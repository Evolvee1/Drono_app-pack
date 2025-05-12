package com.example.imtbf.domain.webview;

import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.utils.Logger;

import java.util.Random;
import java.util.concurrent.CompletableFuture;

/**
 * Engine for simulating human-like browsing behavior in a WebView.
 */
public class WebViewBehaviorEngine {
    private static final String TAG = "WebViewBehaviorEngine";
    private final Random random = new Random();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    /**
     * Interface for JavaScript communication.
     */
    public class BehaviorJavaScriptInterface {
        @JavascriptInterface
        public void onScroll(int scrollY) {
            Logger.d(TAG, "Page scrolled to position Y: " + scrollY);
        }

        @JavascriptInterface
        public void onElementClick(String elementInfo) {
            Logger.d(TAG, "Element clicked: " + elementInfo);
        }
    }

    /**
     * Simulate a browsing session in a WebView.
     * @param webView WebView to use for simulation
     * @param deviceProfile Device profile
     * @param contentLength Content length estimation (0-100)
     * @return CompletableFuture that completes when simulation is done
     */
    public CompletableFuture<Void> simulateSession(WebView webView, DeviceProfile deviceProfile, int contentLength) {
        CompletableFuture<Void> future = new CompletableFuture<>();

        if (webView == null) {
            Logger.e(TAG, "Cannot simulate on null WebView");
            future.complete(null);
            return future;
        }

        // Add JavaScript interface
        mainHandler.post(() -> {
            webView.addJavascriptInterface(new BehaviorJavaScriptInterface(), "BehaviorBridge");

            // Start simulation
            simulateReading(webView, deviceProfile, contentLength, future);
        });

        return future;
    }

    /**
     * Simulate reading content.
     */
    private void simulateReading(WebView webView, DeviceProfile deviceProfile,
                                 int contentLength, CompletableFuture<Void> future) {
        // Calculate reading time
        long readingTimeMs = getReadingTime(deviceProfile, contentLength);
        Logger.d(TAG, "Simulating reading for " + readingTimeMs + "ms");

        // After reading time, simulate scrolling
        mainHandler.postDelayed(() -> {
            if (shouldScroll()) {
                simulateScrolling(webView, getScrollDepth(), future);
            } else {
                // No scrolling, just complete
                future.complete(null);
            }
        }, readingTimeMs);
    }

    /**
     * Simulate scrolling behavior.
     */
    private void simulateScrolling(WebView webView, int scrollDepthPercent, CompletableFuture<Void> future) {
        Logger.d(TAG, "Simulating scroll to " + scrollDepthPercent + "% of page");

        // Get page height via JavaScript
        webView.evaluateJavascript(
                "(function() { " +
                        "return document.body.scrollHeight || " +
                        "document.documentElement.scrollHeight; " +
                        "})()",
                heightResult -> {
                    try {
                        int pageHeight = Integer.parseInt(heightResult);
                        int targetScroll = (pageHeight * scrollDepthPercent) / 100;

                        // Perform gradual scrolling
                        performGradualScroll(webView, targetScroll, future);
                    } catch (Exception e) {
                        Logger.e(TAG, "Error parsing page height: " + e.getMessage());
                        future.complete(null);
                    }
                }
        );
    }

    /**
     * Perform gradual scrolling to simulate natural human behavior.
     */
    private void performGradualScroll(WebView webView, int targetScroll, CompletableFuture<Void> future) {
        // Calculate number of scroll steps
        int scrollSteps = 5 + random.nextInt(10); // 5-15 scroll actions
        int scrollPerStep = targetScroll / scrollSteps;
        int currentStep = 0;

        // Schedule scrolling
        scheduleNextScroll(webView, scrollPerStep, currentStep, scrollSteps, future);
    }

    /**
     * Schedule the next scroll action.
     */
    private void scheduleNextScroll(WebView webView, int scrollPerStep, int currentStep,
                                    int totalSteps, CompletableFuture<Void> future) {
        if (currentStep >= totalSteps) {
            // Scrolling complete
            Logger.d(TAG, "Scrolling complete after " + totalSteps + " steps");
            future.complete(null);
            return;
        }

        // Calculate delay before next scroll (300-800ms)
        int delay = 300 + random.nextInt(500);

        // Perform scroll after delay
        mainHandler.postDelayed(() -> {
            // Execute scroll JavaScript
            String scrollScript = "window.scrollBy(0, " + scrollPerStep + "); " +
                    "BehaviorBridge.onScroll(window.pageYOffset);";
            webView.evaluateJavascript(scrollScript, null);

            // Schedule next scroll
            scheduleNextScroll(webView, scrollPerStep, currentStep + 1, totalSteps, future);

            // Possibly pause scrolling to simulate reading
            if (random.nextFloat() < 0.2f) { // 20% chance
                int pauseTime = 1000 + random.nextInt(2000); // 1-3 seconds
                Logger.d(TAG, "Pausing scroll for " + pauseTime + "ms to read content");
            }

        }, delay);
    }

    // Helper methods similar to TimingDistributor
    private long getReadingTime(DeviceProfile deviceProfile, int contentLength) {
        // Base reading time: 5-20 seconds
        int baseTime = 5000 + (contentLength * 150);

        // Apply variations
        if (deviceProfile.isMobile()) {
            baseTime = (int)(baseTime * 0.8); // Mobile users read faster
        }

        // Add randomness
        return (long)(baseTime * (0.8 + (random.nextFloat() * 0.4)));
    }

    private boolean shouldScroll() {
        return random.nextFloat() < 0.85f; // 85% chance of scrolling
    }

    private int getScrollDepth() {
        // Most users scroll to 50-70% of the page
        return 40 + random.nextInt(40);
    }
}