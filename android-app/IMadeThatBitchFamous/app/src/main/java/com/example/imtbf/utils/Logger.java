package com.example.imtbf.utils;

import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Custom logger that handles both system logging and internal log storage.
 * This is useful for both debugging and displaying logs to the user.
 */
public class Logger {

    private static boolean debugLoggingEnabled = true;
    private static final int MAX_LOG_ENTRIES = 1000;
    private static final List<LogEntry> logEntries = new ArrayList<>();
    private static final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss.SSS", Locale.getDefault());

    /**
     * Check if debug logging is enabled
     * @return True if debug logging is enabled
     */
    public static boolean isDebugLoggingEnabled() {
        return debugLoggingEnabled;
    }

    /**
     * Initialize the logger with debug settings.
     * @param isDebugEnabled Whether debug logging is enabled
     */
    public static void init(boolean isDebugEnabled) {
        debugLoggingEnabled = isDebugEnabled;
        d("Logger", "Logger initialized with debug " + (isDebugEnabled ? "enabled" : "disabled"));
    }

    /**
     * Log a debug message.
     * @param tag Log tag
     * @param message Log message
     */
    public static void d(String tag, String message) {
        if (debugLoggingEnabled) {
            Log.d(tag, message);
        }
        addLogEntry(LogLevel.DEBUG, tag, message);
    }

    /**
     * Log an info message.
     * @param tag Log tag
     * @param message Log message
     */
    public static void i(String tag, String message) {
        Log.i(tag, message);
        addLogEntry(LogLevel.INFO, tag, message);
    }

    /**
     * Log a warning message.
     * @param tag Log tag
     * @param message Log message
     */
    public static void w(String tag, String message) {
        Log.w(tag, message);
        addLogEntry(LogLevel.WARN, tag, message);
    }

    /**
     * Log an error message.
     * @param tag Log tag
     * @param message Log message
     */
    public static void e(String tag, String message) {
        Log.e(tag, message);
        addLogEntry(LogLevel.ERROR, tag, message);
    }

    /**
     * Log an error message with exception.
     * @param tag Log tag
     * @param message Log message
     * @param throwable Exception
     */
    public static void e(String tag, String message, Throwable throwable) {
        Log.e(tag, message, throwable);
        addLogEntry(LogLevel.ERROR, tag, message + ": " + throwable.getMessage());
    }

    /**
     * Add a log entry to the internal log storage.
     * @param level Log level
     * @param tag Log tag
     * @param message Log message
     */
    private static synchronized void addLogEntry(LogLevel level, String tag, String message) {
        if (logEntries.size() >= MAX_LOG_ENTRIES) {
            logEntries.remove(0);
        }
        logEntries.add(new LogEntry(level, tag, message, System.currentTimeMillis()));
    }

    /**
     * Get all log entries.
     * @return List of log entries
     */
    public static synchronized List<LogEntry> getLogEntries() {
        return new ArrayList<>(logEntries);
    }

    /**
     * Clear all log entries.
     */
    public static synchronized void clearLogs() {
        logEntries.clear();
        i("Logger", "Logs cleared");
    }

    /**
     * Get the formatted time for a timestamp.
     * @param timeMillis Timestamp in milliseconds
     * @return Formatted time string
     */
    public static String formatTime(long timeMillis) {
        return timeFormat.format(new Date(timeMillis));
    }

    /**
     * Log level enum.
     */
    public enum LogLevel {
        DEBUG, INFO, WARN, ERROR
    }

    /**
     * Log entry class that holds information about a log message.
     */
    public static class LogEntry {
        private final LogLevel level;
        private final String tag;
        private final String message;
        private final long timestamp;

        public LogEntry(LogLevel level, String tag, String message, long timestamp) {
            this.level = level;
            this.tag = tag;
            this.message = message;
            this.timestamp = timestamp;
        }

        public LogLevel getLevel() {
            return level;
        }

        public String getTag() {
            return tag;
        }

        public String getMessage() {
            return message;
        }

        public long getTimestamp() {
            return timestamp;
        }

        @Override
        public String toString() {
            return formatTime(timestamp) + " | " + level + " | " + tag + ": " + message;
        }
    }
}