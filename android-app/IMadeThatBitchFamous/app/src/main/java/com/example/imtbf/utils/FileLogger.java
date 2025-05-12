package com.example.imtbf.utils;

import android.content.Context;
import android.os.Environment;
import android.util.Log;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Utility for logging to external files
 */
public class FileLogger {
    private static final String TAG = "FileLogger";
    private static final String LOG_DIRECTORY = "DronoLogs";
    private static final String SESSION_LOG_PREFIX = "session_log_";
    private static final String CRASH_LOG_PREFIX = "crash_log_";
    private static final String LOG_EXTENSION = ".txt";
    
    private static FileLogger instance;
    private final Context context;
    private final ConcurrentLinkedQueue<String> logQueue = new ConcurrentLinkedQueue<>();
    private final ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor();
    private String currentSessionId;
    private File logDirectory;
    private boolean isEnabled = true;
    
    /**
     * Get the singleton instance of FileLogger
     * @param context Application context
     * @return FileLogger instance
     */
    public static synchronized FileLogger getInstance(Context context) {
        if (instance == null) {
            instance = new FileLogger(context.getApplicationContext());
        }
        return instance;
    }
    
    private FileLogger(Context context) {
        this.context = context;
        initializeLogDirectory();
        startLogWriterThread();
    }
    
    /**
     * Initialize the log directory
     */
    private void initializeLogDirectory() {
        // Try to use Downloads directory first
        File downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
        logDirectory = new File(downloadDir, LOG_DIRECTORY);
        
        // If we can't access Downloads, use app-specific directory
        if (!logDirectory.exists() && !logDirectory.mkdirs()) {
            logDirectory = new File(context.getExternalFilesDir(null), LOG_DIRECTORY);
            if (!logDirectory.exists() && !logDirectory.mkdirs()) {
                Log.e(TAG, "Failed to create log directory");
                isEnabled = false;
            }
        }
        
        Log.i(TAG, "Log directory: " + logDirectory.getAbsolutePath());
    }
    
    /**
     * Start a background thread to write logs periodically
     */
    private void startLogWriterThread() {
        executor.scheduleWithFixedDelay(() -> {
            if (!logQueue.isEmpty()) {
                writeQueuedLogsToFile();
            }
        }, 5, 5, TimeUnit.SECONDS);
    }
    
    /**
     * Set current session ID for logging
     * @param sessionId Session ID
     */
    public void setCurrentSessionId(String sessionId) {
        this.currentSessionId = sessionId;
    }
    
    /**
     * Log a message to the current session log
     * @param message Log message
     */
    public void log(String message) {
        if (!isEnabled) return;
        
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        String formattedMessage = timestamp + " | " + message;
        
        logQueue.add(formattedMessage);
    }
    
    /**
     * Log an exception or crash
     * @param e Exception
     * @param additionalInfo Additional information about the crash
     */
    public void logCrash(Throwable e, String additionalInfo) {
        if (!isEnabled) return;
        
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        StringBuilder crashLog = new StringBuilder();
        
        crashLog.append(timestamp).append(" | CRASH: ").append(e.getClass().getName())
               .append(": ").append(e.getMessage()).append("\n");
        
        if (additionalInfo != null && !additionalInfo.isEmpty()) {
            crashLog.append(timestamp).append(" | INFO: ").append(additionalInfo).append("\n");
        }
        
        crashLog.append(timestamp).append(" | STACK TRACE:\n");
        for (StackTraceElement element : e.getStackTrace()) {
            crashLog.append(timestamp).append(" | at ").append(element.toString()).append("\n");
        }
        
        logQueue.add(crashLog.toString());
        
        // Force immediate write for crashes
        writeQueuedLogsToFile();
        
        // Also create a dedicated crash log file
        writeCrashLog(crashLog.toString());
    }
    
    /**
     * Write current queued logs to file
     */
    private synchronized void writeQueuedLogsToFile() {
        if (!isEnabled || currentSessionId == null) return;
        
        File logFile = getSessionLogFile();
        
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(logFile, true))) {
            String message;
            while ((message = logQueue.poll()) != null) {
                writer.write(message);
                writer.newLine();
            }
        } catch (IOException e) {
            Log.e(TAG, "Failed to write to log file", e);
        }
    }
    
    /**
     * Write a crash log to a dedicated file
     * @param crashLog Crash log content
     */
    private void writeCrashLog(String crashLog) {
        if (!isEnabled) return;
        
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        File crashLogFile = new File(logDirectory, CRASH_LOG_PREFIX + timestamp + LOG_EXTENSION);
        
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(crashLogFile))) {
            writer.write("DRONO APP CRASH LOG\n");
            writer.write("Session ID: " + (currentSessionId != null ? currentSessionId : "N/A") + "\n");
            writer.write("Timestamp: " + timestamp + "\n\n");
            writer.write(crashLog);
        } catch (IOException e) {
            Log.e(TAG, "Failed to write crash log", e);
        }
    }
    
    /**
     * Get the session log file
     * @return Session log file
     */
    private File getSessionLogFile() {
        return new File(logDirectory, getSessionLogFilename());
    }
    
    /**
     * Get session log filename
     * @return Session log filename
     */
    private String getSessionLogFilename() {
        return SESSION_LOG_PREFIX + currentSessionId + LOG_EXTENSION;
    }
    
    /**
     * Start a new session log
     * @param sessionInfo Session information to log at the beginning
     * @return Session ID
     */
    public String startNewSessionLog(String sessionInfo) {
        if (!isEnabled) return "disabled";
        
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        currentSessionId = timestamp;
        
        String sessionStart = "=== SESSION STARTED: " + timestamp + " ===";
        logQueue.add(sessionStart);
        
        if (sessionInfo != null && !sessionInfo.isEmpty()) {
            logQueue.add("Session info: " + sessionInfo);
        }
        
        // Force immediate write for session start
        writeQueuedLogsToFile();
        
        return currentSessionId;
    }
    
    /**
     * End current session log
     */
    public void endSessionLog() {
        if (!isEnabled || currentSessionId == null) return;
        
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        String sessionEnd = timestamp + " | === SESSION ENDED ===";
        logQueue.add(sessionEnd);
        
        // Force immediate write for session end
        writeQueuedLogsToFile();
    }
    
    /**
     * Get all log files
     * @return Array of log files
     */
    public File[] getLogFiles() {
        if (!isEnabled || !logDirectory.exists()) {
            return new File[0];
        }
        
        return logDirectory.listFiles((dir, name) -> 
            name.startsWith(SESSION_LOG_PREFIX) || name.startsWith(CRASH_LOG_PREFIX));
    }
    
    /**
     * Get the log directory
     * @return Log directory
     */
    public File getLogDirectory() {
        return logDirectory;
    }
    
    /**
     * Clean up resources and ensure logs are written
     */
    public void shutdown() {
        writeQueuedLogsToFile();
        executor.shutdown();
    }
} 