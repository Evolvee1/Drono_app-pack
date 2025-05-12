package com.example.imtbf.data.network;

import android.content.Context;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import com.example.imtbf.utils.Logger;

public class SessionClearingManager {
    private static final String TAG = "SessionClearingManager";

    private final Context context;

    public SessionClearingManager(Context context) {
        this.context = context.getApplicationContext();
    }

    /**
     * Clear all session-related data from WebView
     * @param webView WebView to clear
     */
    public void clearSessionData(WebView webView) {
        try {
            // Clear cookies
            clearCookies();

            // Clear WebView cache
            webView.clearCache(true);

            // Clear WebView history
            webView.clearHistory();

            // Clear form data
            webView.clearFormData();

            // Load blank page to reset
            webView.loadUrl("about:blank");

            Logger.d(TAG, "Session data cleared successfully");
        } catch (Exception e) {
            Logger.e(TAG, "Error clearing session data", e);
        }
    }

    /**
     * Create a fresh WebView with minimal settings
     * @return Clean WebView
     */
    public WebView createCleanWebView() {
        WebView webView = new WebView(context);

        // Minimal, privacy-focused settings
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);

        // Disable data storage
        settings.setDomStorageEnabled(false);
        settings.setDatabaseEnabled(false);

        return webView;
    }

    /**
     * Clear all cookies from WebView
     */
    private void clearCookies() {
        try {
            CookieManager cookieManager = CookieManager.getInstance();
            cookieManager.removeAllCookies(null);
            cookieManager.flush();
            Logger.d(TAG, "All cookies cleared");
        } catch (Exception e) {
            Logger.e(TAG, "Error clearing cookies", e);
        }
    }
}