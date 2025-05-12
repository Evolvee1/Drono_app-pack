package com.example.imtbf.data.network;

import android.content.Context;
import android.net.TrafficStats;
import android.os.Handler;
import android.os.Looper;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.imtbf.data.models.NetworkSession;
import com.example.imtbf.data.models.NetworkStats;
import com.example.imtbf.utils.Logger;

/**
 * Tracks network statistics for the application.
 */
public class NetworkStatsTracker {
    private static final String TAG = "NetworkStatsTracker";
    private static final long UPDATE_INTERVAL_MS = 1000; // Update every second

    private final Context context;
    private final int uid;
    private final Handler mainHandler;
    private final Runnable updateRunnable;

    private long lastRxBytes;
    private long lastTxBytes;
    private long lastUpdateTime;

    private NetworkSession currentSession;
    private final MutableLiveData<NetworkStats> currentStats = new MutableLiveData<>();
    private final MutableLiveData<NetworkSession> sessionData = new MutableLiveData<>();

    private boolean isTracking = false;

    /**
     * Create a new network stats tracker
     * @param context Application context
     */
    public NetworkStatsTracker(Context context) {
        this.context = context.getApplicationContext();
        this.uid = context.getApplicationInfo().uid;
        this.mainHandler = new Handler(Looper.getMainLooper());

        this.currentSession = new NetworkSession();
        this.updateRunnable = this::updateStats;

        // Initialize counters
        resetCounters();
    }

    /**
     * Start tracking network statistics
     */
    public void startTracking() {
        if (isTracking) return;

        isTracking = true;
        resetCounters();
        currentSession = new NetworkSession();
        sessionData.postValue(currentSession);

        // Schedule periodic updates
        mainHandler.post(updateRunnable);
        Logger.i(TAG, "Network stats tracking started");
    }

    /**
     * Stop tracking network statistics
     */
    public void stopTracking() {
        if (!isTracking) return;

        isTracking = false;
        mainHandler.removeCallbacks(updateRunnable);

        if (currentSession != null) {
            currentSession.endSession();
            sessionData.postValue(currentSession);
        }

        Logger.i(TAG, "Network stats tracking stopped");
    }

    /**
     * Reset the tracking counters
     */
    public void resetCounters() {
        lastRxBytes = TrafficStats.getUidRxBytes(uid);
        lastTxBytes = TrafficStats.getUidTxBytes(uid);
        lastUpdateTime = System.currentTimeMillis();
    }

    /**
     * Manually add upload bytes (for OkHttp tracking)
     * @param bytes Bytes uploaded
     */
    public void addUploadBytes(long bytes) {
        if (currentSession != null && isTracking) {
            currentSession.addBytes(bytes, 0);
            sessionData.postValue(currentSession);
        }
    }

    /**
     * Manually add download bytes (for OkHttp tracking)
     * @param bytes Bytes downloaded
     */
    public void addDownloadBytes(long bytes) {
        if (currentSession != null && isTracking) {
            currentSession.addBytes(0, bytes);
            sessionData.postValue(currentSession);
        }
    }

    /**
     * Record a completed network request
     */
    public void recordRequest() {
        if (currentSession != null && isTracking) {
            currentSession.incrementRequestCount();
            sessionData.postValue(currentSession);
        }
    }

    /**
     * Update network statistics
     */
    private void updateStats() {
        if (!isTracking) return;

        try {
            long currentRxBytes = TrafficStats.getUidRxBytes(uid);
            long currentTxBytes = TrafficStats.getUidTxBytes(uid);
            long currentTime = System.currentTimeMillis();

            // Calculate deltas
            long rxDelta = currentRxBytes - lastRxBytes;
            long txDelta = currentTxBytes - lastTxBytes;
            long timeDeltaMs = currentTime - lastUpdateTime;

            // Avoid division by zero
            if (timeDeltaMs == 0) timeDeltaMs = 1;

            // Calculate speeds (bytes per second)
            float downloadSpeed = (rxDelta * 1000f) / timeDeltaMs;
            float uploadSpeed = (txDelta * 1000f) / timeDeltaMs;

            // Create stats object
            NetworkStats stats = new NetworkStats(txDelta, rxDelta, uploadSpeed, downloadSpeed);

            // Update session
            if (currentSession != null) {
                currentSession.addBytes(txDelta, rxDelta);
                currentSession.addSnapshot(stats);
            }

            // Update LiveData
            currentStats.postValue(stats);
            sessionData.postValue(currentSession);

            // Update counters for next time
            lastRxBytes = currentRxBytes;
            lastTxBytes = currentTxBytes;
            lastUpdateTime = currentTime;

            // Log statistics
            Logger.d(TAG, String.format("Network: ⬆️ %.2f KB/s, ⬇️ %.2f KB/s",
                    uploadSpeed / 1024, downloadSpeed / 1024));
        } catch (Exception e) {
            Logger.e(TAG, "Error updating network stats: " + e.getMessage());
        }

        // Schedule next update
        mainHandler.postDelayed(updateRunnable, UPDATE_INTERVAL_MS);
    }

    /**
     * Get current network stats as LiveData
     * @return LiveData of current network stats
     */
    public LiveData<NetworkStats> getCurrentStats() {
        return currentStats;
    }

    /**
     * Get current session data as LiveData
     * @return LiveData of current network session
     */
    public LiveData<NetworkSession> getSessionData() {
        return sessionData;
    }

    /**
     * Get the current session
     * @return Current network session
     */
    public NetworkSession getCurrentSession() {
        return currentSession;
    }

    /**
     * Format bytes to human-readable string
     * @param bytes Bytes to format
     * @return Formatted string (B, KB, MB, GB)
     */
    public static String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024f);
        if (bytes < 1024 * 1024 * 1024) return String.format("%.2f MB", bytes / (1024f * 1024f));
        return String.format("%.2f GB", bytes / (1024f * 1024f * 1024f));
    }

    /**
     * Format speed to human-readable string
     * @param bytesPerSecond Bytes per second
     * @return Formatted string (B/s, KB/s, MB/s)
     */
    public static String formatSpeed(float bytesPerSecond) {
        if (bytesPerSecond < 1024) return String.format("%.0f B/s", bytesPerSecond);
        if (bytesPerSecond < 1024 * 1024) return String.format("%.1f KB/s", bytesPerSecond / 1024);
        return String.format("%.2f MB/s", bytesPerSecond / (1024 * 1024));
    }
}