package com.example.imtbf.data.network;

import android.content.Context;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.webkit.CookieManager;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebStorage;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebViewDatabase;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.data.models.SimulationSession;
import com.example.imtbf.utils.Constants;
import com.example.imtbf.utils.Logger;

import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Manages WebView-based requests with Instagram referrer spoofing.
 * This class handles making requests that appear to come from Instagram.
 * Enhanced with crash resistance and recovery mechanisms.
 */
public class WebViewRequestManager {

    private static final String TAG = "WebViewRequestManager";
    private static final int MAX_REDIRECTS = 10;
    private static final int PAGE_LOAD_TIMEOUT_MS = 30000; // 30 seconds
    private static final int MAX_WEBVIEW_INSTANCES = 5; // Maximum number of concurrent WebViews
    private static final int MAX_WEBVIEW_LIFETIME_REQUESTS = 10; // Maximum requests before recycling

    private final Context context;
    private final NetworkStateMonitor networkStateMonitor;
    private WebView webView;
    private final Handler mainHandler;
    private final Random random = new Random();

    // Tracking for WebView instances
    private final AtomicInteger webViewRequestCounter = new AtomicInteger(0);
    private final AtomicInteger webViewCreationCounter = new AtomicInteger(0);
    private final AtomicInteger consecutiveCrashCounter = new AtomicInteger(0);
    private long lastCrashTime = 0;
    private boolean isRecoveryModeActive = false;

    // Add flag to control whether to create a new WebView for each request
    private boolean useNewWebViewPerRequest = false;
    // Store the current instance ID for debugging
    private String currentWebViewId = "";

    private boolean handleMetapicRedirects = true;

    /**
     * Constructor that initializes the WebView request manager.
     * @param context Application context
     * @param networkStateMonitor Network state monitor
     */
    public WebViewRequestManager(Context context, NetworkStateMonitor networkStateMonitor) {
        this.context = context;
        this.networkStateMonitor = networkStateMonitor;
        this.mainHandler = new Handler(Looper.getMainLooper());

        // Ensure WebView debugging is enabled in development
        if (Constants.DEBUG_MODE) {
            WebView.setWebContentsDebuggingEnabled(true);
        }

        // Log initialization for debugging
        String logMessage = "WebViewRequestManager initialized";
        Logger.i(TAG, logMessage);
    }

    /**
     * Set whether to use a new WebView for each request.
     * @param useNewWebViewPerRequest True to create a new WebView for each request, false to reuse
     */
    public void setUseNewWebViewPerRequest(boolean useNewWebViewPerRequest) {
        String logMessage = "New WebView per request mode changed: " +
                (this.useNewWebViewPerRequest ? "Enabled" : "Disabled") + " -> " +
                (useNewWebViewPerRequest ? "Enabled" : "Disabled");

        this.useNewWebViewPerRequest = useNewWebViewPerRequest;

        // Log to app logs
        Logger.i(TAG, logMessage);

        // If we're switching to reuse mode and we have an existing WebView, clean it up
        if (!useNewWebViewPerRequest && webView != null) {
            Logger.i(TAG, "Cleaning up existing WebView for reuse mode");
            cleanupWebViewState();
        } else if (useNewWebViewPerRequest && webView != null) {
            // If switching to new WebView mode, destroy any existing WebView
            Logger.i(TAG, "Destroying existing WebView for per-request mode");
            destroyWebViewCompletely();
        }
    }

    /**
     * Completely destroys the current WebView instance
     */
    private void destroyWebViewCompletely() {
        if (webView != null) {
            mainHandler.post(() -> {
                try {
                    Logger.i(TAG, "Starting complete destruction of WebView ID: " + currentWebViewId);

                    // Remove from parent if attached
                    ViewParent parent = webView.getParent();
                    if (parent instanceof ViewGroup) {
                        ((ViewGroup) parent).removeView(webView);
                        Logger.d(TAG, "WebView removed from parent view");
                    }

                    // Stop any loading and clear all state
                    webView.stopLoading();
                    webView.clearHistory();
                    webView.clearCache(true);
                    webView.clearFormData();
                    webView.clearSslPreferences();
                    webView.clearMatches();

                    // Clear all types of storage
                    CookieManager cookieManager = CookieManager.getInstance();
                    cookieManager.removeAllCookies(null);
                    cookieManager.flush();
                    WebStorage.getInstance().deleteAllData();

                    // Try to clear as much as possible
                    try {
                        WebViewDatabase.getInstance(context).clearHttpAuthUsernamePassword();
                        WebViewDatabase.getInstance(context).clearFormData();
                    } catch (Exception e) {
                        Logger.e(TAG, "Error clearing WebView database: " + e.getMessage());
                    }

                    // Load blank page before destroying
                    webView.loadUrl("about:blank");

                    // Destroy the WebView
                    webView.destroy();
                    webView = null;

                    // Force garbage collection hint
                    System.gc();

                    Logger.i(TAG, "WebView ID: " + currentWebViewId + " completely destroyed");
                    currentWebViewId = "";

                } catch (Exception e) {
                    Logger.e(TAG, "Error destroying WebView: " + e.getMessage());
                }
            });
        }
    }

    /**
     * Check if new WebView per request mode is enabled.
     * @return True if enabled, false otherwise
     */
    public boolean isUseNewWebViewPerRequest() {
        return useNewWebViewPerRequest;
    }

    /**
     * Make a request to the specified URL with Instagram referrer.
     * @param url Target URL
     * @param deviceProfile Device profile for user agent
     * @param session Current simulation session
     * @param callback Callback for request result
     */
    public void makeRequest(
            String url,
            DeviceProfile deviceProfile,
            SimulationSession session,
            RequestCallback callback) {

        if (!networkStateMonitor.isNetworkAvailable()) {
            String errorMessage = "Network not available";
            Logger.e(TAG, errorMessage);
            if (callback != null) {
                callback.onError(errorMessage);
            }
            return;
        }

        // Check if URL is valid
        if (url == null || url.isEmpty() || !(url.startsWith("http://") || url.startsWith("https://"))) {
            String errorMessage = "Invalid URL: " + url;
            Logger.e(TAG, errorMessage);
            if (callback != null) {
                callback.onError(errorMessage);
            }
            return;
        }

        // Verify we're not in crash recovery mode or having too many consecutive crashes
        if (isRecoveryModeActive) {
            String errorMessage = "WebView is in crash recovery mode - delaying request";
            Logger.w(TAG, errorMessage);
            if (callback != null) {
                callback.onError(errorMessage);
            }
            return;
        }

        if (consecutiveCrashCounter.get() >= 3) {
            String errorMessage = "Too many consecutive WebView crashes - temporarily disabling WebView requests";
            Logger.e(TAG, errorMessage);

            // Clear the crash counter after 5 minutes
            mainHandler.postDelayed(() -> {
                Logger.i(TAG, "Resetting WebView crash counter and exiting recovery mode");
                consecutiveCrashCounter.set(0);
                isRecoveryModeActive = false;
            }, 5 * 60 * 1000); // 5 minutes

            if (callback != null) {
                callback.onError(errorMessage);
            }
            return;
        }

        String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();
        Logger.i(TAG, "Making WebView request to " + url + " with IP " + currentIp);
        Logger.i(TAG, "Using " + (deviceProfile.isInstagramApp() ? "Instagram app" : "browser") +
                " profile on " + deviceProfile.getPlatform() +
                " device type: " + deviceProfile.getDeviceType() +
                ", New WebView per request: " + useNewWebViewPerRequest);

        final long startTime = System.currentTimeMillis();
        final AtomicBoolean requestComplete = new AtomicBoolean(false);
        final CountDownLatch requestLatch = new CountDownLatch(1);

        // Track WebView instance lifetime
        int currentRequestCount = webViewRequestCounter.incrementAndGet();

        // Determine if we need a new WebView based on:
        // - useNewWebViewPerRequest setting
        // - exceeding MAX_WEBVIEW_LIFETIME_REQUESTS
        // - current WebView is null
        boolean shouldCreateNewWebView = useNewWebViewPerRequest ||
                webView == null ||
                currentRequestCount > MAX_WEBVIEW_LIFETIME_REQUESTS;

        // WebView must be created and used on the main thread
        mainHandler.post(() -> {
            try {
                // Create or reuse WebView
                if (shouldCreateNewWebView) {
                    // If we've exceeded our request limit, destroy the old WebView
                    if (webView != null && currentRequestCount > MAX_WEBVIEW_LIFETIME_REQUESTS) {
                        Logger.i(TAG, "WebView has processed " + currentRequestCount +
                                " requests, recycling for memory management");
                        destroyWebViewCompletely();
                        webViewRequestCounter.set(0);
                    }

                    // Create fresh WebView instance
                    createFreshWebView();
                } else {
                    // Reuse existing WebView but clear state
                    Logger.i(TAG, "Reusing existing WebView ID: " + currentWebViewId + " with state clearing");
                    cleanupWebViewState();
                }

                // Configure WebView with specialized settings for uniqueness
                configureWebView(webView, deviceProfile);

                // Set up WebView client with crash handling capabilities
                webView.setWebViewClient(new CrashResistantWebViewClient(
                        url,
                        currentIp,
                        session,
                        callback,
                        requestComplete,
                        requestLatch,
                        webView,
                        currentWebViewId));

                // Set up WebChromeClient for better crash handling and monitoring
                webView.setWebChromeClient(new CrashResistantWebChromeClient());

                // Add Instagram headers and other realistic headers
                Map<String, String> headers = getRealisticHeaders(deviceProfile, useNewWebViewPerRequest);
                StringBuilder headerDebug = new StringBuilder("Request headers:\n");
                for (Map.Entry<String, String> header : headers.entrySet()) {
                    headerDebug.append(header.getKey()).append(": ").append(header.getValue()).append("\n");
                }
                Logger.d(TAG, headerDebug.toString());

                // Load the URL with headers
                Logger.i(TAG, "Loading URL in WebView ID: " + currentWebViewId);
                webView.loadUrl(url, headers);

                // Set a timeout for the request
                mainHandler.postDelayed(() -> {
                    if (!requestComplete.getAndSet(true)) {
                        String timeoutMsg = "WebView request timed out after " + PAGE_LOAD_TIMEOUT_MS + "ms";
                        Logger.w(TAG, timeoutMsg);

                        if (session != null) {
                            session.addRequestResult(
                                    new SimulationSession.RequestResult(
                                            timeoutMsg, currentIp));
                        }

                        if (callback != null) {
                            callback.onError(timeoutMsg);
                        }

                        // Clean up and release latch
                        if (useNewWebViewPerRequest) {
                            Logger.i(TAG, "Destroying WebView ID: " + currentWebViewId + " after timeout");
                            destroyWebViewCompletely();
                        } else {
                            cleanupWebView();
                        }
                        requestLatch.countDown();
                    }
                }, PAGE_LOAD_TIMEOUT_MS);

            } catch (Exception e) {
                String exceptionMsg = "Error creating WebView: " + e.getMessage();
                Logger.e(TAG, exceptionMsg, e);

                if (!requestComplete.getAndSet(true)) {
                    if (session != null) {
                        session.addRequestResult(
                                new SimulationSession.RequestResult(
                                        exceptionMsg, currentIp));
                    }

                    if (callback != null) {
                        callback.onError(exceptionMsg);
                    }

                    requestLatch.countDown();
                }
            }
        });

        // Wait for the request to complete with a timeout
        try {
            requestLatch.await(PAGE_LOAD_TIMEOUT_MS + 5000, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Logger.w(TAG, "WebView request interrupted: " + e.getMessage());
            Thread.currentThread().interrupt();
        }
    }

    /**
     * Creates a fresh WebView instance with proper configuration
     */
    private void createFreshWebView() {
        // Clean up existing WebView if there is one
        if (webView != null) {
            Logger.i(TAG, "Destroying existing WebView before creating a new one");
            destroyWebViewCompletely();
            webView = null;
        }

        // Create a new WebView
        int instanceNum = webViewCreationCounter.incrementAndGet();
        currentWebViewId = "WebView-" + UUID.randomUUID().toString().substring(0, 8);
        Logger.i(TAG, "Creating new WebView #" + instanceNum + ", ID: " + currentWebViewId);

        try {
            // Create WebView with proper layout params
            webView = new WebView(context);
            webView.setLayoutParams(new LinearLayout.LayoutParams(1, 1)); // 1x1 pixel size (invisible)
            webView.setTag(currentWebViewId); // Tag the WebView for tracking

            // Set up default configurations
            WebSettings settings = webView.getSettings();
            settings.setJavaScriptEnabled(true);
            settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
            settings.setDomStorageEnabled(false); // Disable storage for privacy
            settings.setDatabaseEnabled(false);   // Disable database for privacy
            settings.setGeolocationEnabled(false); // Disable geolocation for privacy
            settings.setSaveFormData(false);
            settings.setSavePassword(false);

            // Disable unsafe features that can cause crashes
            settings.setAllowFileAccess(false);
            settings.setAllowContentAccess(false);
            settings.setAllowFileAccessFromFileURLs(false);
            settings.setAllowUniversalAccessFromFileURLs(false);

            // Performance settings to reduce crash risk
            settings.setBlockNetworkImage(false); // Ensure images load
            settings.setLoadsImagesAutomatically(true);

            // Memory management settings
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                webView.setRendererPriorityPolicy(WebView.RENDERER_PRIORITY_BOUND, true);
            }

            // Reset counters
            consecutiveCrashCounter.set(0);
            lastCrashTime = 0;
            isRecoveryModeActive = false;
        } catch (Exception e) {
            Logger.e(TAG, "Error creating WebView instance: " + e.getMessage(), e);
            webView = null;
            consecutiveCrashCounter.incrementAndGet();
            isRecoveryModeActive = true;
        }
    }

    /**
     * Configures a WebView with device-specific settings
     */
    private void configureWebView(WebView webView, DeviceProfile deviceProfile) {
        if (webView == null) return;

        try {
            WebSettings webSettings = webView.getSettings();

            // Base configuration
            webSettings.setJavaScriptEnabled(true);
            webSettings.setCacheMode(WebSettings.LOAD_NO_CACHE);
            webSettings.setDomStorageEnabled(true);
            webSettings.setLoadsImagesAutomatically(true);
            webSettings.setJavaScriptCanOpenWindowsAutomatically(false);
            webSettings.setSupportMultipleWindows(false);

            // Set user agent
            String userAgent = deviceProfile.getUserAgent();
            webSettings.setUserAgentString(userAgent);

            // Add unique identifier if needed
            if (useNewWebViewPerRequest) {
                String uniqueId = UUID.randomUUID().toString().substring(0, 8);
                String uniqueUserAgent = userAgent + " Visitor/" + uniqueId;
                webSettings.setUserAgentString(uniqueUserAgent);
                Logger.i(TAG, "Set unique User-Agent: [" + uniqueUserAgent + "]");
            }

            // Set up cookie handling
            CookieManager cookieManager = CookieManager.getInstance();
            cookieManager.setAcceptCookie(true);
            cookieManager.setAcceptThirdPartyCookies(webView, true);

            // For per-request mode, make sure cookies are reset
            if (useNewWebViewPerRequest) {
                cookieManager.removeAllCookies(null);
                cookieManager.flush();
                Logger.d(TAG, "Cookies cleared for new WebView instance");
            }

            // Add Instagram-specific properties
            if (deviceProfile.isInstagramApp()) {
                prepareWebViewForInstagram(webView, deviceProfile);
            }
        } catch (Exception e) {
            Logger.e(TAG, "Error configuring WebView: " + e.getMessage(), e);
        }
    }

    /**
     * In WebViewRequestManager where you configure WebView before loading
     */
    private void prepareWebViewForInstagram(WebView webView, DeviceProfile deviceProfile) {
        if (deviceProfile.isInstagramApp()) {
            CookieManager cookieManager = CookieManager.getInstance();
            cookieManager.setAcceptCookie(true);
            cookieManager.setAcceptThirdPartyCookies(webView, true);

            // Add Instagram-specific cookies
            String deviceId = generateRandomInstagramDeviceId();
            cookieManager.setCookie("instagram.com", "ig_did=" + deviceId);
            cookieManager.setCookie("instagram.com", "mid=" + generateRandomMid());
            cookieManager.setCookie("instagram.com", "ig_nrcb=1");
            cookieManager.setCookie("instagram.com", "ds_user_id=" + generateRandomUserId());

            cookieManager.flush();
        }
    }

    private String generateRandomInstagramDeviceId() {
        return UUID.randomUUID().toString();
    }

    private String generateRandomMid() {
        return "Y" +
                base64UrlEncode(generateRandomBytes(8)) +
                base64UrlEncode(generateRandomBytes(8));
    }

    private String generateRandomUserId() {
        return String.valueOf(1000000000 + random.nextInt(900000000));
    }

    private byte[] generateRandomBytes(int length) {
        byte[] bytes = new byte[length];
        random.nextBytes(bytes);
        return bytes;
    }

    private String base64UrlEncode(byte[] data) {
        String base64 = android.util.Base64.encodeToString(data, android.util.Base64.NO_WRAP);
        return base64.replace('+', '-').replace('/', '_');
    }


    /**
     * Get realistic browser headers for WebView request, with option to add unique visitor info
     */
    private Map<String, String> getRealisticHeaders(DeviceProfile deviceProfile, boolean addUniqueVisitor) {
        Map<String, String> headers = new HashMap<>();

        // Instagram referrer
        headers.put("Referer", Constants.INSTAGRAM_REFERER);

        // User Agent (may be modified for uniqueness)
        String userAgent = deviceProfile.getUserAgent();
        if (addUniqueVisitor) {
            // Add a unique visitor ID to appear as a different visitor
            String uniqueId = UUID.randomUUID().toString().substring(0, 8);
            userAgent = userAgent + " UniqueVisitor/" + uniqueId;
            Logger.d(TAG, "Added unique visitor ID to User-Agent: " + uniqueId);
        }
        headers.put("User-Agent", userAgent);

        // Check if this is an Instagram app profile
        if (deviceProfile.isInstagramApp()) {
            // Instagram app-specific headers
            headers.put("X-IG-App-ID", "936619743392459");
            headers.put("X-Instagram-AJAX", "1");

            // Add Accept language for Slovakia
            headers.put("Accept-Language", "sk-SK, sk;q=0.9, en-US;q=0.8, en;q=0.7");

            // Add random connection type with bias toward mobile connections
            String connectionType;
            float connChoice = random.nextFloat();
            if (connChoice < 0.40f) { // 40% WiFi (previously 55%)
                connectionType = "WIFI";
            } else if (connChoice < 0.70f) { // 30% 4G/LTE (previously 25%)
                connectionType = random.nextBoolean() ? "MOBILE(LTE)" : "MOBILE(4G)";
            } else if (connChoice < 0.95f) { // 25% 5G (previously 15%)
                connectionType = "MOBILE(5G)";
            } else { // 5% 3G (unchanged)
                connectionType = "MOBILE(3G)";
            }

            // Add platform-specific headers
            if (deviceProfile.getPlatform().equals(DeviceProfile.PLATFORM_ANDROID)) {
                // Android-specific Instagram headers
                String androidId = generateRandomAndroidId();
                headers.put("X-IG-Android-ID", androidId);
                headers.put("X-IG-Connection-Type", connectionType);
                headers.put("X-IG-Capabilities", "3brTvw==");
                headers.put("X-IG-App-Locale", "sk_SK");
                headers.put("X-IG-Device-Locale", "sk_SK");
                headers.put("X-IG-Mapped-Locale", "sk_SK");
                headers.put("X-IG-Bandwidth-Speed-KBPS", String.valueOf(1000 + random.nextInt(9000)));
                headers.put("X-IG-Bandwidth-TotalBytes-B", String.valueOf(1000000 + random.nextInt(9000000)));
                headers.put("X-IG-Bandwidth-TotalTime-MS", String.valueOf(100 + random.nextInt(900)));

                // Instagram app on Android uses a different referrer
                headers.put("Referer", "https://www.instagram.com/android-app/");
            } else if (deviceProfile.getPlatform().equals(DeviceProfile.PLATFORM_IOS)) {
                // iOS-specific Instagram headers
                headers.put("X-IG-iOS-Version", "17.0");
                headers.put("X-IG-Connection-Type", connectionType);
                headers.put("X-IG-Capabilities", "36r/F/8=");
                headers.put("X-IG-App-Locale", "sk_SK");
                headers.put("X-IG-Device-Locale", "sk_SK");
                headers.put("X-IG-Mapped-Locale", "sk_SK");

                // Instagram app on iOS uses a different referrer
                headers.put("Referer", "https://www.instagram.com/ios-app/");
            }
        } else {
            // Browser headers - use these for non-Instagram app traffic
            headers.put("Origin", Constants.INSTAGRAM_REFERER);
            headers.put("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
            headers.put("Accept-Language", "sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7");
            headers.put("DNT", "1");

            // Additional browser-specific headers
            if (deviceProfile.isMobile()) {
                // Mobile browser
                headers.put("Sec-Fetch-Mode", "navigate");
                headers.put("Sec-Fetch-Site", "same-origin");
                headers.put("Sec-Fetch-User", "?1");
            } else {
                // Desktop browser
                headers.put("Sec-Fetch-Dest", "document");
                headers.put("Sec-Fetch-Mode", "navigate");
                headers.put("Sec-Fetch-Site", "same-origin");
                headers.put("Sec-Fetch-User", "?1");
                headers.put("TE", "trailers");
            }
        }

        // Add cache control headers for better uniqueness
        if (addUniqueVisitor) {
            headers.put("Cache-Control", "no-cache, no-store, must-revalidate");
            headers.put("Pragma", "no-cache");
            headers.put("Expires", "0");
        }

        return headers;
    }

    private String generateRandomAndroidId() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 16; i++) {
            sb.append(Integer.toHexString(random.nextInt(16)));
        }
        return sb.toString();
    }

    /**
     * Cleans up WebView state without destroying the WebView.
     * This is used when reusing a WebView instance.
     */
    private void cleanupWebViewState() {
        if (webView != null) {
            mainHandler.post(() -> {
                try {
                    Logger.i(TAG, "Clearing WebView state for ID: " + currentWebViewId);

                    webView.stopLoading();
                    webView.loadUrl("about:blank");
                    webView.clearHistory();
                    webView.clearCache(true);
                    webView.clearFormData();
                    webView.clearSslPreferences();

                    // Clear cookies
                    CookieManager cookieManager = CookieManager.getInstance();
                    cookieManager.removeAllCookies(null);
                    cookieManager.flush();

                    // Clear storage
                    WebStorage.getInstance().deleteAllData();

                    // Clear navigation history
                    webView.clearHistory();

                    // Try to clear form data and passwords
                    try {
                        WebViewDatabase.getInstance(context).clearHttpAuthUsernamePassword();
                        WebViewDatabase.getInstance(context).clearFormData();
                    } catch (Exception e) {
                        // Just log and continue
                        Logger.w(TAG, "Error clearing WebView database: " + e.getMessage());
                    }

                    Logger.i(TAG, "WebView state cleared successfully for ID: " + currentWebViewId);
                } catch (Exception e) {
                    Logger.e(TAG, "Error during WebView state cleanup: " + e.getMessage());
                }
            });
        }
    }

    /**
     * WebChromeClient with crash handling for WebView
     */
    private class CrashResistantWebChromeClient extends WebChromeClient {
        @Override
        public void onProgressChanged(WebView view, int newProgress) {
            super.onProgressChanged(view, newProgress);

            // Log progress for debugging
            if (newProgress % 25 == 0) {
                Logger.d(TAG, "WebView ID: " + currentWebViewId + " - Load progress: " + newProgress + "%");
            }
        }

        // Add any additional WebChromeClient methods here as needed
    }

    /**
     * A robust WebViewClient that handles redirects and page loading events
     * with enhanced crash resistance.
     */
    private class CrashResistantWebViewClient extends WebViewClient {
        private int redirectCount = 0;
        private long startTime = 0;
        private final String initialUrl;
        private final String currentIp;
        private final SimulationSession session;
        private final RequestCallback callback;
        private final AtomicBoolean requestComplete;
        private final CountDownLatch requestLatch;
        private final WebView webView;
        private final String webViewId;

        private int sameUrlCount = 0;
        private String lastRedirectUrl = "";
        private static final int MAX_SAME_URL_REDIRECTS = 2;

        public CrashResistantWebViewClient(
                String url,
                String currentIp,
                SimulationSession session,
                RequestCallback callback,
                AtomicBoolean requestComplete,
                CountDownLatch requestLatch,
                WebView webView,
                String webViewId) {
            this.initialUrl = url;
            this.currentIp = currentIp;
            this.session = session;
            this.callback = callback;
            this.requestComplete = requestComplete;
            this.requestLatch = requestLatch;
            this.webView = webView;
            this.webViewId = webViewId;
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            try {
                super.onPageStarted(view, url, favicon);
                startTime = System.currentTimeMillis();

                if (!url.equals(initialUrl)) {
                    redirectCount++;
                    Logger.i(TAG, "-----------********** WebView ID: " + webViewId + " - Redirect #" + redirectCount + ": " + initialUrl + " -> " + url + "**********-------------");
                }

                Logger.i(TAG, "WebView ID: " + webViewId + " - Page load started: " + url);
            } catch (Exception e) {
                Logger.e(TAG, "Error in onPageStarted: " + e.getMessage(), e);
                // Continue processing to avoid crashes
            }
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            try {
                super.onPageFinished(view, url);
                long loadTime = System.currentTimeMillis() - startTime;
                Logger.i(TAG, "WebView ID: " + webViewId + " - Page load finished: " + url + " in " + loadTime + "ms");
                Logger.i(TAG, "WebView ID: " + webViewId + " - Total redirects: " + redirectCount);

                // Give a short delay to ensure JavaScript has run
                mainHandler.postDelayed(() -> {
                    if (!requestComplete.getAndSet(true)) {
                        // Now simulate behavior before completing
                        Logger.i(TAG, "WebView ID: " + webViewId + " - Starting user behavior simulation");

                        simulateUserBehavior(webView, () -> {
                            if (session != null) {
                                session.addRequestResult(
                                        new SimulationSession.RequestResult(
                                                200, loadTime, currentIp));
                            }

                            if (callback != null) {
                                callback.onSuccess(200, loadTime);
                            }

                            // Now clean up and release latch
                            Logger.i(TAG, "WebView ID: " + webViewId + " - Request completed successfully, cleaning up");

                            if (useNewWebViewPerRequest) {
                                destroyWebViewCompletely();
                            } else {
                                cleanupWebView();
                            }
                            requestLatch.countDown();
                        });
                    }
                }, 500);
            } catch (Exception e) {
                Logger.e(TAG, "Error in onPageFinished: " + e.getMessage(), e);
                handleError("Error completing page load: " + e.getMessage());
            }
        }

        @Override
        public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
            try {
                String errorMsg = "WebView ID: " + webViewId + " - Error: " + description;
                Logger.e(TAG, errorMsg);

                // Try to handle the URL if it's a special scheme
                if (description.contains("ERR_UNKNOWN_URL_SCHEME") && handleMetapicRedirects) {
                    String processedUrl = processSpecialUrlSchemes(failingUrl);
                    if (processedUrl != null && !processedUrl.equals(failingUrl)) {
                        Logger.i(TAG, "Recovered from URL scheme error by converting: " + failingUrl + " -> " + processedUrl);
                        view.loadUrl(processedUrl);
                        return;
                    }
                }

                handleError(errorMsg);
            } catch (Exception e) {
                Logger.e(TAG, "Error in onReceivedError: " + e.getMessage(), e);
                handleError("Error handler exception: " + e.getMessage());
            }
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            try {
                if (request.isForMainFrame()) {
                    String errorMsg = "WebView ID: " + webViewId + " - Error: " + error.getDescription();
                    Logger.e(TAG, errorMsg);

                    // Try to handle the URL if it's a special scheme
                    if (error.getDescription().toString().contains("ERR_UNKNOWN_URL_SCHEME") && handleMetapicRedirects) {
                        String failingUrl = request.getUrl().toString();
                        String processedUrl = processSpecialUrlSchemes(failingUrl);
                        if (processedUrl != null && !processedUrl.equals(failingUrl)) {
                            Logger.i(TAG, "Recovered from URL scheme error by converting: " + failingUrl + " -> " + processedUrl);
                            view.loadUrl(processedUrl);
                            return;
                        }
                    }

                    handleError(errorMsg);
                }
            } catch (Exception e) {
                Logger.e(TAG, "Error in onReceivedError: " + e.getMessage(), e);
                handleError("Error handler exception: " + e.getMessage());
            }
        }

        /**
         * Called when the rendering process crashes
         * This is critical for handling WebView crashes properly
         */
        @Override
        public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
            // Record crash
            consecutiveCrashCounter.incrementAndGet();
            lastCrashTime = System.currentTimeMillis();

            String errorMsg = "WebView render process crashed - " +
                    (detail.didCrash() ? "Fatal crash" : "System killed") +
                    " (crash count: " + consecutiveCrashCounter.get() + ")";

            Logger.e(TAG, errorMsg);

            // Enter recovery mode if needed
            if (consecutiveCrashCounter.get() >= 2) {
                isRecoveryModeActive = true;

                // Schedule recovery mode reset after delay
                mainHandler.postDelayed(() -> {
                    isRecoveryModeActive = false;
                    Logger.i(TAG, "Exited WebView recovery mode");
                }, 2 * 60 * 1000); // 2 minute recovery
            }

            // Clean up the crashed WebView
            destroyWebViewCompletely();

            // Report the error
            handleError(errorMsg);

            // Return true to indicate we handled the crash
            return true;
        }

        /**
         * Handle HTTP errors
         */
        @Override
        public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse errorResponse) {
            try {
                if (request.isForMainFrame()) {
                    int statusCode = errorResponse.getStatusCode();

                    // Only log 4xx and 5xx errors
                    if (statusCode >= 400) {
                        String errorMsg = "WebView ID: " + webViewId + " - HTTP Error " +
                                statusCode + " for URL: " + request.getUrl();
                        Logger.e(TAG, errorMsg);

                        // Only treat 5xx errors as failures
                        if (statusCode >= 500) {
                            handleError(errorMsg);
                        }
                    }
                }

                super.onReceivedHttpError(view, request, errorResponse);
            } catch (Exception e) {
                Logger.e(TAG, "Error in onReceivedHttpError: " + e.getMessage(), e);
            }
        }

        private void handleError(String errorMsg) {
            if (!requestComplete.getAndSet(true)) {
                if (session != null) {
                    session.addRequestResult(
                            new SimulationSession.RequestResult(
                                    errorMsg, currentIp));
                }

                if (callback != null) {
                    callback.onError(errorMsg);
                }

                // Clean up and release latch
                Logger.i(TAG, "WebView ID: " + webViewId + " - Request failed, cleaning up");

                if (useNewWebViewPerRequest) {
                    destroyWebViewCompletely();
                } else {
                    cleanupWebView();
                }
                requestLatch.countDown();
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            try {
                Logger.d(TAG, "WebView ID: " + webViewId + " - shouldOverrideUrlLoading: " + url);

                // Check for redirect loops - if we're seeing the same URL multiple times
                if (url.equals(lastRedirectUrl)) {
                    sameUrlCount++;
                    if (sameUrlCount >= MAX_SAME_URL_REDIRECTS) {
                        Logger.w(TAG, "WebView ID: " + webViewId + " - Detected redirect loop with URL: " + url);

                        // Force extraction of final URL
                        try {
                            Uri uri = Uri.parse(url);
                            String targetParam = uri.getQueryParameter("u");
                            if (targetParam != null && !targetParam.isEmpty()) {
                                String finalUrl = Uri.decode(targetParam);
                                Logger.i(TAG, "Force-redirecting to extracted target: " + finalUrl);
                                view.loadUrl(finalUrl);
                                lastRedirectUrl = url;
                                return true;
                            }
                        } catch (Exception e) {
                            Logger.e(TAG, "Error during force-bypass: " + e.getMessage());
                        }
                    }
                } else {
                    lastRedirectUrl = url;
                    sameUrlCount = 0;
                }

                // Process special URLs like intent:// schemes
                String processedUrl = processSpecialUrlSchemes(url);

                if (processedUrl == null) {
                    // Returning true means we handled the URL (by ignoring it)
                    Logger.i(TAG, "Skipping URL: " + url);
                    return true;
                }

                if (!processedUrl.equals(url)) {
                    // URL was converted, load the new URL
                    Logger.i(TAG, "Converted URL: " + url + " -> " + processedUrl);
                    view.loadUrl(processedUrl);
                    return true;
                }

                // For normal web URLs, let WebView handle it
                return false;
            } catch (Exception e) {
                Logger.e(TAG, "Error in shouldOverrideUrlLoading: " + e.getMessage(), e);
                return true; // Return true to indicate we handled it
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            String url = request.getUrl().toString();
            return shouldOverrideUrlLoading(view, url);
        }
    }

    /**
     * Simulate user behavior on loaded page
     */
    private void simulateUserBehavior(WebView webView, Runnable onComplete) {
        try {
            // Randomly determine how long to stay on page (5-10 seconds)
            int stayTimeMs = 5000 + random.nextInt(5000);
            Logger.i(TAG, "-----------********** WebView ID: " + currentWebViewId + " - Simulating user behavior for " + stayTimeMs + "ms");

            // Schedule some scroll events
            scheduleScrollEvents(webView, stayTimeMs);

            // Complete after the stay time
            mainHandler.postDelayed(onComplete, stayTimeMs);
        } catch (Exception e) {
            Logger.e(TAG, "Error in simulateUserBehavior: " + e.getMessage(), e);
            // Still complete even if simulation fails
            onComplete.run();
        }
    }

    /**
     * Schedule random scroll events
     */
    private void scheduleScrollEvents(WebView webView, int totalTimeMs) {
        try {
            int scrollCount = 2 + random.nextInt(4); // 2-5 scrolls
            Logger.d(TAG, "WebView ID: " + currentWebViewId + " - Scheduling " + scrollCount + " scroll events");

            for (int i = 1; i <= scrollCount; i++) {
                int delay = (totalTimeMs * i) / (scrollCount + 1); // Distribute throughout the time
                int scrollAmount = 100 + random.nextInt(300); // 100-400px

                final int finalScrollAmount = scrollAmount;
                final int eventNumber = i;
                mainHandler.postDelayed(() -> {
                    try {
                        String js = "window.scrollBy(0, " + finalScrollAmount + ");";
                        webView.evaluateJavascript(js, null);
                        Logger.d(TAG, "WebView ID: " + currentWebViewId + " - Scroll event #" + eventNumber + ": " + finalScrollAmount + "px");
                    } catch (Exception e) {
                        Logger.e(TAG, "Error in scroll event: " + e.getMessage());
                    }
                }, delay);
            }
        } catch (Exception e) {
            Logger.e(TAG, "Error scheduling scroll events: " + e.getMessage(), e);
        }
    }

    /**
     * Clean up the WebView to prevent memory leaks.
     */
    private void cleanupWebView() {
        mainHandler.post(() -> {
            if (webView != null) {
                try {
                    Logger.i(TAG, "Cleaning up WebView ID: " + currentWebViewId);

                    webView.stopLoading();
                    webView.loadUrl("about:blank");
                    webView.clearHistory();
                    webView.clearCache(true);
                    webView.clearFormData();

                    // If using new WebView per request, fully destroy the WebView
                    if (useNewWebViewPerRequest) {
                        // Remove from parent view if attached
                        ViewParent parent = webView.getParent();
                        if (parent instanceof ViewGroup) {
                            ((ViewGroup) parent).removeView(webView);
                            Logger.d(TAG, "WebView removed from parent view");
                        }

                        webView.destroy();
                        webView = null;
                        System.gc(); // Hint to garbage collector

                        Logger.i(TAG, "-----------********** WebView ID: " + currentWebViewId + " completely destroyed **************-----------");
                        currentWebViewId = "";
                    }
                } catch (Exception e) {
                    Logger.e(TAG, "Error during WebView cleanup: " + e.getMessage());
                }
            }
        });
    }

    /**
     * Set whether to handle Metapic and similar marketing redirect URLs.
     * @param enable True to handle redirects, false to use default WebView behavior
     */
    public void setHandleMetapicRedirects(boolean enable) {
        this.handleMetapicRedirects = enable;
        Logger.i(TAG, "Metapic redirect handling: " + (enable ? "Enabled" : "Disabled"));
    }

    /**
     * Check if Metapic redirect handling is enabled.
     * @return True if enabled, false otherwise
     */
    public boolean isHandleMetapicRedirectsEnabled() {
        return handleMetapicRedirects;
    }

    /**
     * Process intent or other special URL schemes.
     * Handles redirect URLs that would normally cause errors in WebView.
     * @param url The URL to process
     * @return A web-loadable URL or null if it can't be processed
     */
    private String processSpecialUrlSchemes(String url) {
        if (url == null || url.isEmpty()) {
            return null;
        }

        if (!handleMetapicRedirects) {
            // If redirect handling is disabled, return the URL as-is
            return url;
        }

        try {
            // Handle Instagram linkshim redirects
            if (url.contains("l.instagram.com") ||
                    (url.contains("instagram.com") && url.contains("/linkshim"))) {

                Logger.i(TAG, "Processing Instagram redirect URL: " + url);

                try {
                    Uri uri = Uri.parse(url);
                    String uParam = uri.getQueryParameter("u");

                    if (uParam != null && !uParam.isEmpty()) {
                        // The 'u' parameter contains the encoded target URL
                        String targetUrl = Uri.decode(uParam);
                        Logger.i(TAG, "Extracted Instagram redirect target: " + targetUrl);
                        return targetUrl;
                    }
                } catch (Exception e) {
                    Logger.e(TAG, "Error parsing Instagram redirect URL: " + e.getMessage());
                }
            }

            // Handle intent:// URLs (commonly used by marketing trackers like Metapic)
            if (url.startsWith("intent://")) {
                Logger.i(TAG, "Processing intent URL: " + url);

                // Extract the target URL from the intent
                // Format: intent://host/path?params#Intent;scheme=https;...;end
                String target = null;

                // Find the scheme specification
                int schemeStart = url.indexOf("scheme=");
                if (schemeStart > 0) {
                    schemeStart += 7; // Length of "scheme="
                    int schemeEnd = url.indexOf(";", schemeStart);
                    if (schemeEnd > 0) {
                        String scheme = url.substring(schemeStart, schemeEnd);

                        // Extract the host and path
                        String hostAndPath = url.substring(8, url.indexOf("#"));

                        // Combine into a proper URL
                        target = scheme + "://" + hostAndPath;

                        Logger.i(TAG, "Converted intent URL to: " + target);
                        return target;
                    }
                }

                // Fallback: If we can't parse the intent URL correctly, try to extract URL parameters
                // Many marketing URLs include the actual target as a parameter
                if (target == null && url.contains("url=")) {
                    int urlParamIndex = url.indexOf("url=");
                    int urlEnd = url.indexOf("&", urlParamIndex);
                    if (urlEnd < 0) {
                        urlEnd = url.indexOf(";", urlParamIndex);
                    }
                    if (urlEnd < 0) {
                        urlEnd = url.indexOf("#", urlParamIndex);
                    }

                    if (urlEnd > 0) {
                        target = url.substring(urlParamIndex + 4, urlEnd);
                        // URL might be encoded
                        target = Uri.decode(target);

                        Logger.i(TAG, "Extracted target URL from parameter: " + target);
                        return target;
                    }
                }

                // If all extraction attempts fail, just convert to https
                if (target == null) {
                    // Strip the intent:// prefix and everything after the #Intent part
                    String domain = url.substring(9, url.indexOf("#"));
                    target = "https://" + domain;
                    Logger.i(TAG, "Using fallback conversion: " + target);
                    return target;
                }
            }

            // Handle metapic-specific redirects where they might be multiple nested redirects
            if (url.contains("mtpc.se") || url.contains("metapic")) {
                Logger.i(TAG, "Detected potential Metapic link: " + url);

                try {
                    Uri uri = Uri.parse(url);
                    // Check for common redirect parameters
                    String[] redirectParams = {"target", "url", "u", "goto", "dest", "redirect"};

                    for (String param : redirectParams) {
                        String targetUrl = uri.getQueryParameter(param);
                        if (targetUrl != null && !targetUrl.isEmpty()) {
                            targetUrl = Uri.decode(targetUrl);
                            Logger.i(TAG, "Extracted Metapic redirect target from " + param + ": " + targetUrl);
                            return targetUrl;
                        }
                    }
                } catch (Exception e) {
                    Logger.e(TAG, "Error parsing Metapic URL: " + e.getMessage());
                }
            }

            // Handle other non-web schemes
            if (url.startsWith("market://") ||
                    url.startsWith("instagram://") ||
                    url.startsWith("fb://")) {

                Logger.i(TAG, "Found non-web URL scheme: " + url.substring(0, url.indexOf("://")+3));

                // For market:// links, try to convert to web Play Store links
                if (url.startsWith("market://")) {
                    String packagePath = url.substring(9); // Remove "market://"
                    return "https://play.google.com/store/apps/" + packagePath;
                }

                // For other app links, we'll skip by returning null
                // This signals to the WebViewClient that we should ignore this navigation
                Logger.i(TAG, "Skipping app-specific URL scheme");
                return null;
            }
        } catch (Exception e) {
            Logger.e(TAG, "Error processing special URL: " + e.getMessage());
        }

        // If we get here, the URL is either already a web URL or couldn't be processed
        return url;
    }

    private void simulateInstagramAppBehavior(WebView webView) {
        String js =
                "if (typeof window.__igEnabled === 'undefined') {" +
                        "  window.__igEnabled = true;" +
                        "  window.__igExploreMode = 'discover';" +
                        "  window.__igNativeAssetLoader = true;" +
                        "  window.navigator.connection = {" +
                        "    effectiveType: '" + (random.nextBoolean() ? "4g" : "5g") + "'," +
                        "    rtt: " + (10 + random.nextInt(90)) + "," +
                        "    downlink: " + (5 + random.nextInt(45)) + "," +
                        "    saveData: false" +
                        "  };" +
                        "}";

        webView.evaluateJavascript(js, null);
    }

    /**
     * Callback interface for WebView requests.
     */
    public interface RequestCallback {
        void onSuccess(int statusCode, long responseTimeMs);
        void onError(String error);
    }
}