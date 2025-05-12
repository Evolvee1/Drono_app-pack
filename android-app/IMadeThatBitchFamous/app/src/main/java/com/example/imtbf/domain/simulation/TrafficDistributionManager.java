package com.example.imtbf.domain.simulation;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import com.example.imtbf.InstagramTrafficSimulatorApp;
import com.example.imtbf.data.local.PreferencesManager;
import com.example.imtbf.utils.Logger;
import com.example.imtbf.utils.Constants;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Manages traffic distribution over time according to the configured schedule.
 * This class handles scheduling, pausing, and resuming traffic generation
 * based on a time distribution pattern.
 */
public class TrafficDistributionManager {
    private static final String TAG = "TrafficDistManager";

    private final Context context;
    private final Handler handler;
    private PreferencesManager preferencesManager;
    private SessionManager sessionManager;

    private TrafficSchedule currentSchedule;
    private long[] intervalArray;
    private int currentIndex = 0;
    private long startTimeMs = 0;
    private AtomicBoolean isRunning = new AtomicBoolean(false);
    private AtomicBoolean isPaused = new AtomicBoolean(false);
    private boolean isScheduledModeEnabled = false;

    private List<Runnable> pendingRequests = new ArrayList<>();
    private List<DistributionListener> listeners = new ArrayList<>();

    /**
     * Listener interface for traffic distribution events.
     */
    public interface DistributionListener {
        /**
         * Called when distribution status changes.
         * @param running True if distribution is running, false if paused or stopped
         * @param progress Current progress (0-100)
         */
        void onDistributionStatusChanged(boolean running, int progress);

        /**
         * Called when a request is scheduled.
         * @param scheduledTimeMs Scheduled time in milliseconds from now
         * @param index Request index
         * @param totalRequests Total number of requests
         */
        void onRequestScheduled(long scheduledTimeMs, int index, int totalRequests);
    }

    /**
     * Create a new traffic distribution manager.
     * @param context Application context
     * @param sessionManager Session manager for executing requests
     */
    public TrafficDistributionManager(Context context, SessionManager sessionManager) {
        this.context = context;
        this.sessionManager = sessionManager;
        this.handler = new Handler(Looper.getMainLooper());

        // Get preferences manager
        if (context instanceof Context) {
            preferencesManager = ((InstagramTrafficSimulatorApp) context.getApplicationContext())
                    .getPreferencesManager();

            // Load scheduled mode setting
            isScheduledModeEnabled = preferencesManager.isScheduledModeEnabled();
        }
    }

    /**
     * Add a distribution listener.
     * @param listener Listener to add
     */
    public void addListener(DistributionListener listener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener);
        }
    }

    /**
     * Remove a distribution listener.
     * @param listener Listener to remove
     */
    public void removeListener(DistributionListener listener) {
        listeners.remove(listener);
    }

    /**
     * Configure the traffic schedule.
     * @param totalRequests Total number of requests
     * @param durationHours Duration in hours
     * @param pattern Distribution pattern
     */
    public void configureSchedule(int totalRequests, int durationHours, DistributionPattern pattern) {
        currentSchedule = new TrafficSchedule(totalRequests, durationHours, pattern);

        // If using peak hours pattern, configure it
        if (pattern == DistributionPattern.PEAK_HOURS && preferencesManager != null) {
            int peakStart = preferencesManager.getPeakHourStart();
            int peakEnd = preferencesManager.getPeakHourEnd();
            float peakWeight = preferencesManager.getPeakTrafficWeight();

            currentSchedule.setPeakHourConfig(peakStart, peakEnd, peakWeight);
        }

        // Calculate intervals
        intervalArray = currentSchedule.calculateIntervals();

        Logger.i(TAG, "Configured schedule: " + totalRequests + " requests over " +
                durationHours + " hours using " + pattern.getDisplayName());
    }

    /**
     * Set whether scheduled mode is enabled.
     * @param enabled True to enable scheduled mode, false for immediate mode
     */
    public void setScheduledModeEnabled(boolean enabled) {
        if (isScheduledModeEnabled != enabled) {
            isScheduledModeEnabled = enabled;

            // Save preference
            if (preferencesManager != null) {
                preferencesManager.setScheduledModeEnabled(enabled);
            }

            // If turning off while running, stop distribution
            if (!enabled && isRunning.get()) {
                stopDistribution();
            }

            Logger.i(TAG, "Scheduled mode: " + (enabled ? "Enabled" : "Disabled"));
        }
    }

    /**
     * Check if scheduled mode is enabled.
     * @return True if scheduled mode is enabled
     */
    public boolean isScheduledModeEnabled() {
        return isScheduledModeEnabled;
    }

    /**
     * Start the traffic distribution according to the schedule.
     * @return True if started successfully
     */
    public boolean startDistribution() {
        if (isRunning.get()) {
            Logger.w(TAG, "Distribution already running");
            return false;
        }

        if (currentSchedule == null || intervalArray == null) {
            Logger.e(TAG, "Cannot start without a configured schedule");
            return false;
        }

        // Reset state
        currentIndex = 0;
        startTimeMs = System.currentTimeMillis();
        isRunning.set(true);
        isPaused.set(false);
        pendingRequests.clear();

        // Mark state as existing for recovery
        if (preferencesManager != null) {
            preferencesManager.setBoolean(Constants.PREF_DISTRIBUTION_STATE_EXISTS, true);
            saveDistributionState();
        }

        // Schedule the first request
        scheduleNextRequest();

        // Notify listeners
        notifyStatusChanged(true, 0);

        Logger.i(TAG, "Started traffic distribution");
        return true;
    }

    /**
     * Stop the traffic distribution.
     */
    public void stopDistribution() {
        if (isRunning.getAndSet(false)) {
            // Cancel all pending requests
            handler.removeCallbacksAndMessages(null);
            pendingRequests.clear();
            isPaused.set(false);

            Logger.i(TAG, "Stopped traffic distribution");

            // Clear saved state
            clearSavedState();

            // Notify listeners
            notifyStatusChanged(false, calculateProgress());
        }
    }

    /**
     * Pause the traffic distribution.
     */
    public void pauseDistribution() {
        if (isRunning.getAndSet(false)) {
            // Cancel all pending requests but keep them for later resumption
            handler.removeCallbacksAndMessages(null);
            isPaused.set(true);

            Logger.i(TAG, "Paused traffic distribution");

            // Save state for recovery
            saveDistributionState();

            // Notify listeners
            notifyStatusChanged(false, calculateProgress());
        }
    }

    /**
     * Resume the traffic distribution.
     */
    public void resumeDistribution() {
        if (!isRunning.getAndSet(true)) {
            isPaused.set(false);
            
            // Reschedule pending requests
            for (Runnable request : pendingRequests) {
                handler.post(request);
            }

            Logger.i(TAG, "Resumed traffic distribution");

            // Save state for recovery
            saveDistributionState();

            // Notify listeners
            notifyStatusChanged(true, calculateProgress());
        }
    }

    /**
     * Check if the distribution is currently running.
     * @return True if running
     */
    public boolean isRunning() {
        return isRunning.get();
    }

    /**
     * Check if the distribution is currently paused.
     * @return True if paused
     */
    public boolean isPaused() {
        return isPaused.get();
    }

    /**
     * Schedule the next request.
     */
    private void scheduleNextRequest() {
        if (!isRunning.get() || currentIndex >= intervalArray.length + 1) {
            return;
        }

        // Get current hour to adjust for time-of-day based patterns
        Calendar calendar = Calendar.getInstance();
        int currentHour = calendar.get(Calendar.HOUR_OF_DAY);

        // Execute the current request
        executeRequest();

        // If there are more requests to schedule
        if (currentIndex < intervalArray.length) {
            // Get interval until next request
            long intervalMs = intervalArray[currentIndex];

            // Create runnable for next request
            Runnable requestRunnable = () -> {
                currentIndex++;
                scheduleNextRequest();
            };

            // Add to pending requests
            pendingRequests.add(requestRunnable);

            // Schedule next request
            handler.postDelayed(requestRunnable, intervalMs);

            // Notify listeners
            notifyRequestScheduled(intervalMs, currentIndex, currentSchedule.getTotalRequests());

            Logger.d(TAG, "Scheduled request " + (currentIndex + 1) + "/" +
                    currentSchedule.getTotalRequests() + " in " + intervalMs + "ms");
        } else {
            // All requests complete
            Logger.i(TAG, "Traffic distribution completed");
            isRunning.set(false);

            // Notify listeners
            notifyStatusChanged(false, 100);
        }
    }

    /**
     * Execute a single request.
     */
    private void executeRequest() {
        if (sessionManager != null) {
            // If in scheduled mode, this triggers the session manager to execute one request
            // The implementation details would depend on your SessionManager
            sessionManager.executeScheduledRequest();

            Logger.d(TAG, "Executed request " + currentIndex + "/" +
                    currentSchedule.getTotalRequests());
        }
    }

    /**
     * Calculate current progress (0-100).
     * @return Progress percentage
     */
    private int calculateProgress() {
        if (currentSchedule == null) {
            return 0;
        }

        int totalRequests = currentSchedule.getTotalRequests();
        if (totalRequests <= 0) {
            return 0;
        }

        return (currentIndex * 100) / totalRequests;
    }

    /**
     * Notify listeners of status change.
     * @param running Running status
     * @param progress Current progress
     */
    private void notifyStatusChanged(boolean running, int progress) {
        for (DistributionListener listener : listeners) {
            listener.onDistributionStatusChanged(running, progress);
        }
    }

    /**
     * Notify listeners of request scheduled.
     * @param scheduledTimeMs Time until request in milliseconds
     * @param index Request index
     * @param totalRequests Total number of requests
     */
    private void notifyRequestScheduled(long scheduledTimeMs, int index, int totalRequests) {
        for (DistributionListener listener : listeners) {
            listener.onRequestScheduled(scheduledTimeMs, index, totalRequests);
        }
    }

    /**
     * Get estimated remaining time in milliseconds.
     * @return Estimated remaining time
     */
    public long getEstimatedRemainingTimeMs() {
        if (!isRunning.get() || currentSchedule == null || currentIndex >= intervalArray.length) {
            return 0;
        }

        long remainingMs = 0;
        for (int i = currentIndex; i < intervalArray.length; i++) {
            remainingMs += intervalArray[i];
        }

        return remainingMs;
    }

    /**
     * Get estimated completion time in milliseconds since epoch.
     * @return Estimated completion time
     */
    public long getEstimatedCompletionTimeMs() {
        return System.currentTimeMillis() + getEstimatedRemainingTimeMs();
    }

    /**
     * Get current progress (0-100).
     * @return Progress percentage
     */
    public int getProgress() {
        return calculateProgress();
    }

    /**
     * Save the current distribution state for recovery.
     */
    private void saveDistributionState() {
        if (preferencesManager != null && currentSchedule != null) {
            // Save state to preferences
            preferencesManager.setInt(Constants.PREF_DISTRIBUTION_CURRENT_INDEX, currentIndex);
            preferencesManager.setInt(Constants.PREF_DISTRIBUTION_TOTAL_REQUESTS, currentSchedule.getTotalRequests());
            preferencesManager.setLong(Constants.PREF_DISTRIBUTION_START_TIME, startTimeMs);
            preferencesManager.setBoolean(Constants.PREF_DISTRIBUTION_IS_PAUSED, isPaused.get());
        }
    }

    /**
     * Restore the distribution state from saved preferences.
     * @return True if state was restored successfully
     */
    public boolean restoreDistributionState() {
        if (preferencesManager == null || 
            !preferencesManager.getBoolean(Constants.PREF_DISTRIBUTION_STATE_EXISTS, false)) {
            return false;
        }

        try {
            // Restore state from preferences
            int savedIndex = preferencesManager.getInt(Constants.PREF_DISTRIBUTION_CURRENT_INDEX, 0);
            int totalRequests = preferencesManager.getInt(Constants.PREF_DISTRIBUTION_TOTAL_REQUESTS, 0);
            long savedStartTime = preferencesManager.getLong(Constants.PREF_DISTRIBUTION_START_TIME, 0);
            boolean savedIsPaused = preferencesManager.getBoolean(Constants.PREF_DISTRIBUTION_IS_PAUSED, false);

            // Verify we have valid data
            if (totalRequests <= 0) {
                return false;
            }

            // Find the distribution pattern from preferences
            String patternStr = preferencesManager.getDistributionPattern();
            DistributionPattern pattern = DistributionPattern.EVEN;
            for (DistributionPattern p : DistributionPattern.values()) {
                if (p.name().equals(patternStr)) {
                    pattern = p;
                    break;
                }
            }

            // Configure the schedule
            int durationHours = preferencesManager.getDistributionDurationHours();
            configureSchedule(totalRequests, durationHours, pattern);

            // Restore state variables
            currentIndex = savedIndex;
            startTimeMs = savedStartTime > 0 ? savedStartTime : System.currentTimeMillis();
            isPaused.set(savedIsPaused);
            isRunning.set(!savedIsPaused);

            Logger.i(TAG, "Restored distribution state: " + currentIndex + "/" + totalRequests +
                    ", pattern=" + pattern.getDisplayName() +
                    ", paused=" + savedIsPaused);

            // Notify listeners of the restored state
            notifyStatusChanged(!savedIsPaused, calculateProgress());

            // If not paused, schedule the next request
            if (!savedIsPaused) {
                scheduleNextRequest();
            }

            return true;
        } catch (Exception e) {
            Logger.e(TAG, "Error restoring distribution state", e);
            return false;
        }
    }

    /**
     * Clear the saved distribution state.
     */
    private void clearSavedState() {
        if (preferencesManager != null) {
            preferencesManager.setBoolean(Constants.PREF_DISTRIBUTION_STATE_EXISTS, false);
            preferencesManager.setInt(Constants.PREF_DISTRIBUTION_CURRENT_INDEX, 0);
            preferencesManager.setInt(Constants.PREF_DISTRIBUTION_TOTAL_REQUESTS, 0);
            preferencesManager.setLong(Constants.PREF_DISTRIBUTION_START_TIME, 0);
            preferencesManager.setBoolean(Constants.PREF_DISTRIBUTION_IS_PAUSED, false);
        }
    }
}