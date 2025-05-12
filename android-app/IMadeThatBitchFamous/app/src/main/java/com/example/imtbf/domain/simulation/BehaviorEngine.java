package com.example.imtbf.domain.simulation;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.utils.Logger;

import java.util.Random;
import java.util.concurrent.CompletableFuture;

/**
 * Engine for simulating human-like browsing behavior.
 * This is used to create realistic patterns of user interaction.
 */
public class BehaviorEngine {

    private static final String TAG = "BehaviorEngine";
    private final Random random = new Random();
    private final TimingDistributor timingDistributor;

    /**
     * Constructor with default timing distributor.
     */
    public BehaviorEngine() {
        this.timingDistributor = new TimingDistributor();
    }

    /**
     * Constructor with custom timing distributor.
     * @param timingDistributor Timing distributor
     */
    public BehaviorEngine(TimingDistributor timingDistributor) {
        this.timingDistributor = timingDistributor;
    }

    /**
     * Simulate a complete session of user interaction.
     * @param deviceProfile Device profile
     * @param contentLength Content length (0-100)
     * @return CompletableFuture that completes when the simulation is done
     */
    public CompletableFuture<Void> simulateSession(DeviceProfile deviceProfile, int contentLength) {
        return CompletableFuture.runAsync(() -> {
            try {
                Logger.d(TAG, "Starting behavior simulation session");

                // Initial page load time (simulated)
                int loadTimeMs = getRandomLoadTime(deviceProfile);
                Logger.d(TAG, "Page load time: " + loadTimeMs + "ms");
                Thread.sleep(loadTimeMs);

                // Reading time
                long readingTimeMs = timingDistributor.getReadingTimeMs(deviceProfile, contentLength);
                Logger.d(TAG, "Reading content for " + readingTimeMs + "ms");
                Thread.sleep(readingTimeMs);

                // Scrolling behavior (if applicable)
                if (timingDistributor.willScroll()) {
                    int scrollDepth = timingDistributor.getScrollDepthPercent();
                    Logger.d(TAG, "Scrolling to " + scrollDepth + "% of content");

                    // Simulate scrolling with proper timing
                    simulateScrolling(scrollDepth);
                }

                // Secondary actions (depends on content type)
                if (random.nextFloat() < 0.3f) { // 30% chance of secondary action
                    simulateSecondaryAction(deviceProfile);
                }

                // Exit delay (time before leaving the page)
                int exitDelayMs = (int) (500 + random.nextFloat() * 2000); // 0.5-2.5 seconds
                Logger.d(TAG, "Exit delay: " + exitDelayMs + "ms");
                Thread.sleep(exitDelayMs);

                Logger.d(TAG, "Behavior simulation session completed");

            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                Logger.w(TAG, "Behavior simulation interrupted");
            } catch (Exception e) {
                Logger.e(TAG, "Error in behavior simulation", e);
            }
        });
    }

    /**
     * Get a random page load time based on device profile.
     * @param deviceProfile Device profile
     * @return Load time in milliseconds
     */
    private int getRandomLoadTime(DeviceProfile deviceProfile) {
        // Base load time
        int baseLoadTimeMs = 1000; // 1 second base time

        // Adjust based on device tier
        if (DeviceProfile.TIER_BUDGET.equals(deviceProfile.getDeviceTier())) {
            baseLoadTimeMs += 1000; // Budget devices are slower
        } else if (DeviceProfile.TIER_FLAGSHIP.equals(deviceProfile.getDeviceTier())) {
            baseLoadTimeMs -= 200; // Flagship devices are faster
        }

        // Adjust based on platform (mobile vs desktop)
        if (!deviceProfile.isMobile()) {
            baseLoadTimeMs -= 300; // Desktop connections often faster
        }

        // Add random variation
        baseLoadTimeMs += (int) (random.nextGaussian() * 300); // Add some random variation

        // Ensure reasonable bounds
        return Math.max(500, Math.min(5000, baseLoadTimeMs));
    }

    /**
     * Simulate scrolling behavior with realistic timing.
     * @param scrollDepthPercent Target scroll depth percentage
     */
    private void simulateScrolling(int scrollDepthPercent) throws InterruptedException {
        // Number of scroll events
        int scrollCount = 5 + (int) (scrollDepthPercent / 10.0);

        // Time between scrolls (slows down as user reads)
        long baseScrollInterval = 300; // 300ms initial interval

        for (int i = 0; i < scrollCount; i++) {
            // Calculate current depth
            int currentDepth = (int) (((float) i / scrollCount) * scrollDepthPercent);

            // Slower scrolling as user gets further down
            long scrollInterval = baseScrollInterval +
                    (long) (i * 2.5 * baseScrollInterval / scrollCount);

            // Add human-like random variation
            scrollInterval += (long) (random.nextGaussian() * 100);

            // Ensure reasonable bounds
            scrollInterval = Math.max(100, Math.min(2000, scrollInterval));

            Logger.d(TAG, "Scroll event: depth " + currentDepth +
                    "%, next in " + scrollInterval + "ms");

            // Wait before next scroll
            Thread.sleep(scrollInterval);

            // Occasional pause to read content
            if (random.nextFloat() < 0.2) { // 20% chance of pausing
                long pauseTime = (long) (500 + random.nextGaussian() * 300);
                pauseTime = Math.max(200, Math.min(1500, pauseTime));

                Logger.d(TAG, "Pausing at " + currentDepth + "% for " + pauseTime + "ms");
                Thread.sleep(pauseTime);
            }
        }
    }

    /**
     * Simulate a secondary action that a user might take.
     * @param deviceProfile Device profile
     */
    private void simulateSecondaryAction(DeviceProfile deviceProfile) throws InterruptedException {
        float actionType = random.nextFloat();

        if (actionType < 0.5f) {
            // Simulate clicking a link or button
            Logger.d(TAG, "Secondary action: Clicking a link");

            // Time to find and click
            long findTimeMs = Math.max(50, (long)(800 + random.nextGaussian() * 200));
            Thread.sleep(findTimeMs);

            // Simulated click
            Thread.sleep(50);

            // Wait for imaginary content to appear
            Thread.sleep(300);

        } else if (actionType < 0.8f) {
            // Simulate text selection
            Logger.d(TAG, "Secondary action: Selecting text");

            // Time to start selection
            Thread.sleep(500);

            // Dragging to select
            long selectionTimeMs = Math.max(50, (long)(400 + random.nextGaussian() * 100));
            Thread.sleep(selectionTimeMs);

        } else {
            // Simulate hovering over elements
            Logger.d(TAG, "Secondary action: Hovering over elements");

            // Several hover events
            int hoverCount = 2 + random.nextInt(4);
            for (int i = 0; i < hoverCount; i++) {
                // Move time
                long moveTimeMs = Math.max(50, (long)(300 + random.nextGaussian() * 100));
                Thread.sleep(moveTimeMs);

                // Hover time
                long hoverTimeMs = Math.max(50, (long)(200 + random.nextGaussian() * 150));
                Thread.sleep(hoverTimeMs);
            }
        }
    }

    /**
     * Get the timing distributor.
     * @return Timing distributor
     */
    public TimingDistributor getTimingDistributor() {
        return timingDistributor;
    }
}