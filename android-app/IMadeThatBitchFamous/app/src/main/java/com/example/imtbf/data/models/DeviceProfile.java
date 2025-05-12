package com.example.imtbf.data.models;

import java.util.Random;
/**
 * Represents a device profile with all information needed for fingerprinting.
 * This class holds information about the device type, platform, and user agent.
 */
public class DeviceProfile {

    // Device type constants
    public static final String TYPE_MOBILE = "mobile";
    public static final String TYPE_TABLET = "tablet";
    public static final String TYPE_DESKTOP = "desktop";

    // Platform constants
    public static final String PLATFORM_ANDROID = "android";
    public static final String PLATFORM_IOS = "ios";
    public static final String PLATFORM_WINDOWS = "windows";
    public static final String PLATFORM_MAC = "mac";
    public static final String PLATFORM_LINUX = "linux";

    // Tier constants
    public static final String TIER_BUDGET = "budget";
    public static final String TIER_MID_RANGE = "mid-range";
    public static final String TIER_FLAGSHIP = "flagship";
    public static final String TIER_MIXED = "mixed";

    private String deviceType;
    private String platform;
    private String deviceTier;
    private String deviceModel;
    private String userAgent;
    private int screenWidth;
    private int screenHeight;
    private String browserName;
    private String browserVersion;
    private boolean isMobile;
    private boolean supportsTouch;
    private String region;

    /**
     * Default constructor.
     */
    public DeviceProfile() {
        // Default constructor
    }

    /**
     * Constructor with essential parameters.
     */
    public DeviceProfile(String deviceType, String platform, String deviceTier,
                         String userAgent, String region) {
        this.deviceType = deviceType;
        this.platform = platform;
        this.deviceTier = deviceTier;
        this.userAgent = userAgent;
        this.region = region;
        this.isMobile = TYPE_MOBILE.equals(deviceType) || TYPE_TABLET.equals(deviceType);
        this.supportsTouch = isMobile;
    }

    /**
     * Get the device type (mobile, tablet, desktop).
     * @return Device type
     */
    public String getDeviceType() {
        return deviceType;
    }

    /**
     * Set the device type.
     * @param deviceType Device type
     */
    public void setDeviceType(String deviceType) {
        this.deviceType = deviceType;
        // Update isMobile based on device type
        this.isMobile = TYPE_MOBILE.equals(deviceType) || TYPE_TABLET.equals(deviceType);
    }

    private boolean isInstagramApp;

    /**
     * Check if this profile represents an Instagram app user.
     * @return True if this is an Instagram app user, false for browser
     */
    public boolean isInstagramApp() {
        return isInstagramApp;
    }

    /**
     * Set whether this profile represents an Instagram app user.
     * @param isInstagramApp True if this is an Instagram app user
     */
    public void setIsInstagramApp(boolean isInstagramApp) {
        this.isInstagramApp = isInstagramApp;
    }


    /**
     * Get the platform (android, ios, windows, mac, linux).
     * @return Platform
     */
    public String getPlatform() {
        return platform;
    }

    /**
     * Set the platform.
     * @param platform Platform
     */
    public void setPlatform(String platform) {
        this.platform = platform;
    }

    /**
     * Get the device tier (budget, mid-range, flagship, mixed).
     * @return Device tier
     */
    public String getDeviceTier() {
        return deviceTier;
    }

    /**
     * Set the device tier.
     * @param deviceTier Device tier
     */
    public void setDeviceTier(String deviceTier) {
        this.deviceTier = deviceTier;
    }

    /**
     * Get the device model.
     * @return Device model
     */
    public String getDeviceModel() {
        return deviceModel;
    }

    /**
     * Set the device model.
     * @param deviceModel Device model
     */
    public void setDeviceModel(String deviceModel) {
        this.deviceModel = deviceModel;
    }

    /**
     * Get the user agent string.
     * @return User agent string
     */
    public String getUserAgent() {
        return userAgent;
    }

    /**
     * Set the user agent string.
     * @param userAgent User agent string
     */
    public void setUserAgent(String userAgent) {
        this.userAgent = userAgent;
    }

    /**
     * Get the screen width.
     * @return Screen width
     */
    public int getScreenWidth() {
        return screenWidth;
    }

    /**
     * Set the screen width.
     * @param screenWidth Screen width
     */
    public void setScreenWidth(int screenWidth) {
        this.screenWidth = screenWidth;
    }

    /**
     * Get the screen height.
     * @return Screen height
     */
    public int getScreenHeight() {
        return screenHeight;
    }

    /**
     * Set the screen height.
     * @param screenHeight Screen height
     */
    public void setScreenHeight(int screenHeight) {
        this.screenHeight = screenHeight;
    }

    /**
     * Get the browser name.
     * @return Browser name
     */
    public String getBrowserName() {
        return browserName;
    }

    /**
     * Set the browser name.
     * @param browserName Browser name
     */
    public void setBrowserName(String browserName) {
        this.browserName = browserName;
    }

    /**
     * Get the browser version.
     * @return Browser version
     */
    public String getBrowserVersion() {
        return browserVersion;
    }

    /**
     * Set the browser version.
     * @param browserVersion Browser version
     */
    public void setBrowserVersion(String browserVersion) {
        this.browserVersion = browserVersion;
    }

    /**
     * Check if the device is mobile.
     * @return True if the device is mobile, false otherwise
     */
    public boolean isMobile() {
        return isMobile;
    }

    /**
     * Check if the device supports touch.
     * @return True if the device supports touch, false otherwise
     */
    public boolean isSupportsTouch() {
        return supportsTouch;
    }

    /**
     * Set whether the device supports touch.
     * @param supportsTouch True if the device supports touch, false otherwise
     */
    public void setSupportsTouch(boolean supportsTouch) {
        this.supportsTouch = supportsTouch;
    }

    /**
     * Get the region for this device profile.
     * @return Region
     */
    public String getRegion() {
        return region;
    }

    /**
     * Set the region for this device profile.
     * @param region Region
     */
    public void setRegion(String region) {
        this.region = region;
    }

    /**
     * Builder for DeviceProfile.
     */
    public static class Builder {
        private final DeviceProfile profile;


        public Builder() {
            profile = new DeviceProfile();
        }

        public Builder deviceType(String deviceType) {
            profile.setDeviceType(deviceType);
            return this;
        }

        public Builder platform(String platform) {
            profile.setPlatform(platform);
            return this;
        }

        public Builder deviceTier(String deviceTier) {
            profile.setDeviceTier(deviceTier);
            return this;
        }

        public Builder deviceModel(String deviceModel) {
            profile.setDeviceModel(deviceModel);
            return this;
        }

        public Builder userAgent(String userAgent) {
            profile.setUserAgent(userAgent);
            return this;
        }

        public Builder screenWidth(int screenWidth) {
            profile.setScreenWidth(screenWidth);
            return this;
        }

        public Builder screenHeight(int screenHeight) {
            profile.setScreenHeight(screenHeight);
            return this;
        }

        public Builder browserName(String browserName) {
            profile.setBrowserName(browserName);
            return this;
        }

        public Builder browserVersion(String browserVersion) {
            profile.setBrowserVersion(browserVersion);
            return this;
        }

        public Builder supportsTouch(boolean supportsTouch) {
            profile.setSupportsTouch(supportsTouch);
            return this;
        }

        public Builder region(String region) {
            profile.setRegion(region);
            return this;
        }

        public Builder isInstagramApp(boolean isInstagramApp) {
            profile.setIsInstagramApp(isInstagramApp);
            return this;
        }

        public DeviceProfile build() {
            return profile;
        }
    }
}