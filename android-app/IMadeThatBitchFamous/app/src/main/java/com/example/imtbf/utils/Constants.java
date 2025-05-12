package com.example.imtbf.utils;

/**
 * Central place for all constants used throughout the app.
 * This helps maintain consistency and makes it easier to change values.
 */
public class Constants {

    // Preference keys
    public static final String PREF_FILE_NAME = "instagram_traffic_simulator_prefs";
    public static final String PREF_TARGET_URL = "target_url";
    public static final String PREF_MIN_INTERVAL = "min_interval";
    public static final String PREF_MAX_INTERVAL = "max_interval";
    public static final String PREF_ITERATIONS = "iterations";
    public static final String PREF_IS_RUNNING = "is_running";
    public static final String PREF_DEVICE_ID = "device_id";
    public static final String PREF_DEBUG_LOGGING = "debug_logging";
    public static final String PREF_AIRPLANE_MODE_DELAY = "airplane_mode_delay";
    public static final String PREF_SELECTED_USER_AGENT_TYPE = "selected_user_agent_type";
    public static final String PREF_NEW_WEBVIEW_PER_REQUEST = "new_webview_per_request";
    public static final String PREF_AGGRESSIVE_SESSION_CLEARING = "aggressive_session_clearing";

    public static final String PREF_USE_WEBVIEW_MODE = "use_webview_mode";

    // Default values
    public static final String DEFAULT_TARGET_URL = "https://example.com";
    public static final int DEFAULT_MIN_INTERVAL = 1; // 30 seconds
    public static final int DEFAULT_MAX_INTERVAL = 2; // 90 seconds
    public static final int DEFAULT_ITERATIONS = 1000;
    public static final int DEFAULT_AIRPLANE_MODE_DELAY = 3000; // 3 seconds
    public static final String DEFAULT_USER_AGENT_TYPE = "mixed";

    // Intent actions
    public static final String ACTION_START_SIMULATION = "com.example.imtbf.START_SIMULATION";
    public static final String ACTION_STOP_SIMULATION = "com.example.imtbf.STOP_SIMULATION";
    public static final String ACTION_UPDATE_STATUS = "com.example.imtbf.UPDATE_STATUS";

    // Intent extras
    public static final String EXTRA_STATUS = "status";
    public static final String EXTRA_ERROR = "error";
    public static final String EXTRA_PROGRESS = "progress";

    // Notification
    public static final int NOTIFICATION_ID = 1001;
    public static final String NOTIFICATION_CHANNEL_ID = "traffic_simulator_channel";

    // Service
    public static final int SERVICE_STOP_DELAY = 200; // 3 seconds before stopping service after last request

    // Worker tags
    public static final String WORKER_TAG_SIMULATION = "simulation_worker";
    public static final String WORKER_TAG_METRICS = "metrics_worker";

    // Regional settings - Slovakia
    public static final String REGION_SLOVAKIA = "slovakia";
    public static final int SLOVAKIA_AIRPLANE_MODE_TOGGLE_DURATION = 2000; // 1 second

    // Network headers
    public static final String HEADER_USER_AGENT = "User-Agent";
    public static final String HEADER_REFERER = "Referer";
    public static final String INSTAGRAM_REFERER = "https://www.instagram.com/";

    // Human behavior simulation parameters (research-based defaults)
    // Preference keys for reading time
    public static final String PREF_READING_TIME_MEAN = "reading_time_mean";
    public static final String PREF_READING_TIME_STDDEV = "reading_time_stddev";

    // Default values for reading time
    public static final int DEFAULT_READING_TIME_MEAN_MS = 2000; // 15 seconds
    public static final int DEFAULT_READING_TIME_STDDEV_MS = 1000; // 7.5 seconds

    public static final int READING_TIME_MEAN_MS = 2000; // 15 seconds average reading time
    public static final int READING_TIME_STDDEV_MS = 1000; // Standard deviation for reading time
    public static final float SCROLL_PROBABILITY = 0.82f; // 84% of visitors scroll
    public static final int AVERAGE_SCROLL_DEPTH_PERCENT = 56; // Average scroll depth

    // Database
    public static final String DATABASE_NAME = "instagram_traffic_simulator.db";
    public static final int DATABASE_VERSION = 1;

    // Airplane mode settings
    public static final int AIRPLANE_MODE_OFF = 0;
    public static final int AIRPLANE_MODE_ON = 1;

    // Retry settings
    public static final int MAX_RETRIES = 3;
    public static final int RETRY_DELAY_MS = 5000; // 5 seconds

// Preference keys for custom delay
    public static final String PREF_DELAY_MIN = "delay_min";
    public static final String PREF_DELAY_MAX = "delay_max";

    // Default values for custom delay
    public static final int DEFAULT_DELAY_MIN = 1; // 1 second
    public static final int DEFAULT_DELAY_MAX = 5; // 5 seconds

    //schedule framework

    // Traffic Distribution Preferences
    public static final String PREF_SCHEDULED_MODE_ENABLED = "scheduled_mode_enabled";
    public static final String PREF_DISTRIBUTION_PATTERN = "distribution_pattern";
    public static final String PREF_DISTRIBUTION_DURATION_HOURS = "distribution_duration_hours";
    public static final String PREF_PEAK_HOUR_START = "peak_hour_start";
    public static final String PREF_PEAK_HOUR_END = "peak_hour_end";
    public static final String PREF_PEAK_TRAFFIC_WEIGHT = "peak_traffic_weight";

    // Default values
    public static final boolean DEFAULT_SCHEDULED_MODE_ENABLED = false;
    public static final String DEFAULT_DISTRIBUTION_PATTERN = "EVEN";
    public static final int DEFAULT_DISTRIBUTION_DURATION_HOURS = 24;
    public static final int DEFAULT_PEAK_HOUR_START = 9; // 9 AM
    public static final int DEFAULT_PEAK_HOUR_END = 17;  // 5 PM
    public static final float DEFAULT_PEAK_TRAFFIC_WEIGHT = 0.7f; // 70% during peak hours
    public static final String PREF_HANDLE_MARKETING_REDIRECTS = "handle_marketing_redirects";
    public static final boolean DEFAULT_HANDLE_MARKETING_REDIRECTS = true;

    // Session persistence constants
    public static final String PREF_SESSION_CURRENT_INDEX = "session_current_index";
    public static final String PREF_SESSION_TOTAL_REQUESTS = "session_total_requests";
    public static final String PREF_SESSION_IS_PAUSED = "session_is_paused";
    public static final String PREF_SESSION_START_TIME = "session_start_time";
    
    // Distribution state persistence constants
    public static final String PREF_DISTRIBUTION_STATE_EXISTS = "distribution_state_exists";
    public static final String PREF_DISTRIBUTION_CURRENT_INDEX = "distribution_current_index";
    public static final String PREF_DISTRIBUTION_TOTAL_REQUESTS = "distribution_total_requests";
    public static final String PREF_DISTRIBUTION_START_TIME = "distribution_start_time";
    public static final String PREF_DISTRIBUTION_IS_PAUSED = "distribution_is_paused";

    public static final boolean DEBUG_MODE = true; // or false

    private Constants() {
        // Private constructor to prevent instantiation
    }
}