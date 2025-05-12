package com.example.imtbf.data.local;

import android.content.Context;
import android.os.Environment;
import android.util.Log;

import com.example.imtbf.data.models.AppConfiguration;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Manages configuration import/export functionality
 */
public class ConfigurationManager {
    private static final String TAG = "ConfigurationManager";
    private static final String CONFIG_DIRECTORY = "DronoConfigs";
    private static final String CONFIG_EXTENSION = ".json";
    
    private final Context context;
    private final PreferencesManager preferencesManager;
    private final Gson gson;
    private File configDirectory;
    
    /**
     * Constructor
     * @param context Application context
     * @param preferencesManager Preferences manager instance
     */
    public ConfigurationManager(Context context, PreferencesManager preferencesManager) {
        this.context = context;
        this.preferencesManager = preferencesManager;
        this.gson = new GsonBuilder().setPrettyPrinting().create();
        initializeConfigDirectory();
    }
    
    /**
     * Initialize the configuration directory
     */
    private void initializeConfigDirectory() {
        // Try to use Downloads directory first
        File downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
        configDirectory = new File(downloadDir, CONFIG_DIRECTORY);
        
        // If we can't access Downloads, use app-specific directory
        if (!configDirectory.exists() && !configDirectory.mkdirs()) {
            configDirectory = new File(context.getExternalFilesDir(null), CONFIG_DIRECTORY);
            if (!configDirectory.exists() && !configDirectory.mkdirs()) {
                Log.e(TAG, "Failed to create configuration directory");
            }
        }
        
        Log.i(TAG, "Configuration directory: " + configDirectory.getAbsolutePath());
    }
    
    /**
     * Create an AppConfiguration from current settings
     * @param configName Name for the configuration
     * @param description Optional description
     * @return AppConfiguration object
     */
    public AppConfiguration createConfigurationFromCurrentSettings(String configName, String description) {
        return AppConfiguration.builder()
                .configName(configName)
                .description(description)
                .targetUrl(preferencesManager.getTargetUrl())
                .minInterval(preferencesManager.getMinInterval())
                .maxInterval(preferencesManager.getMaxInterval())
                .iterations(preferencesManager.getIterations())
                .airplaneModeDelay(preferencesManager.getAirplaneModeDelay())
                .delayMin(preferencesManager.getInt("delay_min", 1))
                .delayMax(preferencesManager.getInt("delay_max", 5))
                .useWebViewMode(preferencesManager.getUseWebViewMode())
                .newWebViewPerRequest(preferencesManager.isNewWebViewPerRequestEnabled())
                .handleMarketingRedirects(preferencesManager.isHandleMarketingRedirectsEnabled())
                .aggressiveSessionClearing(preferencesManager.isAggressiveSessionClearingEnabled())
                .rotateIp(preferencesManager.getBoolean("rotate_ip", true))
                .useRandomDeviceProfile(preferencesManager.getBoolean("use_random_device_profile", true))
                .scheduledModeEnabled(preferencesManager.isScheduledModeEnabled())
                .distributionPattern(preferencesManager.getDistributionPattern())
                .distributionDurationHours(preferencesManager.getDistributionDurationHours())
                .peakHourStart(preferencesManager.getPeakHourStart())
                .peakHourEnd(preferencesManager.getPeakHourEnd())
                .peakTrafficWeight(preferencesManager.getPeakTrafficWeight())
                .build();
    }
    
    /**
     * Apply a configuration to the app settings
     * @param config AppConfiguration to apply
     */
    public void applyConfigurationToSettings(AppConfiguration config) {
        preferencesManager.setTargetUrl(config.getTargetUrl());
        preferencesManager.setMinInterval(config.getMinInterval());
        preferencesManager.setMaxInterval(config.getMaxInterval());
        preferencesManager.setIterations(config.getIterations());
        preferencesManager.setAirplaneModeDelay(config.getAirplaneModeDelay());
        preferencesManager.setInt("delay_min", config.getDelayMin());
        preferencesManager.setInt("delay_max", config.getDelayMax());
        preferencesManager.setUseWebViewMode(config.isUseWebViewMode());
        preferencesManager.setNewWebViewPerRequestEnabled(config.isNewWebViewPerRequest());
        preferencesManager.setHandleMarketingRedirectsEnabled(config.isHandleMarketingRedirects());
        preferencesManager.setAggressiveSessionClearingEnabled(config.isAggressiveSessionClearing());
        preferencesManager.setBoolean("rotate_ip", config.isRotateIp());
        preferencesManager.setBoolean("use_random_device_profile", config.isUseRandomDeviceProfile());
        preferencesManager.setScheduledModeEnabled(config.isScheduledModeEnabled());
        preferencesManager.setDistributionPattern(config.getDistributionPattern());
        preferencesManager.setDistributionDurationHours(config.getDistributionDurationHours());
        preferencesManager.setPeakHourStart(config.getPeakHourStart());
        preferencesManager.setPeakHourEnd(config.getPeakHourEnd());
        preferencesManager.setPeakTrafficWeight(config.getPeakTrafficWeight());
    }
    
    /**
     * Export a configuration to a file
     * @param config Configuration to export
     * @return File where configuration was saved, or null if failed
     */
    public File exportConfiguration(AppConfiguration config) {
        if (config.getConfigName() == null || config.getConfigName().isEmpty()) {
            String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            config.setConfigName("config_" + timestamp);
        }
        
        String filename = sanitizeFilename(config.getConfigName()) + CONFIG_EXTENSION;
        File configFile = new File(configDirectory, filename);
        
        try (FileWriter writer = new FileWriter(configFile)) {
            gson.toJson(config, writer);
            Log.i(TAG, "Configuration exported to: " + configFile.getAbsolutePath());
            return configFile;
        } catch (IOException e) {
            Log.e(TAG, "Failed to export configuration", e);
            return null;
        }
    }
    
    /**
     * Import a configuration from a file
     * @param configFile File to import from
     * @return Imported AppConfiguration or null if failed
     */
    public AppConfiguration importConfiguration(File configFile) {
        try (BufferedReader reader = new BufferedReader(new FileReader(configFile))) {
            AppConfiguration config = gson.fromJson(reader, AppConfiguration.class);
            Log.i(TAG, "Configuration imported from: " + configFile.getAbsolutePath());
            return config;
        } catch (IOException e) {
            Log.e(TAG, "Failed to import configuration", e);
            return null;
        }
    }
    
    /**
     * Get list of saved configurations
     * @return List of configuration files
     */
    public List<File> getSavedConfigurations() {
        List<File> configFiles = new ArrayList<>();
        if (configDirectory.exists() && configDirectory.isDirectory()) {
            File[] files = configDirectory.listFiles((dir, name) -> name.endsWith(CONFIG_EXTENSION));
            if (files != null) {
                for (File file : files) {
                    configFiles.add(file);
                }
            }
        }
        return configFiles;
    }
    
    /**
     * Get the configuration directory
     * @return Configuration directory
     */
    public File getConfigDirectory() {
        return configDirectory;
    }
    
    /**
     * Sanitize a filename to remove invalid characters
     * @param filename Filename to sanitize
     * @return Sanitized filename
     */
    private String sanitizeFilename(String filename) {
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
} 