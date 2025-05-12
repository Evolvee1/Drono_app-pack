package com.example.imtbf2.data.local;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.UUID;

import com.example.imtbf2.utils.Constants;

/**
 * Manages access to SharedPreferences for storing app settings.
 * Uses a centralized approach for all preference access.
 */
public class PreferencesManager {

    private final SharedPreferences preferences;



    /**
     * Constructor that initializes SharedPreferences.
     * @param context Application context
     */
    public PreferencesManager(Context context) {
        preferences = context.getSharedPreferences(
                Constants.PREF_FILE_NAME, Context.MODE_PRIVATE);

        // Generate a unique device ID if not already generated
        if (getDeviceId().isEmpty()) {
            setDeviceId(UUID.randomUUID().toString());
        }
    }

    /**
     * Get an integer preference value
     * @param key Preference key
     * @param defaultValue Default value if preference doesn't exist
     * @return Preference value or default
     */
    public int getInt(String key, int defaultValue) {
        return preferences.getInt(key, defaultValue);
    }

    /**
     * Set an integer preference value
     * @param key Preference key
     * @param value Value to set
     */
    public void setInt(String key, int value) {
        preferences.edit().putInt(key, value).apply();
    }

    /**
     * Get the target URL for simulation.
     * @return Target URL
     */
    public String getTargetUrl() {
        return preferences.getString(
                Constants.PREF_TARGET_URL, Constants.DEFAULT_TARGET_URL);
    }

    /**
     * Set the target URL for simulation.
     * @param url Target URL
     */
    public void setTargetUrl(String url) {
        preferences.edit().putString(Constants.PREF_TARGET_URL, url).apply();
    }

    /**
     * Get the reading time mean in milliseconds.
     * @return Reading time mean
     */
    public int getReadingTimeMean() {
        return getInt(Constants.PREF_READING_TIME_MEAN, Constants.DEFAULT_READING_TIME_MEAN_MS);
    }

    /**
     * Set the reading time mean in milliseconds.
     * @param readingTimeMean Reading time mean
     */
    public void setReadingTimeMean(int readingTimeMean) {
        setInt(Constants.PREF_READING_TIME_MEAN, readingTimeMean);
    }

    /**
     * Get the reading time standard deviation in milliseconds.
     * @return Reading time standard deviation
     */
    public int getReadingTimeStdDev() {
        return getInt(Constants.PREF_READING_TIME_STDDEV, Constants.DEFAULT_READING_TIME_STDDEV_MS);
    }

    /**
     * Set the reading time standard deviation in milliseconds.
     * @param readingTimeStdDev Reading time standard deviation
     */
    public void setReadingTimeStdDev(int readingTimeStdDev) {
        setInt(Constants.PREF_READING_TIME_STDDEV, readingTimeStdDev);
    }

    /**
     * Get the minimum interval between requests in seconds.
     * @return Minimum interval in seconds
     */
    public int getMinInterval() {
        return preferences.getInt(
                Constants.PREF_MIN_INTERVAL, Constants.DEFAULT_MIN_INTERVAL);
    }

    /**
     * Set the minimum interval between requests in seconds.
     * @param seconds Minimum interval in seconds
     */
    public void setMinInterval(int seconds) {
        preferences.edit().putInt(Constants.PREF_MIN_INTERVAL, seconds).apply();
    }

    /**
     * Get the maximum interval between requests in seconds.
     * @return Maximum interval in seconds
     */
    public int getMaxInterval() {
        return preferences.getInt(
                Constants.PREF_MAX_INTERVAL, Constants.DEFAULT_MAX_INTERVAL);
    }

    /**
     * Set the maximum interval between requests in seconds.
     * @param seconds Maximum interval in seconds
     */
    public void setMaxInterval(int seconds) {
        preferences.edit().putInt(Constants.PREF_MAX_INTERVAL, seconds).apply();
    }

    /**
     * Get the number of iterations for the simulation.
     * @return Number of iterations
     */
    public int getIterations() {
        return preferences.getInt(
                Constants.PREF_ITERATIONS, Constants.DEFAULT_ITERATIONS);
    }

    /**
     * Set the number of iterations for the simulation.
     * @param iterations Number of iterations
     */
    public void setIterations(int iterations) {
        preferences.edit().putInt(Constants.PREF_ITERATIONS, iterations).apply();
    }

    /**
     * Check if a simulation is currently running.
     * @return True if simulation is running, false otherwise
     */
    public boolean isSimulationRunning() {
        return preferences.getBoolean(Constants.PREF_IS_RUNNING, false);
    }

    /**
     * Set the simulation running state.
     * @param isRunning True if simulation is running, false otherwise
     */
    public void setSimulationRunning(boolean isRunning) {
        preferences.edit().putBoolean(Constants.PREF_IS_RUNNING, isRunning).apply();
    }

    /**
     * Get the unique device ID.
     * @return Device ID
     */
    public String getDeviceId() {
        return preferences.getString(Constants.PREF_DEVICE_ID, "");
    }

    /**
     * Set the unique device ID.
     * @param deviceId Device ID
     */
    private void setDeviceId(String deviceId) {
        preferences.edit().putString(Constants.PREF_DEVICE_ID, deviceId).apply();
    }

    /**
     * Check if debug logging is enabled.
     * @return True if debug logging is enabled, false otherwise
     */
    public boolean isDebugLoggingEnabled() {
        return preferences.getBoolean(Constants.PREF_DEBUG_LOGGING, false);
    }

    /**
     * Set whether debug logging is enabled.
     * @param enabled True to enable debug logging, false to disable
     */
    public void setDebugLoggingEnabled(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_DEBUG_LOGGING, enabled).apply();
    }

    /**
     * Get the airplane mode toggle delay in milliseconds.
     * This is the time between toggling airplane mode on and off.
     * @return Airplane mode toggle delay in milliseconds
     */
    public int getAirplaneModeDelay() {
        return preferences.getInt(
                Constants.PREF_AIRPLANE_MODE_DELAY,
                Constants.DEFAULT_AIRPLANE_MODE_DELAY);
    }

    /**
     * Set the airplane mode toggle delay in milliseconds.
     * @param delayMs Airplane mode toggle delay in milliseconds
     */
    public void setAirplaneModeDelay(int delayMs) {
        preferences.edit().putInt(Constants.PREF_AIRPLANE_MODE_DELAY, delayMs).apply();
    }

    /**
     * Get the selected user agent type.
     * @return Selected user agent type
     */
    public String getSelectedUserAgentType() {
        return preferences.getString(
                Constants.PREF_SELECTED_USER_AGENT_TYPE,
                Constants.DEFAULT_USER_AGENT_TYPE);
    }

    /**
     * Set the selected user agent type.
     * @param userAgentType User agent type
     */
    public void setSelectedUserAgentType(String userAgentType) {
        preferences.edit().putString(
                Constants.PREF_SELECTED_USER_AGENT_TYPE, userAgentType).apply();
    }

    // Add this constant to Constants.java
    public static final String PREF_USE_WEBVIEW_MODE = "use_webview_mode";

// Add these methods to PreferencesManager.java
    /**
     * Check if WebView mode is enabled.
     * @return True if WebView mode is enabled, false for HTTP mode
     */
    public boolean getUseWebViewMode() {
        return preferences.getBoolean(Constants.PREF_USE_WEBVIEW_MODE, false);
    }

    /**
     * Set whether WebView mode is enabled.
     * @param enabled True to enable WebView mode, false for HTTP mode
     */
    public void setUseWebViewMode(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_USE_WEBVIEW_MODE, enabled).apply();
    }

    /**
     * Get a boolean preference value
     * @param key Preference key
     * @param defaultValue Default value if preference doesn't exist
     * @return Preference value or default
     */
    public boolean getBoolean(String key, boolean defaultValue) {
        return preferences.getBoolean(key, defaultValue);
    }

    /**
     * Set a boolean preference value
     * @param key Preference key
     * @param value Value to set
     */
    public void setBoolean(String key, boolean value) {
        preferences.edit().putBoolean(key, value).apply();
    }

    public boolean isAggressiveSessionClearingEnabled() {
        // Default to true (turned on by default)
        return preferences.getBoolean(Constants.PREF_AGGRESSIVE_SESSION_CLEARING, true);
    }

    public void setAggressiveSessionClearingEnabled(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_AGGRESSIVE_SESSION_CLEARING, enabled).apply();
    }

    public boolean isNewWebViewPerRequestEnabled() {
        return preferences.getBoolean(Constants.PREF_NEW_WEBVIEW_PER_REQUEST, false);
    }

    public void setNewWebViewPerRequestEnabled(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_NEW_WEBVIEW_PER_REQUEST, enabled).apply();
    }

    // Add these methods to PreferencesManager.java

    /**
     * Check if scheduled traffic distribution mode is enabled
     * @return True if scheduled mode is enabled, false for immediate mode
     */
    public boolean isScheduledModeEnabled() {
        return preferences.getBoolean(Constants.PREF_SCHEDULED_MODE_ENABLED,
                Constants.DEFAULT_SCHEDULED_MODE_ENABLED);
    }

    /**
     * Set whether scheduled traffic distribution mode is enabled
     * @param enabled True to enable scheduled mode, false for immediate mode
     */
    public void setScheduledModeEnabled(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_SCHEDULED_MODE_ENABLED, enabled).apply();
    }

    /**
     * Get the selected distribution pattern
     * @return Distribution pattern name
     */
    public String getDistributionPattern() {
        return preferences.getString(Constants.PREF_DISTRIBUTION_PATTERN,
                Constants.DEFAULT_DISTRIBUTION_PATTERN);
    }

    /**
     * Set the distribution pattern
     * @param pattern Distribution pattern name
     */
    public void setDistributionPattern(String pattern) {
        preferences.edit().putString(Constants.PREF_DISTRIBUTION_PATTERN, pattern).apply();
    }

    /**
     * Get the distribution duration in hours
     * @return Duration in hours
     */
    public int getDistributionDurationHours() {
        return preferences.getInt(Constants.PREF_DISTRIBUTION_DURATION_HOURS,
                Constants.DEFAULT_DISTRIBUTION_DURATION_HOURS);
    }

    /**
     * Set the distribution duration in hours
     * @param hours Duration in hours
     */
    public void setDistributionDurationHours(int hours) {
        preferences.edit().putInt(Constants.PREF_DISTRIBUTION_DURATION_HOURS, hours).apply();
    }

    /**
     * Get the peak hour start time (24-hour format)
     * @return Start hour (0-23)
     */
    public int getPeakHourStart() {
        return preferences.getInt(Constants.PREF_PEAK_HOUR_START,
                Constants.DEFAULT_PEAK_HOUR_START);
    }

    /**
     * Set the peak hour start time (24-hour format)
     * @param hour Start hour (0-23)
     */
    public void setPeakHourStart(int hour) {
        preferences.edit().putInt(Constants.PREF_PEAK_HOUR_START, hour).apply();
    }

    /**
     * Get the peak hour end time (24-hour format)
     * @return End hour (0-23)
     */
    public int getPeakHourEnd() {
        return preferences.getInt(Constants.PREF_PEAK_HOUR_END,
                Constants.DEFAULT_PEAK_HOUR_END);
    }

    /**
     * Set the peak hour end time (24-hour format)
     * @param hour End hour (0-23)
     */
    public void setPeakHourEnd(int hour) {
        preferences.edit().putInt(Constants.PREF_PEAK_HOUR_END, hour).apply();
    }

    /**
     * Get the peak traffic weight factor
     * @return Weight factor (0.0-1.0)
     */
    public float getPeakTrafficWeight() {
        return preferences.getFloat(Constants.PREF_PEAK_TRAFFIC_WEIGHT,
                Constants.DEFAULT_PEAK_TRAFFIC_WEIGHT);
    }

    /**
     * Set the peak traffic weight factor
     * @param weight Weight factor (0.0-1.0)
     */
    public void setPeakTrafficWeight(float weight) {
        preferences.edit().putFloat(Constants.PREF_PEAK_TRAFFIC_WEIGHT, weight).apply();
    }

    /**
     * Check if marketing redirect handling is enabled.
     * @return True if enabled, false otherwise
     */
    public boolean isHandleMarketingRedirectsEnabled() {
        return preferences.getBoolean(Constants.PREF_HANDLE_MARKETING_REDIRECTS,
                Constants.DEFAULT_HANDLE_MARKETING_REDIRECTS);
    }

    /**
     * Set whether marketing redirect handling is enabled.
     * @param enabled True to enable handling, false to disable
     */
    public void setHandleMarketingRedirectsEnabled(boolean enabled) {
        preferences.edit().putBoolean(Constants.PREF_HANDLE_MARKETING_REDIRECTS, enabled).apply();
    }

    /**
     * Save session state for recovery after a crash or device restart.
     * @param currentIndex Current request index
     * @param totalRequests Total number of requests
     * @param isPaused Whether the session is paused
     * @param startTime Session start time in milliseconds
     * @param totalPausedTime Total time spent in paused state in milliseconds
     * @param pauseStartTime Time when the session was paused (0 if not paused)
     */
    public void saveSessionState(int currentIndex, int totalRequests, boolean isPaused, 
                               long startTime, long totalPausedTime, long pauseStartTime) {
        SharedPreferences.Editor editor = preferences.edit();
        editor.putInt(Constants.PREF_SESSION_CURRENT_INDEX, currentIndex);
        editor.putInt(Constants.PREF_SESSION_TOTAL_REQUESTS, totalRequests);
        editor.putBoolean(Constants.PREF_SESSION_IS_PAUSED, isPaused);
        editor.putLong(Constants.PREF_SESSION_START_TIME, startTime);
        editor.putLong("session_total_paused_time", totalPausedTime);
        editor.putLong("session_pause_start_time", pauseStartTime);
        editor.apply();
    }

    /**
     * Save session state with the old method signature (for backward compatibility).
     */
    public void saveSessionState(int currentIndex, int totalRequests, boolean isPaused, long startTime) {
        saveSessionState(currentIndex, totalRequests, isPaused, startTime, 0, 0);
    }

    /**
     * Check if there is a saved session state.
     * @return True if there is a saved session state
     */
    public boolean hasSavedSessionState() {
        return isSimulationRunning() && preferences.contains(Constants.PREF_SESSION_CURRENT_INDEX);
    }

    /**
     * Get the saved current request index.
     * @return Current request index or 0 if not saved
     */
    public int getSavedCurrentIndex() {
        return preferences.getInt(Constants.PREF_SESSION_CURRENT_INDEX, 0);
    }

    /**
     * Get the saved total number of requests.
     * @return Total number of requests or 0 if not saved
     */
    public int getSavedTotalRequests() {
        return preferences.getInt(Constants.PREF_SESSION_TOTAL_REQUESTS, 0);
    }

    /**
     * Check if the session was paused.
     * @return True if session was paused, false otherwise
     */
    public boolean wasSavedSessionPaused() {
        return preferences.getBoolean(Constants.PREF_SESSION_IS_PAUSED, false);
    }

    /**
     * Get the saved session start time.
     * @return Session start time in milliseconds or 0 if not saved
     */
    public long getSavedSessionStartTime() {
        return preferences.getLong(Constants.PREF_SESSION_START_TIME, 0);
    }

    /**
     * Get the total time spent in paused state during the session.
     * @return Total paused time in milliseconds or 0 if not saved
     */
    public long getSavedTotalPausedTime() {
        return preferences.getLong("session_total_paused_time", 0);
    }

    /**
     * Get the time when the session was last paused.
     * @return Pause start time in milliseconds or 0 if not saved or not paused
     */
    public long getSavedPauseStartTime() {
        return preferences.getLong("session_pause_start_time", 0);
    }

    /**
     * Clear saved session state.
     */
    public void clearSavedSessionState() {
        SharedPreferences.Editor editor = preferences.edit();
        editor.remove(Constants.PREF_SESSION_CURRENT_INDEX);
        editor.remove(Constants.PREF_SESSION_TOTAL_REQUESTS);
        editor.remove(Constants.PREF_SESSION_IS_PAUSED);
        editor.remove(Constants.PREF_SESSION_START_TIME);
        editor.remove("session_total_paused_time");
        editor.remove("session_pause_start_time");
        editor.apply();
    }

    /**
     * Get a long preference value
     * @param key Preference key
     * @param defaultValue Default value if preference doesn't exist
     * @return Preference value or default
     */
    public long getLong(String key, long defaultValue) {
        return preferences.getLong(key, defaultValue);
    }
    
    /**
     * Set a long preference value
     * @param key Preference key
     * @param value Value to set
     */
    public void setLong(String key, long value) {
        preferences.edit().putLong(key, value).apply();
    }

    /**
     * Get a string preference value
     * @param key Preference key
     * @param defaultValue Default value if preference doesn't exist
     * @return Preference value or default
     */
    public String getString(String key, String defaultValue) {
        return preferences.getString(key, defaultValue);
    }

    /**
     * Set a string preference value
     * @param key Preference key
     * @param value Value to set
     */
    public void setString(String key, String value) {
        preferences.edit().putString(key, value).apply();
    }
}