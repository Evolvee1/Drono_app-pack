package com.example.imtbf2.data.models;

import java.util.HashMap;
import java.util.Map;

/**
 * Model representing the complete app configuration that can be serialized to JSON.
 */
public class AppConfiguration {
    // Basic settings
    private String targetUrl;
    private int minInterval;
    private int maxInterval;
    private int iterations;
    private int airplaneModeDelay;
    private int delayMin;
    private int delayMax;
    
    // Feature toggles
    private boolean useWebViewMode;
    private boolean newWebViewPerRequest;
    private boolean handleMarketingRedirects;
    private boolean aggressiveSessionClearing;
    private boolean rotateIp;
    private boolean useRandomDeviceProfile;
    
    // Distribution settings
    private boolean scheduledModeEnabled;
    private String distributionPattern;
    private int distributionDurationHours;
    private int peakHourStart;
    private int peakHourEnd;
    private float peakTrafficWeight;
    
    // Custom settings
    private Map<String, Object> additionalSettings;
    
    // Metadata
    private String configName;
    private String description;
    private long createdTimestamp;
    private long lastModifiedTimestamp;
    private String version;
    
    /**
     * Default constructor required for JSON serialization
     */
    public AppConfiguration() {
        additionalSettings = new HashMap<>();
        createdTimestamp = System.currentTimeMillis();
        lastModifiedTimestamp = createdTimestamp;
        version = "1.0";
    }
    
    /**
     * Get the target URL for simulation
     * @return Target URL
     */
    public String getTargetUrl() {
        return targetUrl;
    }
    
    /**
     * Set the target URL for simulation
     * @param targetUrl Target URL
     */
    public void setTargetUrl(String targetUrl) {
        this.targetUrl = targetUrl;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the minimum interval between requests in seconds
     * @return Minimum interval
     */
    public int getMinInterval() {
        return minInterval;
    }
    
    /**
     * Set the minimum interval between requests in seconds
     * @param minInterval Minimum interval
     */
    public void setMinInterval(int minInterval) {
        this.minInterval = minInterval;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the maximum interval between requests in seconds
     * @return Maximum interval
     */
    public int getMaxInterval() {
        return maxInterval;
    }
    
    /**
     * Set the maximum interval between requests in seconds
     * @param maxInterval Maximum interval
     */
    public void setMaxInterval(int maxInterval) {
        this.maxInterval = maxInterval;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the number of iterations for the simulation
     * @return Number of iterations
     */
    public int getIterations() {
        return iterations;
    }
    
    /**
     * Set the number of iterations for the simulation
     * @param iterations Number of iterations
     */
    public void setIterations(int iterations) {
        this.iterations = iterations;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the airplane mode toggle delay in milliseconds
     * @return Airplane mode delay
     */
    public int getAirplaneModeDelay() {
        return airplaneModeDelay;
    }
    
    /**
     * Set the airplane mode toggle delay in milliseconds
     * @param airplaneModeDelay Airplane mode delay
     */
    public void setAirplaneModeDelay(int airplaneModeDelay) {
        this.airplaneModeDelay = airplaneModeDelay;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the minimum delay between iterations in seconds
     * @return Minimum delay
     */
    public int getDelayMin() {
        return delayMin;
    }
    
    /**
     * Set the minimum delay between iterations in seconds
     * @param delayMin Minimum delay
     */
    public void setDelayMin(int delayMin) {
        this.delayMin = delayMin;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the maximum delay between iterations in seconds
     * @return Maximum delay
     */
    public int getDelayMax() {
        return delayMax;
    }
    
    /**
     * Set the maximum delay between iterations in seconds
     * @param delayMax Maximum delay
     */
    public void setDelayMax(int delayMax) {
        this.delayMax = delayMax;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if WebView mode is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isUseWebViewMode() {
        return useWebViewMode;
    }
    
    /**
     * Set whether WebView mode is enabled
     * @param useWebViewMode True to enable, false to disable
     */
    public void setUseWebViewMode(boolean useWebViewMode) {
        this.useWebViewMode = useWebViewMode;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if new WebView per request is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isNewWebViewPerRequest() {
        return newWebViewPerRequest;
    }
    
    /**
     * Set whether new WebView per request is enabled
     * @param newWebViewPerRequest True to enable, false to disable
     */
    public void setNewWebViewPerRequest(boolean newWebViewPerRequest) {
        this.newWebViewPerRequest = newWebViewPerRequest;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if marketing redirects handling is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isHandleMarketingRedirects() {
        return handleMarketingRedirects;
    }
    
    /**
     * Set whether marketing redirects handling is enabled
     * @param handleMarketingRedirects True to enable, false to disable
     */
    public void setHandleMarketingRedirects(boolean handleMarketingRedirects) {
        this.handleMarketingRedirects = handleMarketingRedirects;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if aggressive session clearing is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isAggressiveSessionClearing() {
        return aggressiveSessionClearing;
    }
    
    /**
     * Set whether aggressive session clearing is enabled
     * @param aggressiveSessionClearing True to enable, false to disable
     */
    public void setAggressiveSessionClearing(boolean aggressiveSessionClearing) {
        this.aggressiveSessionClearing = aggressiveSessionClearing;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if IP rotation is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isRotateIp() {
        return rotateIp;
    }
    
    /**
     * Set whether IP rotation is enabled
     * @param rotateIp True to enable, false to disable
     */
    public void setRotateIp(boolean rotateIp) {
        this.rotateIp = rotateIp;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if random device profile is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isUseRandomDeviceProfile() {
        return useRandomDeviceProfile;
    }
    
    /**
     * Set whether random device profile is enabled
     * @param useRandomDeviceProfile True to enable, false to disable
     */
    public void setUseRandomDeviceProfile(boolean useRandomDeviceProfile) {
        this.useRandomDeviceProfile = useRandomDeviceProfile;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Check if scheduled mode is enabled
     * @return True if enabled, false otherwise
     */
    public boolean isScheduledModeEnabled() {
        return scheduledModeEnabled;
    }
    
    /**
     * Set whether scheduled mode is enabled
     * @param scheduledModeEnabled True to enable, false to disable
     */
    public void setScheduledModeEnabled(boolean scheduledModeEnabled) {
        this.scheduledModeEnabled = scheduledModeEnabled;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the distribution pattern
     * @return Distribution pattern
     */
    public String getDistributionPattern() {
        return distributionPattern;
    }
    
    /**
     * Set the distribution pattern
     * @param distributionPattern Distribution pattern
     */
    public void setDistributionPattern(String distributionPattern) {
        this.distributionPattern = distributionPattern;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the distribution duration in hours
     * @return Distribution duration
     */
    public int getDistributionDurationHours() {
        return distributionDurationHours;
    }
    
    /**
     * Set the distribution duration in hours
     * @param distributionDurationHours Distribution duration
     */
    public void setDistributionDurationHours(int distributionDurationHours) {
        this.distributionDurationHours = distributionDurationHours;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the peak hour start time (0-23)
     * @return Peak hour start
     */
    public int getPeakHourStart() {
        return peakHourStart;
    }
    
    /**
     * Set the peak hour start time (0-23)
     * @param peakHourStart Peak hour start
     */
    public void setPeakHourStart(int peakHourStart) {
        this.peakHourStart = peakHourStart;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the peak hour end time (0-23)
     * @return Peak hour end
     */
    public int getPeakHourEnd() {
        return peakHourEnd;
    }
    
    /**
     * Set the peak hour end time (0-23)
     * @param peakHourEnd Peak hour end
     */
    public void setPeakHourEnd(int peakHourEnd) {
        this.peakHourEnd = peakHourEnd;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the peak traffic weight factor (0.0-1.0)
     * @return Peak traffic weight
     */
    public float getPeakTrafficWeight() {
        return peakTrafficWeight;
    }
    
    /**
     * Set the peak traffic weight factor (0.0-1.0)
     * @param peakTrafficWeight Peak traffic weight
     */
    public void setPeakTrafficWeight(float peakTrafficWeight) {
        this.peakTrafficWeight = peakTrafficWeight;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get additional settings as a map
     * @return Map of additional settings
     */
    public Map<String, Object> getAdditionalSettings() {
        return additionalSettings;
    }
    
    /**
     * Set additional settings as a map
     * @param additionalSettings Map of additional settings
     */
    public void setAdditionalSettings(Map<String, Object> additionalSettings) {
        this.additionalSettings = additionalSettings;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Add an additional setting
     * @param key Setting key
     * @param value Setting value
     */
    public void addAdditionalSetting(String key, Object value) {
        if (additionalSettings == null) {
            additionalSettings = new HashMap<>();
        }
        additionalSettings.put(key, value);
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the configuration name
     * @return Configuration name
     */
    public String getConfigName() {
        return configName;
    }
    
    /**
     * Set the configuration name
     * @param configName Configuration name
     */
    public void setConfigName(String configName) {
        this.configName = configName;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the configuration description
     * @return Configuration description
     */
    public String getDescription() {
        return description;
    }
    
    /**
     * Set the configuration description
     * @param description Configuration description
     */
    public void setDescription(String description) {
        this.description = description;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Get the configuration creation timestamp
     * @return Creation timestamp
     */
    public long getCreatedTimestamp() {
        return createdTimestamp;
    }
    
    /**
     * Set the configuration creation timestamp
     * @param createdTimestamp Creation timestamp
     */
    public void setCreatedTimestamp(long createdTimestamp) {
        this.createdTimestamp = createdTimestamp;
    }
    
    /**
     * Get the configuration last modified timestamp
     * @return Last modified timestamp
     */
    public long getLastModifiedTimestamp() {
        return lastModifiedTimestamp;
    }
    
    /**
     * Get the configuration version
     * @return Configuration version
     */
    public String getVersion() {
        return version;
    }
    
    /**
     * Set the configuration version
     * @param version Configuration version
     */
    public void setVersion(String version) {
        this.version = version;
        this.lastModifiedTimestamp = System.currentTimeMillis();
    }
    
    /**
     * Create a builder for AppConfiguration
     * @return AppConfigurationBuilder
     */
    public static Builder builder() {
        return new Builder();
    }
    
    /**
     * Builder class for AppConfiguration
     */
    public static class Builder {
        private final AppConfiguration config;
        
        /**
         * Constructor
         */
        public Builder() {
            config = new AppConfiguration();
        }
        
        /**
         * Set the target URL
         * @param targetUrl Target URL
         * @return Builder
         */
        public Builder targetUrl(String targetUrl) {
            config.setTargetUrl(targetUrl);
            return this;
        }
        
        /**
         * Set the minimum interval
         * @param minInterval Minimum interval
         * @return Builder
         */
        public Builder minInterval(int minInterval) {
            config.setMinInterval(minInterval);
            return this;
        }
        
        /**
         * Set the maximum interval
         * @param maxInterval Maximum interval
         * @return Builder
         */
        public Builder maxInterval(int maxInterval) {
            config.setMaxInterval(maxInterval);
            return this;
        }
        
        /**
         * Set the number of iterations
         * @param iterations Number of iterations
         * @return Builder
         */
        public Builder iterations(int iterations) {
            config.setIterations(iterations);
            return this;
        }
        
        /**
         * Set the airplane mode delay
         * @param airplaneModeDelay Airplane mode delay
         * @return Builder
         */
        public Builder airplaneModeDelay(int airplaneModeDelay) {
            config.setAirplaneModeDelay(airplaneModeDelay);
            return this;
        }
        
        /**
         * Set the minimum delay
         * @param delayMin Minimum delay
         * @return Builder
         */
        public Builder delayMin(int delayMin) {
            config.setDelayMin(delayMin);
            return this;
        }
        
        /**
         * Set the maximum delay
         * @param delayMax Maximum delay
         * @return Builder
         */
        public Builder delayMax(int delayMax) {
            config.setDelayMax(delayMax);
            return this;
        }
        
        /**
         * Set whether WebView mode is enabled
         * @param useWebViewMode True to enable, false to disable
         * @return Builder
         */
        public Builder useWebViewMode(boolean useWebViewMode) {
            config.setUseWebViewMode(useWebViewMode);
            return this;
        }
        
        /**
         * Set whether new WebView per request is enabled
         * @param newWebViewPerRequest True to enable, false to disable
         * @return Builder
         */
        public Builder newWebViewPerRequest(boolean newWebViewPerRequest) {
            config.setNewWebViewPerRequest(newWebViewPerRequest);
            return this;
        }
        
        /**
         * Set whether marketing redirects handling is enabled
         * @param handleMarketingRedirects True to enable, false to disable
         * @return Builder
         */
        public Builder handleMarketingRedirects(boolean handleMarketingRedirects) {
            config.setHandleMarketingRedirects(handleMarketingRedirects);
            return this;
        }
        
        /**
         * Set whether aggressive session clearing is enabled
         * @param aggressiveSessionClearing True to enable, false to disable
         * @return Builder
         */
        public Builder aggressiveSessionClearing(boolean aggressiveSessionClearing) {
            config.setAggressiveSessionClearing(aggressiveSessionClearing);
            return this;
        }
        
        /**
         * Set whether IP rotation is enabled
         * @param rotateIp True to enable, false to disable
         * @return Builder
         */
        public Builder rotateIp(boolean rotateIp) {
            config.setRotateIp(rotateIp);
            return this;
        }
        
        /**
         * Set whether random device profile is enabled
         * @param useRandomDeviceProfile True to enable, false to disable
         * @return Builder
         */
        public Builder useRandomDeviceProfile(boolean useRandomDeviceProfile) {
            config.setUseRandomDeviceProfile(useRandomDeviceProfile);
            return this;
        }
        
        /**
         * Set whether scheduled mode is enabled
         * @param scheduledModeEnabled True to enable, false to disable
         * @return Builder
         */
        public Builder scheduledModeEnabled(boolean scheduledModeEnabled) {
            config.setScheduledModeEnabled(scheduledModeEnabled);
            return this;
        }
        
        /**
         * Set the distribution pattern
         * @param distributionPattern Distribution pattern
         * @return Builder
         */
        public Builder distributionPattern(String distributionPattern) {
            config.setDistributionPattern(distributionPattern);
            return this;
        }
        
        /**
         * Set the distribution duration
         * @param distributionDurationHours Distribution duration
         * @return Builder
         */
        public Builder distributionDurationHours(int distributionDurationHours) {
            config.setDistributionDurationHours(distributionDurationHours);
            return this;
        }
        
        /**
         * Set the peak hour start
         * @param peakHourStart Peak hour start
         * @return Builder
         */
        public Builder peakHourStart(int peakHourStart) {
            config.setPeakHourStart(peakHourStart);
            return this;
        }
        
        /**
         * Set the peak hour end
         * @param peakHourEnd Peak hour end
         * @return Builder
         */
        public Builder peakHourEnd(int peakHourEnd) {
            config.setPeakHourEnd(peakHourEnd);
            return this;
        }
        
        /**
         * Set the peak traffic weight
         * @param peakTrafficWeight Peak traffic weight
         * @return Builder
         */
        public Builder peakTrafficWeight(float peakTrafficWeight) {
            config.setPeakTrafficWeight(peakTrafficWeight);
            return this;
        }
        
        /**
         * Set the configuration name
         * @param configName Configuration name
         * @return Builder
         */
        public Builder configName(String configName) {
            config.setConfigName(configName);
            return this;
        }
        
        /**
         * Set the configuration description
         * @param description Configuration description
         * @return Builder
         */
        public Builder description(String description) {
            config.setDescription(description);
            return this;
        }
        
        /**
         * Build the AppConfiguration
         * @return AppConfiguration
         */
        public AppConfiguration build() {
            return config;
        }
    }
} 