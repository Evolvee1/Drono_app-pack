package com.example.imtbf.domain.webview;

import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

import com.example.imtbf.utils.Logger;

import java.util.Random;
import java.util.concurrent.CompletableFuture;

/**
 * Simulates realistic user interactions on a webpage.
 */
public class PageInteractionSimulator {
    private static final String TAG = "PageInteractionSimulator";
    private final Random random = new Random();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    /**
     * Simulate a realistic session of user interaction on a page.
     * @param webView WebView to interact with
     * @param durationMs How long to interact with the page
     * @return CompletableFuture that completes when simulation is done
     */
    public CompletableFuture<Void> simulatePageInteraction(WebView webView, int durationMs) {
        CompletableFuture<Void> future = new CompletableFuture<>();

        if (webView == null) {
            Logger.e(TAG, "Cannot simulate on null WebView");
            future.complete(null);
            return future;
        }

        Logger.i(TAG, "Starting page interaction for " + durationMs + "ms");

        // Schedule various interactions during the session
        scheduleInteractions(webView, durationMs, future);

        return future;
    }

    private void scheduleInteractions(WebView webView, int totalDurationMs, CompletableFuture<Void> future) {
        // Determine how many interactions to perform
        int interactionCount = 3 + random.nextInt(3); // 3-5 interactions
        int timePerInteraction = totalDurationMs / (interactionCount + 1);

        Logger.d(TAG, "Scheduling " + interactionCount + " interactions");

        // Schedule each interaction at appropriate intervals
        for (int i = 1; i <= interactionCount; i++) {
            final int delay = i * timePerInteraction;
            final int interactionType = random.nextInt(3); // 0=scroll, 1=move, 2=click

            mainHandler.postDelayed(() -> {
                switch (interactionType) {
                    case 0:
                        simulateScroll(webView);
                        break;
                    case 1:
                        simulateMouseMovement(webView);
                        break;
                    case 2:
                        simulateRandomClick(webView);
                        break;
                }
            }, delay);
        }

        // Complete the future after the session duration
        mainHandler.postDelayed(() -> {
            Logger.i(TAG, "Page interaction complete after " + totalDurationMs + "ms");
            future.complete(null);
        }, totalDurationMs);
    }

    private void simulateScroll(WebView webView) {
        int scrollAmount = 50 + random.nextInt(150); // 50-200px scroll
        String js = "window.scrollBy(0, " + scrollAmount + ");";
        webView.evaluateJavascript(js, null);
        Logger.d(TAG, "Simulated scroll of " + scrollAmount + "px");
    }

    private void simulateMouseMovement(WebView webView) {
        String js =
                "var event = new MouseEvent('mousemove', {" +
                        "  bubbles: true," +
                        "  cancelable: true," +
                        "  view: window," +
                        "  clientX: Math.floor(Math.random() * window.innerWidth)," +
                        "  clientY: Math.floor(Math.random() * window.innerHeight)" +
                        "});" +
                        "document.dispatchEvent(event);";

        webView.evaluateJavascript(js, null);
        Logger.d(TAG, "Simulated mouse movement");
    }

    private void simulateRandomClick(WebView webView) {
        String js =
                "(function() {" +
                        "  var clickables = [];" +
                        "  var links = document.getElementsByTagName('a');" +
                        "  var buttons = document.getElementsByTagName('button');" +
                        "  for (var i = 0; i < Math.min(links.length, 20); i++) {" + // Limit to first 20 for performance
                        "    if (links[i].offsetParent !== null) clickables.push(links[i]);" +
                        "  }" +
                        "  for (var i = 0; i < Math.min(buttons.length, 10); i++) {" +
                        "    if (buttons[i].offsetParent !== null) clickables.push(buttons[i]);" +
                        "  }" +
                        "  if (clickables.length > 0) {" +
                        "    var randomIndex = Math.floor(Math.random() * clickables.length);" +
                        "    var element = clickables[randomIndex];" +
                        "    var elemText = element.textContent || element.innerText;" +
                        "    return 'Found clickable: ' + elemText;" +
                        "  } else {" +
                        "    return 'No clickable elements found';" +
                        "  }" +
                        "})();";

        webView.evaluateJavascript(js, result -> {
            Logger.d(TAG, "Click target search: " + result);

            // Only perform click if we found something clickable
            if (!result.contains("No clickable")) {
                // We found a clickable, now click it
                String clickJs =
                        "(function() {" +
                                "  var clickables = [];" +
                                "  var links = document.getElementsByTagName('a');" +
                                "  var buttons = document.getElementsByTagName('button');" +
                                "  for (var i = 0; i < Math.min(links.length, 20); i++) {" +
                                "    if (links[i].offsetParent !== null) clickables.push(links[i]);" +
                                "  }" +
                                "  for (var i = 0; i < Math.min(buttons.length, 10); i++) {" +
                                "    if (buttons[i].offsetParent !== null) clickables.push(buttons[i]);" +
                                "  }" +
                                "  if (clickables.length > 0) {" +
                                "    var randomIndex = Math.floor(Math.random() * clickables.length);" +
                                "    var element = clickables[randomIndex];" +
                                "    element.click();" +
                                "    return 'Clicked element';" +
                                "  }" +
                                "})();";
                webView.evaluateJavascript(clickJs, clickResult -> {
                    Logger.d(TAG, "Click result: " + clickResult);
                });
            }
        });
    }
}