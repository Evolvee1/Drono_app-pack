package com.example.imtbf.domain.simulation;

import com.example.imtbf.data.models.DeviceProfile;
import com.example.imtbf.utils.Constants;
import com.example.imtbf.utils.Logger;

import java.util.Random;

/**
 * Responsible for generating human-like timing patterns for simulations.
 * This class provides various timing distributions that mimic real user behavior.
 */
public class TimingDistributor {

    private static final String TAG = "TimingDistributor";
    private final Random random = new Random();

    // Session timing parameters
    private int minIntervalSeconds;
    private int maxIntervalSeconds;
    private int readingTimeMeanMs;
    private int readingTimeStdDevMs;
    private float scrollProbability;

    /**
     * Constructor with default timing parameters.
     */
    public TimingDistributor() {
        this.minIntervalSeconds = Constants.DEFAULT_MIN_INTERVAL;
        this.maxIntervalSeconds = Constants.DEFAULT_MAX_INTERVAL;
        this.readingTimeMeanMs = Constants.READING_TIME_MEAN_MS;
        this.readingTimeStdDevMs = Constants.READING_TIME_STDDEV_MS;
        this.scrollProbability = Constants.SCROLL_PROBABILITY;
    }

    /**
     * Constructor with custom timing parameters.
     * @param minIntervalSeconds Minimum interval between requests in seconds
     * @param maxIntervalSeconds Maximum interval between requests in seconds
     * @param readingTimeMeanMs Mean reading time in milliseconds
     * @param readingTimeStdDevMs Standard deviation of reading time in milliseconds
     * @param scrollProbability Probability of scrolling (0.0 to 1.0)
     */
    public TimingDistributor(int minIntervalSeconds, int maxIntervalSeconds,
                             int readingTimeMeanMs, int readingTimeStdDevMs,
                             float scrollProbability) {
        this.minIntervalSeconds = minIntervalSeconds;
        this.maxIntervalSeconds = maxIntervalSeconds;
        this.readingTimeMeanMs = readingTimeMeanMs;
        this.readingTimeStdDevMs = readingTimeStdDevMs;
        this.scrollProbability = scrollProbability;
    }

    /**
     * Generate a random interval between min and max in seconds.
     * @return Random interval in seconds
     */
    public int getRandomIntervalSeconds() {
        if (minIntervalSeconds >= maxIntervalSeconds) {
            return minIntervalSeconds;
        }

        // Basic uniform distribution between min and max
        int result = minIntervalSeconds + random.nextInt(maxIntervalSeconds - minIntervalSeconds + 1);
        Logger.d(TAG, "Generated random interval: " + result + " seconds");
        return result;
    }

    /**
     * Generate a human-like interval based on realistic behavior patterns.
     * This uses a more sophisticated approach than simple uniform distribution.
     * @return Human-like interval in seconds
     */
    public int getHumanLikeIntervalSeconds() {
        // Add debugging
        Logger.d(TAG, "Getting interval between min=" + minIntervalSeconds + " and max=" + maxIntervalSeconds);

        // Ensure min and max are properly set
        if (minIntervalSeconds <= 0) minIntervalSeconds = 1;
        if (maxIntervalSeconds <= 0) maxIntervalSeconds = 60;
        if (maxIntervalSeconds < minIntervalSeconds) {
            maxIntervalSeconds = minIntervalSeconds + 1;
        }

        // Calculate interval using one of three methods
        float choice = random.nextFloat();
        int result;

        if (choice < 0.5f) {
            // Normal distribution centered between min and max
            int mean = (minIntervalSeconds + maxIntervalSeconds) / 2;
            int stdDev = Math.max(1, (maxIntervalSeconds - minIntervalSeconds) / 4);
            result = (int) Math.max(minIntervalSeconds, Math.min(maxIntervalSeconds,
                    generateNormalDistribution(mean, stdDev)));

        } else if (choice < 0.8f) {
            // Exponential distribution for quick successive visits
            result = (int) Math.max(minIntervalSeconds,
                    Math.min(maxIntervalSeconds,
                            generateExponentialDistribution(minIntervalSeconds)));

        } else {
            // Long-tail distribution for occasional long pauses
            int mean = minIntervalSeconds + (maxIntervalSeconds - minIntervalSeconds) / 3;
            int stdDev = Math.max(1, (maxIntervalSeconds - minIntervalSeconds) / 2);
            result = (int) Math.max(minIntervalSeconds, Math.min(maxIntervalSeconds,
                    generateNormalDistribution(mean, stdDev) +
                            generateExponentialDistribution(stdDev / 2)));
        }

        Logger.d(TAG, "Generated human-like interval: " + result + " seconds");
        return result;
    }

    /**
     * Generate reading time based on device type and content length.
     * @param deviceProfile Device profile
     * @param contentLength Approximate content length (0-100, where 100 is very long)
     * @return Reading time in milliseconds
     */
    public long getReadingTimeMs(DeviceProfile deviceProfile, int contentLength) {
        // Adjust reading time based on device type (mobile users read faster)
        int adjustedMean = readingTimeMeanMs;

        if (deviceProfile.isMobile()) {
            // Mobile users spend 20% less time on average
            adjustedMean = (int) (readingTimeMeanMs * 0.8);
        }

        // Adjust based on content length (longer content = longer reading time)
        adjustedMean = (int) (adjustedMean * (0.5 + contentLength / 100.0));

        // Generate reading time with normal distribution
        long readingTime = (long) generateNormalDistribution(adjustedMean, readingTimeStdDevMs);

        // Ensure positive value
        readingTime = Math.max(1000, readingTime);

        Logger.d(TAG, "Generated reading time: " + readingTime + "ms");
        return readingTime;
    }

    /**
     * Determine if the user will scroll based on probability.
     * @return True if the user will scroll, false otherwise
     */
    public boolean willScroll() {
        return random.nextFloat() < scrollProbability;
    }

    /**
     * Determine scroll depth as a percentage of content.
     * @return Scroll depth percentage (0-100)
     */
    public int getScrollDepthPercent() {
        // Most users scroll to around 50-60% with normal distribution
        return (int) Math.min(100, Math.max(0,
                generateNormalDistribution(Constants.AVERAGE_SCROLL_DEPTH_PERCENT, 20)));
    }

    /**
     * Generate a value from a normal distribution.
     * @param mean Mean value
     * @param stdDev Standard deviation
     * @return Normally distributed value
     */
    private double generateNormalDistribution(double mean, double stdDev) {
        return random.nextGaussian() * stdDev + mean;
    }

    /**
     * Generate a value from an exponential distribution.
     * @param mean Mean value
     * @return Exponentially distributed value
     */
    private double generateExponentialDistribution(double mean) {
        return -mean * Math.log(1 - random.nextDouble());
    }

    /**
     * Get session timing parameters.
     */
    public int getMinIntervalSeconds() {
        return minIntervalSeconds;
    }

    public void setMinIntervalSeconds(int minIntervalSeconds) {
        this.minIntervalSeconds = minIntervalSeconds;
    }

    public int getMaxIntervalSeconds() {
        return maxIntervalSeconds;
    }

    public void setMaxIntervalSeconds(int maxIntervalSeconds) {
        this.maxIntervalSeconds = maxIntervalSeconds;
    }

    public int getReadingTimeMeanMs() {
        return readingTimeMeanMs;
    }

    public void setReadingTimeMeanMs(int readingTimeMeanMs) {
        this.readingTimeMeanMs = readingTimeMeanMs;
    }

    public int getReadingTimeStdDevMs() {
        return readingTimeStdDevMs;
    }

    public void setReadingTimeStdDevMs(int readingTimeStdDevMs) {
        this.readingTimeStdDevMs = readingTimeStdDevMs;
    }

    public float getScrollProbability() {
        return scrollProbability;
    }

    public void setScrollProbability(float scrollProbability) {
        this.scrollProbability = scrollProbability;
    }
}