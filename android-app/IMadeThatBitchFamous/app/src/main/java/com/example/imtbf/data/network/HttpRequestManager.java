package com.example.imtbf.data.network;

import android.content.Context;

import androidx.annotation.NonNull;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.data.models.SimulationSession;
import com.example.imtbf.utils.Constants;
import com.example.imtbf.utils.Logger;
import com.example.imtbf.data.network.NetworkStatsInterceptor;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.ConnectionPool;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;



/**
 * Manages HTTP requests with Instagram referrer spoofing.
 * This class handles making requests that appear to come from Instagram.
 */
public class HttpRequestManager {

    private static final String TAG = "HttpRequestManager";
    private static final int CONNECTION_TIMEOUT = 30; // seconds
    private static final int READ_TIMEOUT = 30; // seconds
    private static final int MAX_IDLE_CONNECTIONS = 5;
    private static final long KEEP_ALIVE_DURATION = 5; // minutes

    private final OkHttpClient client;
    private final NetworkStateMonitor networkStateMonitor;

    private NetworkStatsInterceptor networkStatsInterceptor;

    /**
     * Constructor that initializes the HTTP client.
     * @param context Application context
     * @param networkStateMonitor Network state monitor
     */
    public HttpRequestManager(Context context, NetworkStateMonitor networkStateMonitor) {
        this.networkStateMonitor = networkStateMonitor;

        ConnectionPool connectionPool = new ConnectionPool(
                MAX_IDLE_CONNECTIONS, KEEP_ALIVE_DURATION, TimeUnit.MINUTES);

        client = new OkHttpClient.Builder()
                .connectionPool(connectionPool)
                .connectTimeout(CONNECTION_TIMEOUT, TimeUnit.SECONDS)
                .readTimeout(READ_TIMEOUT, TimeUnit.SECONDS)
                .build();
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

        String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();
        Logger.i(TAG, "Making request to " + url + " with IP " + currentIp);
        Logger.d(TAG, "Using " + (deviceProfile.isInstagramApp() ? "Instagram app" : "browser") +
                " profile on " + deviceProfile.getPlatform() +
                " device type: " + deviceProfile.getDeviceType());

        long startTime = System.currentTimeMillis();

        // Build the request with Instagram headers
        Request.Builder requestBuilder = new Request.Builder()
                .url(url)
                .header(Constants.HEADER_USER_AGENT, deviceProfile.getUserAgent());

        // Add additional Instagram-specific headers
        Map<String, String> instagramHeaders = getInstagramHeaders(deviceProfile);
        StringBuilder headerDebug = new StringBuilder("Request headers:\n");

        for (Map.Entry<String, String> header : instagramHeaders.entrySet()) {
            requestBuilder.header(header.getKey(), header.getValue());
            headerDebug.append(header.getKey()).append(": ").append(header.getValue()).append("\n");
        }

        Logger.d(TAG, headerDebug.toString());

        // Build the final request
        Request request = requestBuilder.build();

        // Execute the request
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                long responseTime = System.currentTimeMillis() - startTime;
                Logger.e(TAG, "Request failed: " + e.getMessage() + " after " + responseTime + "ms");

                if (session != null) {
                    session.addRequestResult(
                            new SimulationSession.RequestResult(
                                    e.getMessage(), currentIp));
                }

                if (callback != null) {
                    callback.onError(e.getMessage());
                }
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                long responseTime = System.currentTimeMillis() - startTime;
                int statusCode = response.code();
                String responseBody = "";

                try {
                    // Read a small part of the response body for logging
                    ResponseBody body = response.body();
                    if (body != null) {
                        String fullBody = body.string();
                        responseBody = fullBody.length() > 100 ?
                                fullBody.substring(0, 100) + "..." : fullBody;
                    }
                } catch (Exception e) {
                    Logger.w(TAG, "Couldn't read response body: " + e.getMessage());
                }

                Logger.i(TAG, "Request completed: " + statusCode +
                        " in " + responseTime + "ms");
                Logger.d(TAG, "Response preview: " + responseBody);

                if (session != null) {
                    session.addRequestResult(
                            new SimulationSession.RequestResult(
                                    statusCode, responseTime, currentIp));
                }

                if (callback != null) {
                    callback.onSuccess(statusCode, responseTime);
                }

                response.close();
            }
        });
    }

    /**
     * Get Instagram-specific headers based on the device profile.
     * @param deviceProfile Device profile
     * @return Map of headers
     */
    private Map<String, String> getInstagramHeaders(DeviceProfile deviceProfile) {
        Map<String, String> headers = new HashMap<>();

        if (deviceProfile.isInstagramApp()) {
            // Instagram app headers (different depending on platform)
            headers.put("X-IG-App-ID", "936619743392459");
            headers.put("X-Instagram-AJAX", "1");

            if (DeviceProfile.PLATFORM_ANDROID.equals(deviceProfile.getPlatform())) {
                headers.put("X-IG-Android-ID", generateRandomAndroidId());
                headers.put("X-IG-Capabilities", "3brTvw==");
                headers.put("X-IG-Connection-Type", "WIFI");
                // Instagram app on Android uses a different referrer
                headers.put("Referer", "https://www.instagram.com/android-app/");
            } else if (DeviceProfile.PLATFORM_IOS.equals(deviceProfile.getPlatform())) {
                headers.put("X-IG-iOS-Version", "14.0");
                headers.put("X-IG-Connection-Type", "WIFI");
                headers.put("X-IG-Capabilities", "36r/F/8=");
                // Instagram app on iOS uses a different referrer
                headers.put("Referer", "https://www.instagram.com/ios-app/");
            }
        } else {
            // Browser headers
            headers.put("Origin", Constants.INSTAGRAM_REFERER);
            headers.put("Referer", Constants.INSTAGRAM_REFERER);
            headers.put("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
            headers.put("Accept-Language", "en-US,en;q=0.5");
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

        return headers;
    }

    /**
     * Generate a random Android ID for Instagram headers.
     * @return Random Android ID
     */
    private String generateRandomAndroidId() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 16; i++) {
            sb.append(Integer.toHexString((int) (Math.random() * 16)));
        }
        return sb.toString();
    }

    /**
     * Callback interface for HTTP requests.
     */
    public interface RequestCallback {
        /**
         * Called when the request is successful.
         * @param statusCode HTTP status code
         * @param responseTimeMs Response time in milliseconds
         */
        void onSuccess(int statusCode, long responseTimeMs);

        /**
         * Called when the request fails.
         * @param error Error message
         */
        void onError(String error);
    }
}