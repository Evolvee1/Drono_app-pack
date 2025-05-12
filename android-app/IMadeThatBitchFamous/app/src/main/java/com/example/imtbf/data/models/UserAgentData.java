package com.example.imtbf.data.models;

import com.example.imtbf.utils.Logger;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.security.SecureRandom;


/**
 * Contains comprehensive data about user agents.
 * This class is used to manage and retrieve user agents based on various criteria.
 */
public class UserAgentData {

    private static final Random random = new Random();

    // Maps to store user agents by different criteria
    private static final Map<String, List<String>> deviceTypeUserAgents = new HashMap<>();
    private static final Map<String, List<String>> platformUserAgents = new HashMap<>();
    private static final Map<String, Map<String, List<String>>> deviceTierUserAgents = new HashMap<>();
    private static final Map<String, List<String>> browserUserAgents = new HashMap<>();
    private static final Map<String, Map<String, Float>> demographicDistributions = new HashMap<>();

    // Lists of user agents by category
    private static final List<String> androidUserAgents = new ArrayList<>();
    private static final List<String> iosUserAgents = new ArrayList<>();
    private static final List<String> windowsUserAgents = new ArrayList<>();
    private static final List<String> macUserAgents = new ArrayList<>();
    private static final List<String> instagramAppUserAgents = new ArrayList<>();

    private static final SecureRandom secureRandom = new SecureRandom();

    // Initialize with some sample user agents - this would be expanded in a real implementation
    static {
        // Initialize Android user agents
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; ONEPLUS A6013) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 12; moto g(60)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; M2101K6G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36");

        // Initialize iOS user agents
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPhone14,7; U; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 15_7_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.7 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1");

        // Initialize Windows user agents
        windowsUserAgents.add("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36");
        windowsUserAgents.add("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/112.0");
        windowsUserAgents.add("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36 Edg/112.0.1722.58");
        windowsUserAgents.add("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36 OPR/98.0.0.0");
        windowsUserAgents.add("Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36");

        // Initialize Mac user agents
        macUserAgents.add("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15");
        macUserAgents.add("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36");
        macUserAgents.add("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36 Edg/112.0.1722.58");
        macUserAgents.add("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/112.0");
        macUserAgents.add("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36 OPR/98.0.0.0");

        instagramAppUserAgents.add("Instagram 292.0.0.29.122 Android (33/13; 480dpi; 1080x2400; Google/google; Pixel 7; panther; arm64-v8a; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 293.1.0.21.111 Android (33/13; 420dpi; 1080x2340; samsung; SM-S918B; CS2; arm64-v8a; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 294.0.0.26.117 Android (31/12; 320dpi; 720x1600; Samsung; SM-A125F; a12; mt6765; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 295.0.0.14.109 Android (32/12; 440dpi; 1080x2340; Xiaomi/Redmi; Redmi Note 11; spes; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 291.1.0.34.111 Android (30/11; 440dpi; 1080x2400; OnePlus; Nord CE 2; OP535BL1; mt6877; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 296.0.0.31.111 Android (33/13; 480dpi; 1080x2340; Motorola; moto g71 5G; corfur; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 294.0.0.26.117 Android (29/10; 420dpi; 1080x2220; Huawei; P30 Lite; HWMAR; kirin710; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 297.0.0.29.101 Android (34/14; 560dpi; 1440x3200; Samsung; SM-S928B; CS3; exynos2400; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 295.0.0.14.109 Android (30/11; 280dpi; 720x1560; POCO; M3; angelica; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 293.0.0.27.111 Android (31/12; 440dpi; 1080x2400; Xiaomi; Redmi Note 10 Pro; sweet; qcom; sk_SK; " + generateInstagramInstallationId() + ")");

        // iOS Instagram app user agents - UPDATED with Slovak (sk_SK) versions
        instagramAppUserAgents.add("Instagram 291.0.0.31.111 iOS (17_5_1; iPhone14,7; sk_SK; sk-SK; scale=3.00; 1170x2532; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 292.0.0.25.111 iOS (17_2; iPhone15,4; sk_SK; sk-SK; scale=3.00; 1179x2556; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 293.1.0.21.111 iOS (16_6_1; iPhone12,1; sk_SK; sk-SK; scale=2.00; 828x1792; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 294.0.0.26.117 iOS (16_0; iPad13,1; sk_SK; sk-SK; scale=2.00; 1620x2160; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 290.0.0.16.111 iOS (15_7_8; iPhone11,8; sk_SK; sk-SK; scale=2.00; 828x1792; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 295.0.0.14.109 iOS (17_5_1; iPhone15,5; sk_SK; sk-SK; scale=3.00; 1290x2796; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 296.0.0.31.111 iOS (17_5; iPad12,1; sk_SK; sk-SK; scale=2.00; 1620x2160; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 294.0.0.26.117 iOS (16_7; iPhone13,4; sk_SK; sk-SK; scale=3.00; 1284x2778; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 297.0.0.29.101 iOS (17_6; iPhone14,3; sk_SK; sk-SK; scale=3.00; 1170x2532; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 298.0.0.23.118 iOS (17_6; iPhone14,8; sk_SK; sk-SK; scale=3.00; 1179x2556; " + generateInstagramInstallationId() + ")");

        // Additional Android Instagram app user agents (2018-2020)
        instagramAppUserAgents.add("Instagram 70.0.0.22.98 Android (26/8.0.0; 320dpi; 720x1280; Samsung; SM-A520F; a5y17lte; samsungexynos7880; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 125.0.0.18.125 Android (28/9.0; 440dpi; 1080x2220; Xiaomi; Mi 9T; davinci; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 167.0.0.24.120 Android (29/10; 380dpi; 1080x2280; OnePlus; ONEPLUS A6003; OnePlus6; qcom; sk_SK; " + generateInstagramInstallationId() + ")");

        // Additional Android Instagram app user agents (2021-2022)
        instagramAppUserAgents.add("Instagram 231.1.0.17.107 Android (30/11; 420dpi; 1080x2340; Samsung; SM-A525F; a52q; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 253.0.0.23.114 Android (31/12; 420dpi; 1080x2340; Xiaomi; M2101K6G; sweet; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 275.0.0.27.98 Android (31/12; 420dpi; 1080x2340; Xiaomi; Redmi Note 11; spes; qcom; sk_SK; " + generateInstagramInstallationId() + ")");

        // Additional Android Instagram app user agents (2023-2025)
        instagramAppUserAgents.add("Instagram 302.1.0.34.111 Android (33/13; 440dpi; 1080x2400; Samsung; SM-A536B; a53x; exynos1280; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 324.0.0.47.119 Android (33/13; 440dpi; 1080x2400; Xiaomi; Redmi Note 12; tapas; qcom; sk_SK; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 352.0.0.30.109 Android (34/14; 440dpi; 1080x2400; Xiaomi; 23030RAC7Y; ruby; mt6877t; sk_SK; " + generateInstagramInstallationId() + ")");

        // Additional iOS Instagram app user agents (2018-2020)
        instagramAppUserAgents.add("Instagram 70.0.0.14.96 iOS (11_4_1; iPhone8,2; sk_SK; sk-SK; scale=2.61; 1080x1920; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 123.0.0.21.114 iOS (13_3; iPhone11,8; sk_SK; sk-SK; scale=2.00; 828x1792; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 165.1.0.29.119 iOS (14_0; iPhone12,1; sk_SK; sk-SK; scale=2.00; 828x1792; " + generateInstagramInstallationId() + ")");

        // Additional iOS Instagram app user agents (2021-2022)
        instagramAppUserAgents.add("Instagram 234.0.0.10.111 iOS (15_0; iPhone13,2; sk_SK; sk-SK; scale=3.00; 1170x2532; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 255.0.0.17.102 iOS (15_4; iPhone13,4; sk_SK; sk-SK; scale=3.00; 1284x2778; " + generateInstagramInstallationId() + ")");

        // Additional iOS Instagram app user agents (2023-2025)
        instagramAppUserAgents.add("Instagram 304.0.0.36.108 iOS (16_4_1; iPhone15,3; sk_SK; sk-SK; scale=3.00; 1290x2796; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 343.0.0.28.116 iOS (17_0; iPhone16,1; sk_SK; sk-SK; scale=3.00; 1179x2556; " + generateInstagramInstallationId() + ")");
        instagramAppUserAgents.add("Instagram 360.0.0.31.109 iOS (17_3; iPhone15,5; sk_SK; sk-SK; scale=3.00; 1290x2796; " + generateInstagramInstallationId() + ")");

        // Add older iPhones (2018-2020)
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 14_4_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1");

// Add newer iPhones (2021-2023)
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 16_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1");

// Add more iPads
        iosUserAgents.add("Mozilla/5.0 (iPad; CPU OS 15_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1");
        iosUserAgents.add("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1");

        // Add additional Android devices - budget (2018-2021)
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 9; Redmi 7A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.104 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 10; Nokia 5.3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 10; moto e(7) plus) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.101 Mobile Safari/537.36");

// Add additional Android devices - mid-range (2018-2021)
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 10; Mi 9T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 10; Redmi Note 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.85 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 11; Redmi Note 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.73 Mobile Safari/537.36");

// Add additional Android devices - flagship (2020-2022)
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.74 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36");

// Add Android tablets
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 12; SM-T733) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36");
        androidUserAgents.add("Mozilla/5.0 (Linux; Android 13; SM-T870) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36");

        // Map by device type
        deviceTypeUserAgents.put(DeviceProfile.TYPE_MOBILE, new ArrayList<>());
        deviceTypeUserAgents.get(DeviceProfile.TYPE_MOBILE).addAll(androidUserAgents.subList(0, 4));
        deviceTypeUserAgents.get(DeviceProfile.TYPE_MOBILE).addAll(iosUserAgents.subList(0, 4));

        deviceTypeUserAgents.put(DeviceProfile.TYPE_TABLET, new ArrayList<>());
        deviceTypeUserAgents.get(DeviceProfile.TYPE_TABLET).add(iosUserAgents.get(4)); // iPad

        deviceTypeUserAgents.put(DeviceProfile.TYPE_DESKTOP, new ArrayList<>());
        deviceTypeUserAgents.get(DeviceProfile.TYPE_DESKTOP).addAll(windowsUserAgents);
        deviceTypeUserAgents.get(DeviceProfile.TYPE_DESKTOP).addAll(macUserAgents);

        // Map by platform
        platformUserAgents.put(DeviceProfile.PLATFORM_ANDROID, androidUserAgents);
        platformUserAgents.put(DeviceProfile.PLATFORM_IOS, iosUserAgents);
        platformUserAgents.put(DeviceProfile.PLATFORM_WINDOWS, windowsUserAgents);
        platformUserAgents.put(DeviceProfile.PLATFORM_MAC, macUserAgents);

        // Initialize device tier maps for each platform
        for (String platform : new String[]{
                DeviceProfile.PLATFORM_ANDROID,
                DeviceProfile.PLATFORM_IOS,
                DeviceProfile.PLATFORM_WINDOWS,
                DeviceProfile.PLATFORM_MAC
        }) {
            deviceTierUserAgents.put(platform, new HashMap<>());
            deviceTierUserAgents.get(platform).put(DeviceProfile.TIER_BUDGET, new ArrayList<>());
            deviceTierUserAgents.get(platform).put(DeviceProfile.TIER_MID_RANGE, new ArrayList<>());
            deviceTierUserAgents.get(platform).put(DeviceProfile.TIER_FLAGSHIP, new ArrayList<>());
        }

        // Add some sample device tier mappings (in a real implementation, this would be more comprehensive)
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_ANDROID).get(DeviceProfile.TIER_FLAGSHIP).add(androidUserAgents.get(0)); // Pixel 7
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_ANDROID).get(DeviceProfile.TIER_FLAGSHIP).add(androidUserAgents.get(1)); // Samsung S22
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_ANDROID).get(DeviceProfile.TIER_MID_RANGE).add(androidUserAgents.get(2)); // OnePlus
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_ANDROID).get(DeviceProfile.TIER_MID_RANGE).add(androidUserAgents.get(3)); // Moto G
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_ANDROID).get(DeviceProfile.TIER_BUDGET).add(androidUserAgents.get(4)); // Xiaomi

        deviceTierUserAgents.get(DeviceProfile.PLATFORM_IOS).get(DeviceProfile.TIER_FLAGSHIP).add(iosUserAgents.get(0)); // iOS 17
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_IOS).get(DeviceProfile.TIER_FLAGSHIP).add(iosUserAgents.get(1)); // iPhone 13
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_IOS).get(DeviceProfile.TIER_MID_RANGE).add(iosUserAgents.get(2)); // iOS 16
        deviceTierUserAgents.get(DeviceProfile.PLATFORM_IOS).get(DeviceProfile.TIER_BUDGET).add(iosUserAgents.get(3)); // iOS 15

        // Slovak-specific demographic distributions
        Map<String, Float> ageDistributionSlovakia = new HashMap<>();
        ageDistributionSlovakia.put("13-17", 0.12f);
        ageDistributionSlovakia.put("18-24", 0.24f);
        ageDistributionSlovakia.put("25-34", 0.31f);
        ageDistributionSlovakia.put("35-44", 0.18f);
        ageDistributionSlovakia.put("45-54", 0.09f);
        ageDistributionSlovakia.put("55-64", 0.04f);
        ageDistributionSlovakia.put("65+", 0.02f);

        Map<String, Float> deviceDistributionSlovakia = new HashMap<>();
        deviceDistributionSlovakia.put(DeviceProfile.TYPE_MOBILE, 0.90f);
        deviceDistributionSlovakia.put(DeviceProfile.TYPE_DESKTOP, 0.05f);
        deviceDistributionSlovakia.put(DeviceProfile.TYPE_TABLET, 0.05f);

        Map<String, Float> platformDistributionSlovakia = new HashMap<>();
        platformDistributionSlovakia.put(DeviceProfile.PLATFORM_ANDROID, 0.72f);
        platformDistributionSlovakia.put(DeviceProfile.PLATFORM_IOS, 0.15f);
        platformDistributionSlovakia.put(DeviceProfile.PLATFORM_WINDOWS, 0.10f);
        platformDistributionSlovakia.put(DeviceProfile.PLATFORM_MAC, 0.03f);

        demographicDistributions.put("age_slovakia", ageDistributionSlovakia);
        demographicDistributions.put("device_slovakia", deviceDistributionSlovakia);
        demographicDistributions.put("platform_slovakia", platformDistributionSlovakia);
    }

    /**
     * Get a random user agent string.
     * @return Random user agent string
     */
    public static String getRandomUserAgent() {
        List<String> allUserAgents = new ArrayList<>();
        allUserAgents.addAll(androidUserAgents);
        allUserAgents.addAll(iosUserAgents);
        allUserAgents.addAll(windowsUserAgents);
        allUserAgents.addAll(macUserAgents);

        return allUserAgents.get(random.nextInt(allUserAgents.size()));
    }

    /**
     * Get a random user agent for a specific device type.
     * @param deviceType Device type (mobile, tablet, desktop)
     * @return Random user agent string
     */
    public static String getRandomUserAgentByDeviceType(String deviceType) {
        List<String> agents = deviceTypeUserAgents.get(deviceType);
        if (agents == null || agents.isEmpty()) {
            return getRandomUserAgent();
        }
        return agents.get(random.nextInt(agents.size()));
    }

    /**
     * Get a random user agent for a specific platform.
     * @param platform Platform (android, ios, windows, mac)
     * @return Random user agent string
     */
    public static String getRandomUserAgentByPlatform(String platform) {
        List<String> agents = platformUserAgents.get(platform);
        if (agents == null || agents.isEmpty()) {
            return getRandomUserAgent();
        }
        return agents.get(random.nextInt(agents.size()));
    }

    /**
     * Get a random user agent for a specific platform and device tier.
     * @param platform Platform (android, ios, windows, mac)
     * @param tier Device tier (budget, mid-range, flagship)
     * @return Random user agent string
     */
    public static String getRandomUserAgentByTier(String platform, String tier) {
        Map<String, List<String>> platformTiers = deviceTierUserAgents.get(platform);
        if (platformTiers == null) {
            return getRandomUserAgentByPlatform(platform);
        }

        List<String> agents = platformTiers.get(tier);
        if (agents == null || agents.isEmpty()) {
            return getRandomUserAgentByPlatform(platform);
        }

        return agents.get(random.nextInt(agents.size()));
    }

    /**
     * Get a random Instagram app user agent.
     * @return Random Instagram app user agent string
     */
    public static String getRandomInstagramAppUserAgent() {
        String originalUserAgent = instagramAppUserAgents.get(random.nextInt(instagramAppUserAgents.size()));

        return originalUserAgent.replaceFirst("(\\d{9})$", generateRealisticInstallationId());
    }

    /**
     * Get a device profile based on Slovak demographic data.
     * @return Device profile with Slovak demographic characteristics
     */
    public static DeviceProfile getSlovakDemographicProfile() {
        // Choose age group based on Slovak demographics
        String ageGroup = chooseBased(demographicDistributions.get("age_slovakia"));

        // Choose device type based on age group and Slovak demographics
        String deviceType = chooseBased(demographicDistributions.get("device_slovakia"));

        // Choose platform based on device type and Slovak demographics
        String platform = chooseBased(demographicDistributions.get("platform_slovakia"));

        // Choose device tier based on age group
        String deviceTier;
        if (ageGroup.equals("13-17") || ageGroup.equals("18-24")) {
            // Younger users more likely to have budget or mid-range devices
            deviceTier = random.nextFloat() < 0.7f ?
                    (random.nextFloat() < 0.6f ? DeviceProfile.TIER_BUDGET : DeviceProfile.TIER_MID_RANGE) :
                    DeviceProfile.TIER_FLAGSHIP;
        } else if (ageGroup.equals("25-34") || ageGroup.equals("35-44")) {
            // Middle-aged users more likely to have mid-range or flagship devices
            deviceTier = random.nextFloat() < 0.8f ?
                    (random.nextFloat() < 0.5f ? DeviceProfile.TIER_MID_RANGE : DeviceProfile.TIER_FLAGSHIP) :
                    DeviceProfile.TIER_BUDGET;
        } else {
            // Older users have more varied device tiers
            deviceTier = random.nextFloat() < 0.4f ? DeviceProfile.TIER_BUDGET :
                    (random.nextFloat() < 0.5f ? DeviceProfile.TIER_MID_RANGE : DeviceProfile.TIER_FLAGSHIP);
        }

        // Get appropriate user agent
        String userAgent;
        boolean isInstagramApp = false;

        if (deviceType.equals(DeviceProfile.TYPE_MOBILE) || deviceType.equals(DeviceProfile.TYPE_TABLET)) {
            // UPDATED: Increased chance to use Instagram app user agent from 70% to 95%
            if (random.nextFloat() < 0.97f) { // 95% chance for mobile to use Instagram app
                userAgent = getRandomInstagramAppUserAgent(); // This now includes dynamic ID
                isInstagramApp = true;
            } else {
                userAgent = getRandomUserAgentByTier(platform, deviceTier);
            }
        } else {
            // Desktop devices always use browser user agents
            userAgent = getRandomUserAgentByTier(platform, deviceTier);
        }

        // Create and return the device profile
        DeviceProfile profile = new DeviceProfile.Builder()
                .deviceType(deviceType)
                .platform(platform)
                .deviceTier(deviceTier)
                .userAgent(userAgent)
                .region("slovakia")
                .isInstagramApp(isInstagramApp)
                .build();

        Logger.d("UserAgentData", "Created profile: " + deviceType + ", " + platform +
                ", Instagram app: " + isInstagramApp);

        return profile;
    }

    /**
     * Choose a random item based on a probability distribution.
     * @param distribution Map of items to their probabilities
     * @param <T> Type of the items
     * @return Randomly chosen item
     */
    private static <T> T chooseBased(Map<T, Float> distribution) {
        float value = random.nextFloat();
        float cumulative = 0.0f;

        for (Map.Entry<T, Float> entry : distribution.entrySet()) {
            cumulative += entry.getValue();
            if (value < cumulative) {
                return entry.getKey();
            }
        }

        // If we somehow get here, return the first item
        return distribution.keySet().iterator().next();
    }

    private static String generateRealisticInstallationId() {
        // Use SecureRandom for better randomness
        long randomBase = Math.abs(secureRandom.nextLong());

        // Ensure 9-digit format with additional entropy from timestamp
        long timestamp = System.currentTimeMillis();
        long combinedId = (randomBase + timestamp) % 1_000_000_000;

        // Format to always be 9 digits
        return String.format("%09d", Math.abs(combinedId));
    }

    private static String replaceInstallationId(String userAgent) {
        return userAgent.replaceFirst("(\\d{9})$", generateRealisticInstallationId());
    }

    static {
        // Modify Android Instagram app user agents
        for (int i = 0; i < instagramAppUserAgents.size(); i++) {
            if (instagramAppUserAgents.get(i).contains("Android")) {
                instagramAppUserAgents.set(i, replaceInstallationId(instagramAppUserAgents.get(i)));
            }
        }

        // Modify iOS Instagram app user agents
        for (int i = 0; i < instagramAppUserAgents.size(); i++) {
            if (instagramAppUserAgents.get(i).contains("iOS")) {
                instagramAppUserAgents.set(i, replaceInstallationId(instagramAppUserAgents.get(i)));
            }
        }
    }

    private static String generateInstagramInstallationId() {
        // Combine multiple sources of entropy for a more realistic ID
        long baseRandom = Math.abs(new Random().nextLong());
        long timestamp = System.currentTimeMillis();

        // Create a deterministic but seemingly random 9-digit number
        long installationId = (baseRandom + timestamp) % 1_000_000_000;

        // Ensure it's always 9 digits
        return String.format("%09d", Math.abs(installationId));
    }
}

