package com.example.imtbf.data.network;

import com.example.imtbf.utils.Logger;

import java.io.IOException;

import okhttp3.Interceptor;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * OkHttp interceptor to track network usage.
 */
public class NetworkStatsInterceptor implements Interceptor {
    private static final String TAG = "NetworkStatsInterceptor";
    private final NetworkStatsTracker statsTracker;

    /**
     * Create a new network stats interceptor
     * @param statsTracker Network stats tracker
     */
    public NetworkStatsInterceptor(NetworkStatsTracker statsTracker) {
        this.statsTracker = statsTracker;
    }

    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();
        long startTime = System.nanoTime();

        // Calculate request size
        long requestBytes = calculateRequestSize(request);
        statsTracker.addUploadBytes(requestBytes);

        Response response;
        try {
            response = chain.proceed(request);
        } catch (IOException e) {
            Logger.e(TAG, "Network error: " + e.getMessage());
            // Record that we attempted a request
            statsTracker.recordRequest();
            throw e;
        }

        // Record successful request
        statsTracker.recordRequest();

        // Get response details
        ResponseBody responseBody = response.body();

        // Measure response size if we have a body
        long responseBytes = 0;
        if (responseBody != null) {
            responseBytes = responseBody.contentLength();

            // If content length is unknown, we can't track it precisely
            // But we'll record something to show activity
            if (responseBytes < 0) {
                responseBytes = 100; // Just a token amount
            }
        }

        // Record download size
        statsTracker.addDownloadBytes(responseBytes);

        // Log the request
        long duration = (System.nanoTime() - startTime) / 1_000_000; // Convert to ms
        Logger.d(TAG, String.format("Request: %s %s (%d ms, ⬆️ %s, ⬇️ %s)",
                request.method(), request.url(), duration,
                NetworkStatsTracker.formatBytes(requestBytes),
                NetworkStatsTracker.formatBytes(responseBytes)));

        return response;
    }

    /**
     * Estimate the size of a request in bytes
     * @param request The request
     * @return Size in bytes
     */
    private long calculateRequestSize(Request request) {
        long size = 0;

        // URL size (rough estimate)
        size += request.url().toString().length();

        // Headers size
        for (String name : request.headers().names()) {
            size += name.length() + request.header(name).length() + 4; // ':' + ' ' + '\r\n'
        }

        // Request method and HTTP version
        size += request.method().length() + 10; // " HTTP/1.1\r\n"

        // Request body if present
        if (request.body() != null) {
            try {
                size += request.body().contentLength();
            } catch (IOException e) {
                Logger.e(TAG, "Error getting content length: " + e.getMessage());
                // Use a reasonable default value for the size estimate
                size += 100; // Default to 100 bytes if we can't determine
            }
        }

        return size;
    }
}