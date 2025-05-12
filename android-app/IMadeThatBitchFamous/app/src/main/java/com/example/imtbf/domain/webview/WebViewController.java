package com.example.imtbf.domain.webview;

import android.content.Context;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.utils.Logger;

import java.util.UUID;

/**
 * Controls WebView configuration and provides central access to WebView functionality.
 */
public class WebViewController {
    private static final String TAG = "WebViewController";
    private final Context context;

    public WebViewController(Context context) {
        this.context = context;
    }

    /**
     * Configure a WebView based on a device profile with incognito settings.
     * @param webView WebView to configure
     * @param deviceProfile Device profile to use for configuration
     */
    public void configureWebView(WebView webView, DeviceProfile deviceProfile) {
        if (webView == null) {
            Logger.e(TAG, "Cannot configure null WebView");
            return;
        }

        WebSettings settings = webView.getSettings();

        // Incognito-focused settings
        settings.setJavaScriptEnabled(true);

        // Disable data storage
        settings.setDomStorageEnabled(false);
        settings.setDatabaseEnabled(false);

        // Prevent caching
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);

        // Disable form data and password saving
        settings.setSaveFormData(false);
        settings.setSavePassword(false);

        // Content display settings
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setLoadsImagesAutomatically(true);

        // User agent from device profile
        if (deviceProfile != null && deviceProfile.getUserAgent() != null) {
            settings.setUserAgentString(deviceProfile.getUserAgent());
            Logger.d(TAG, "Set user agent: " + deviceProfile.getUserAgent());
        }

        // Clear existing data
        webView.clearCache(true);
        webView.clearHistory();
        webView.clearFormData();

        // Remove cookies
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.removeAllCookies(null);
        cookieManager.flush();
        cookieManager.setAcceptCookie(false);

        // Set a unique identifier for the session
        webView.setTag(UUID.randomUUID().toString());

        Logger.i(TAG, "WebView configured for device: " +
                (deviceProfile != null ? deviceProfile.getDeviceType() : "unknown") +
                " with incognito settings");
    }

    /**
     * Clear all WebView data and cookies.
     * @param webView WebView to clear
     */
    public void clearWebViewData(WebView webView) {
        if (webView != null) {
            webView.clearCache(true);
            webView.clearHistory();
            webView.clearFormData();

            CookieManager cookieManager = CookieManager.getInstance();
            cookieManager.removeAllCookies(null);
            cookieManager.flush();
            cookieManager.setAcceptCookie(false);

            Logger.d(TAG, "WebView data completely cleared");
        }
    }

    /**
     * Configure WebView for incognito mode
     * @param webView WebView to configure
     */
    public void configureWebViewForIncognito(WebView webView) {
        if (webView == null) {
            Logger.e(TAG, "Cannot configure null WebView");
            return;
        }

        WebSettings settings = webView.getSettings();

        // Incognito-focused settings
        settings.setJavaScriptEnabled(true);

        // Disable data storage
        settings.setDomStorageEnabled(false);
        settings.setDatabaseEnabled(false);

        // Prevent caching
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);

        // Disable form data and password saving
        settings.setSaveFormData(false);
        settings.setSavePassword(false);

        // Content display settings
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setLoadsImagesAutomatically(true);

        // Clear existing data
        webView.clearCache(true);
        webView.clearHistory();
        webView.clearFormData();

        // Remove cookies
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.removeAllCookies(null);
        cookieManager.flush();
        cookieManager.setAcceptCookie(false);

        // Set a unique identifier for the session
        webView.setTag(UUID.randomUUID().toString());

        Logger.i(TAG, "WebView configured for incognito mode");
    }


}

