package com.example.imtbf;

import android.app.Application;
import android.content.Context;
import android.util.Log;

import androidx.work.Configuration;

import com.example.imtbf.data.local.PreferencesManager;
import com.example.imtbf.utils.Logger;
import com.example.imtbf.domain.webview.WebViewController;
import com.example.imtbf.data.network.WebViewRequestManager;

/**
 * Main Application class that initializes app-wide components.
 * This is the entry point for the application's global state.
 */
public class InstagramTrafficSimulatorApp extends Application implements Configuration.Provider {

    private static final String TAG = "ItsApplication";
    private static Context applicationContext;
    private PreferencesManager preferencesManager;

    private WebViewRequestManager webViewRequestManager;
    private WebViewController webViewController;

    @Override
    public void onCreate() {
        super.onCreate();
        applicationContext = getApplicationContext();

        // Initialize preferences
        preferencesManager = new PreferencesManager(this);

        // Initialize logging
        Logger.init(preferencesManager.isDebugLoggingEnabled());

        Logger.d(TAG, "Application initialized");
    }

    @Override
    public Configuration getWorkManagerConfiguration() {
        return new Configuration.Builder()
                .setMinimumLoggingLevel(Log.INFO)
                .build();
    }

    /**
     * Get the application context from anywhere in the app.
     * @return The application context
     */
    public static Context getAppContext() {
        return applicationContext;
    }

    /**
     * Get the preferences manager from anywhere in the app.
     * @return The preferences manager
     */

    public PreferencesManager getPreferencesManager() {
        return preferencesManager;
    }
    // Add getter method
    public WebViewRequestManager getWebViewRequestManager() {
        return webViewRequestManager;
    }

    public WebViewController getWebViewController() {
        return webViewController;
    }
}