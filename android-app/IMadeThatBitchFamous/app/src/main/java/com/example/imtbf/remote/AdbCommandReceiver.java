package com.example.imtbf.remote;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

import com.example.imtbf.InstagramTrafficSimulatorApp;
import com.example.imtbf.data.local.ConfigurationManager;
import com.example.imtbf.data.local.PreferencesManager;
import com.example.imtbf.data.models.AppConfiguration;
import com.example.imtbf.utils.Logger;
import com.example.imtbf.presentation.activities.MainActivity;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Broadcast receiver for handling ADB commands sent to the app.
 * Allows remote control of app features via ADB intent commands.
 *
 * Usage examples:
 * 
 * Start simulation:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command start
 * 
 * Pause simulation:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command pause
 * 
 * Resume simulation:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command resume
 * 
 * Stop simulation:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command stop
 * 
 * Set URL:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es value "https://example.com"
 * 
 * Set iterations:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_iterations --ei value 100
 * 
 * Set min interval:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_min_interval --ei value 5
 * 
 * Set max interval:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_max_interval --ei value 20
 * 
 * Set airplane mode delay:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_airplane_delay --ei value 3000
 * 
 * Enable/disable feature:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_feature --es feature "rotate_ip" --ez value true
 * 
 * Export configuration:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command export_config --es name "my_config" --es desc "My configuration description"
 * 
 * Import configuration:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command import_config --es name "my_config.json"
 * 
 * Get status:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status
 * 
 * List available configurations:
 * adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command list_configs
 */
public class AdbCommandReceiver extends BroadcastReceiver {
    private static final String TAG = "AdbCommandReceiver";
    public static final String ACTION_COMMAND = "com.example.imtbf.debug.COMMAND";
    public static final String ACTION_RESPONSE = "com.example.imtbf.debug.RESPONSE";
    
    // Commands
    public static final String COMMAND_START = "start";
    public static final String COMMAND_PAUSE = "pause";
    public static final String COMMAND_RESUME = "resume";
    public static final String COMMAND_STOP = "stop";
    public static final String COMMAND_SET_URL = "set_url";
    public static final String COMMAND_SET_ITERATIONS = "set_iterations";
    public static final String COMMAND_SET_MIN_INTERVAL = "set_min_interval";
    public static final String COMMAND_SET_MAX_INTERVAL = "set_max_interval";
    public static final String COMMAND_SET_AIRPLANE_DELAY = "set_airplane_delay";
    public static final String COMMAND_TOGGLE_FEATURE = "toggle_feature";
    public static final String COMMAND_EXPORT_CONFIG = "export_config";
    public static final String COMMAND_IMPORT_CONFIG = "import_config";
    public static final String COMMAND_GET_STATUS = "get_status";
    public static final String COMMAND_GET_DETAILED_STATUS = "get_detailed_status";
    public static final String COMMAND_LIST_CONFIGS = "list_configs";
    
    // Feature keys for toggle_feature command
    public static final Map<String, String> FEATURE_KEYS = new HashMap<String, String>() {{
        put("rotate_ip", "rotate_ip");
        put("random_devices", "use_random_device_profile");
        put("webview_mode", "use_webview_mode");
        put("aggressive_clearing", "aggressive_session_clearing_enabled");
        put("new_webview_per_request", "new_webview_per_request_enabled");
        put("handle_redirects", "handle_marketing_redirects_enabled");
    }};

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !ACTION_COMMAND.equals(intent.getAction())) {
            Logger.e(TAG, "Intent is null or action doesn't match: " + (intent != null ? intent.getAction() : "null"));
            return;
        }

        String command = intent.getStringExtra("command");
        if (command == null) {
            Logger.e(TAG, "Received intent without command");
            return;
        }

        Logger.i(TAG, "Received command: " + command + " with extras: " + intent.getExtras());
        
        // Handle the command
        try {
            processCommand(context, command, intent.getExtras());
        } catch (Exception e) {
            Logger.e(TAG, "Error processing command: " + command, e);
            sendResponse(context, false, "Error: " + e.getMessage());
        }
    }
    
    /**
     * Process the received command
     * 
     * @param context Application context
     * @param command The command to process
     * @param extras Intent extras containing command parameters
     */
    private void processCommand(Context context, String command, Bundle extras) {
        PreferencesManager preferencesManager = 
                ((InstagramTrafficSimulatorApp) context.getApplicationContext())
                .getPreferencesManager();
        
        boolean settingsChanged = false;

        switch (command) {
            case COMMAND_START:
                CommandExecutor.executeStart(context);
                sendResponse(context, true, "Simulation started");
                break;
                
            case COMMAND_PAUSE:
                CommandExecutor.executePause(context);
                sendResponse(context, true, "Simulation paused");
                break;
                
            case COMMAND_RESUME:
                CommandExecutor.executeResume(context);
                sendResponse(context, true, "Simulation resumed");
                break;
                
            case COMMAND_STOP:
                CommandExecutor.executeStop(context);
                sendResponse(context, true, "Simulation stopped");
                break;
                
            case COMMAND_SET_URL:
                String url = extras.getString("value");
                if (url != null && !url.isEmpty()) {
                    preferencesManager.setTargetUrl(url);
                    sendResponse(context, true, "URL set to: " + url);
                    settingsChanged = true;
                } else {
                    sendResponse(context, false, "Invalid URL value");
                }
                break;
                
            case COMMAND_SET_ITERATIONS:
                if (extras.containsKey("value")) {
                    int iterations = extras.getInt("value");
                    if (iterations > 0) {
                        preferencesManager.setIterations(iterations);
                        sendResponse(context, true, "Iterations set to: " + iterations);
                        settingsChanged = true;
                    } else {
                        sendResponse(context, false, "Iterations must be > 0");
                    }
                } else {
                    sendResponse(context, false, "Missing value parameter");
                }
                break;
                
            case COMMAND_SET_MIN_INTERVAL:
                if (extras.containsKey("value")) {
                    int minInterval = extras.getInt("value");
                    if (minInterval > 0) {
                        preferencesManager.setMinInterval(minInterval);
                        sendResponse(context, true, "Min interval set to: " + minInterval);
                        settingsChanged = true;
                    } else {
                        sendResponse(context, false, "Min interval must be > 0");
                    }
                } else {
                    sendResponse(context, false, "Missing value parameter");
                }
                break;
                
            case COMMAND_SET_MAX_INTERVAL:
                if (extras.containsKey("value")) {
                    int maxInterval = extras.getInt("value");
                    if (maxInterval > 0) {
                        preferencesManager.setMaxInterval(maxInterval);
                        sendResponse(context, true, "Max interval set to: " + maxInterval);
                        settingsChanged = true;
                    } else {
                        sendResponse(context, false, "Max interval must be > 0");
                    }
                } else {
                    sendResponse(context, false, "Missing value parameter");
                }
                break;
                
            case COMMAND_SET_AIRPLANE_DELAY:
                if (extras.containsKey("value")) {
                    int delay = extras.getInt("value");
                    if (delay >= 1000) {
                        preferencesManager.setAirplaneModeDelay(delay);
                        sendResponse(context, true, "Airplane mode delay set to: " + delay);
                        settingsChanged = true;
                    } else {
                        sendResponse(context, false, "Delay must be >= 1000ms");
                    }
                } else {
                    sendResponse(context, false, "Missing value parameter");
                }
                break;
                
            case COMMAND_TOGGLE_FEATURE:
                String feature = extras.getString("feature");
                if (feature != null && FEATURE_KEYS.containsKey(feature)) {
                    if (extras.containsKey("value")) {
                        boolean value = extras.getBoolean("value");
                        String prefKey = FEATURE_KEYS.get(feature);
                        
                        // Set the preference based on the feature key
                        if (prefKey.equals("use_webview_mode")) {
                            preferencesManager.setUseWebViewMode(value);
                        } else if (prefKey.equals("aggressive_session_clearing_enabled")) {
                            preferencesManager.setAggressiveSessionClearingEnabled(value);
                        } else if (prefKey.equals("new_webview_per_request_enabled")) {
                            preferencesManager.setNewWebViewPerRequestEnabled(value);
                        } else if (prefKey.equals("handle_marketing_redirects_enabled")) {
                            preferencesManager.setHandleMarketingRedirectsEnabled(value);
                        } else {
                            // Generic boolean preference
                            preferencesManager.setBoolean(prefKey, value);
                        }
                        
                        sendResponse(context, true, "Feature '" + feature + "' set to: " + value);
                        settingsChanged = true;
                    } else {
                        sendResponse(context, false, "Missing value parameter");
                    }
                } else {
                    sendResponse(context, false, "Unknown feature: " + feature);
                }
                break;
                
            case COMMAND_EXPORT_CONFIG:
                String configName = extras.getString("name");
                String configDesc = extras.getString("desc", "");
                
                if (configName != null && !configName.isEmpty()) {
                    ConfigurationManager configManager = new ConfigurationManager(context, preferencesManager);
                    AppConfiguration config = configManager.createConfigurationFromCurrentSettings(configName, configDesc);
                    File configFile = configManager.exportConfiguration(config);
                    
                    if (configFile != null) {
                        sendResponse(context, true, "Configuration exported to: " + configFile.getName());
                    } else {
                        sendResponse(context, false, "Failed to export configuration");
                    }
                } else {
                    sendResponse(context, false, "Missing configuration name");
                }
                break;
                
            case COMMAND_IMPORT_CONFIG:
                String fileName = extras.getString("name");
                
                if (fileName != null && !fileName.isEmpty()) {
                    ConfigurationManager configManager = new ConfigurationManager(context, preferencesManager);
                    File configFile = null;
                    
                    // Search for the file by name
                    for (File file : configManager.getSavedConfigurations()) {
                        if (file.getName().equals(fileName) || 
                            (file.getName().endsWith(".json") && fileName.equals(file.getName().replace(".json", "")))) {
                            configFile = file;
                            break;
                        }
                    }
                    
                    if (configFile != null) {
                        AppConfiguration config = configManager.importConfiguration(configFile);
                        if (config != null) {
                            configManager.applyConfigurationToSettings(config);
                            sendResponse(context, true, "Configuration imported: " + fileName);
                            settingsChanged = true;
                        } else {
                            sendResponse(context, false, "Failed to import configuration: invalid format");
                        }
                    } else {
                        sendResponse(context, false, "Configuration file not found: " + fileName);
                    }
                } else {
                    sendResponse(context, false, "Missing configuration name");
                }
                break;
                
            case COMMAND_GET_STATUS:
                boolean isRunning = preferencesManager.isSimulationRunning();
                String statusUrl = preferencesManager.getTargetUrl();
                int iterations = preferencesManager.getIterations();
                
                StringBuilder status = new StringBuilder();
                status.append("Status: ").append(isRunning ? "Running" : "Stopped").append("\n");
                status.append("URL: ").append(statusUrl).append("\n");
                status.append("Iterations: ").append(iterations).append("\n");
                status.append("Min Interval: ").append(preferencesManager.getMinInterval()).append("\n");
                status.append("Max Interval: ").append(preferencesManager.getMaxInterval()).append("\n");
                status.append("Delay Min: ").append(preferencesManager.getInt("delay_min", 1)).append("\n");
                status.append("Delay Max: ").append(preferencesManager.getInt("delay_max", 2)).append("\n");
                
                sendResponse(context, true, status.toString());
                break;
                
            case COMMAND_GET_DETAILED_STATUS:
                // Get timing information from MainActivity
                Intent detailedStatusIntent = new Intent("com.example.imtbf.GET_DETAILED_STATUS");
                detailedStatusIntent.setPackage(context.getPackageName());
                context.sendBroadcast(detailedStatusIntent);
                
                // Log detailed status for retrieval via logcat
                Logger.i(TAG, "Detailed status requested via ADB");
                
                sendResponse(context, true, "Detailed status logged");
                break;
                
            case COMMAND_LIST_CONFIGS:
                ConfigurationManager configManager = new ConfigurationManager(context, preferencesManager);
                StringBuilder configs = new StringBuilder("Available configurations:\n");
                
                for (File file : configManager.getSavedConfigurations()) {
                    configs.append("- ").append(file.getName()).append("\n");
                }
                
                sendResponse(context, true, configs.toString());
                break;
                
            default:
                sendResponse(context, false, "Unknown command: " + command);
                break;
        }
        
        // If settings were changed, tell MainActivity to reload its UI
        if (settingsChanged) {
            refreshMainActivityUI(context);
        }
    }
    
    /**
     * Refresh the MainActivity UI after settings changes.
     * This sends a broadcast that will be received by MainActivity
     * to reload its UI with new settings.
     * 
     * @param context Application context
     */
    private void refreshMainActivityUI(Context context) {
        try {
            Logger.i(TAG, "Sending UI refresh broadcast");
            
            // Send broadcast to refresh UI
            Intent refreshIntent = new Intent("com.example.imtbf.REFRESH_UI");
            refreshIntent.setPackage(context.getPackageName());
            context.sendBroadcast(refreshIntent);
            
            // Also send direct intent to MainActivity as a backup method
            Intent directIntent = new Intent(context, MainActivity.class);
            directIntent.setAction("com.example.imtbf.REFRESH_UI");
            directIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(directIntent);
            
            Logger.i(TAG, "UI refresh signals sent");
        } catch (Exception e) {
            Logger.e(TAG, "Error sending UI refresh signal", e);
        }
    }
    
    /**
     * Send a response back as a broadcast
     * 
     * @param context Application context
     * @param success Whether the command was successful
     * @param message Response message
     */
    private void sendResponse(Context context, boolean success, String message) {
        Intent responseIntent = new Intent(ACTION_RESPONSE);
        responseIntent.putExtra("success", success);
        responseIntent.putExtra("message", message);
        
        // Log the response
        Logger.i(TAG, "Response: " + (success ? "SUCCESS" : "FAILED") + " - " + message);
        
        // Send the broadcast
        context.sendBroadcast(responseIntent);
        
        // Also show a toast for debugging purposes
        // This can be removed in production
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show();
    }
} 