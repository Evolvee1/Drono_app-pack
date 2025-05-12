package com.example.imtbf.domain.simulation;

import java.util.HashMap;
import java.util.Map;

/**
 * Represents a traffic distribution schedule with parameters for controlling
 * how traffic is spread across a time period.
 */
public class TrafficSchedule {
    private final int totalRequests;
    private final int durationHours;
    private final DistributionPattern pattern;
    private final Map<Integer, Float> hourlyWeights; // Hour (0-23) -> weight

    private int peakHourStart = 9;  // Default 9 AM
    private int peakHourEnd = 17;   // Default 5 PM
    private float peakTrafficWeight = 0.7f; // 70% during peak hours

    /**
     * Create a new traffic schedule.
     * @param totalRequests Total number of requests to distribute
     * @param durationHours Duration in hours for distribution
     * @param pattern Distribution pattern to use
     */
    public TrafficSchedule(int totalRequests, int durationHours, DistributionPattern pattern) {
        this.totalRequests = totalRequests;
        this.durationHours = durationHours;
        this.pattern = pattern;
        this.hourlyWeights = new HashMap<>();

        initializeHourlyWeights();
    }

    /**
     * Initialize hourly weights based on the selected pattern.
     */
    private void initializeHourlyWeights() {
        switch (pattern) {
            case EVEN:
                initializeEvenWeights();
                break;
            case PEAK_HOURS:
                initializePeakHourWeights();
                break;
            case RANDOM:
                initializeRandomWeights();
                break;
            case BURST:
                initializeBurstWeights();
                break;
        }

        // Normalize weights to ensure they sum to 1.0
        normalizeWeights();
    }

    /**
     * Initialize even distribution weights.
     */
    private void initializeEvenWeights() {
        float weight = 1.0f / 24.0f; // Even weight across all hours
        for (int hour = 0; hour < 24; hour++) {
            hourlyWeights.put(hour, weight);
        }
    }

    /**
     * Initialize peak hour distribution weights.
     */
    private void initializePeakHourWeights() {
        int peakHourCount = 0;
        int offPeakHourCount = 0;

        // Count peak and off-peak hours
        for (int hour = 0; hour < 24; hour++) {
            if (isHourInPeakPeriod(hour)) {
                peakHourCount++;
            } else {
                offPeakHourCount++;
            }
        }

        // Calculate weights
        float peakHourTotalWeight = peakTrafficWeight;
        float offPeakHourTotalWeight = 1.0f - peakTrafficWeight;

        float peakHourWeight = peakHourCount > 0 ? peakHourTotalWeight / peakHourCount : 0;
        float offPeakHourWeight = offPeakHourCount > 0 ? offPeakHourTotalWeight / offPeakHourCount : 0;

        // Assign weights
        for (int hour = 0; hour < 24; hour++) {
            if (isHourInPeakPeriod(hour)) {
                hourlyWeights.put(hour, peakHourWeight);
            } else {
                hourlyWeights.put(hour, offPeakHourWeight);
            }
        }
    }

    /**
     * Initialize random distribution weights.
     */
    private void initializeRandomWeights() {
        // Assign random weights
        for (int hour = 0; hour < 24; hour++) {
            hourlyWeights.put(hour, 0.1f + (float)Math.random() * 0.9f);
        }
    }

    /**
     * Initialize burst distribution weights.
     */
    private void initializeBurstWeights() {
        // Create burst periods (3-hour chunks with high traffic)
        int burstCount = 3; // 3 bursts throughout the day
        int burstLength = 3; // 3 hours per burst
        int hoursPerDay = 24;

        // Spacing between bursts
        int spacing = (hoursPerDay - (burstCount * burstLength)) / (burstCount + 1);

        // Initialize all hours to low weight
        for (int hour = 0; hour < 24; hour++) {
            hourlyWeights.put(hour, 0.1f);
        }

        // Set burst hours to high weight
        int currentHour = spacing;
        for (int burst = 0; burst < burstCount; burst++) {
            for (int i = 0; i < burstLength; i++) {
                if (currentHour < 24) {
                    hourlyWeights.put(currentHour, 1.0f);
                    currentHour++;
                }
            }
            currentHour += spacing;
        }
    }

    /**
     * Normalize weights to ensure they sum to 1.0
     */
    private void normalizeWeights() {
        float sum = 0.0f;
        for (float weight : hourlyWeights.values()) {
            sum += weight;
        }

        if (sum > 0.0f) {
            for (int hour : hourlyWeights.keySet()) {
                hourlyWeights.put(hour, hourlyWeights.get(hour) / sum);
            }
        }
    }

    /**
     * Check if an hour is within the peak period.
     * @param hour Hour to check (0-23)
     * @return True if in peak period
     */
    private boolean isHourInPeakPeriod(int hour) {
        if (peakHourStart <= peakHourEnd) {
            // Normal case: e.g., 9 AM to 5 PM
            return hour >= peakHourStart && hour < peakHourEnd;
        } else {
            // Overnight case: e.g., 10 PM to 6 AM
            return hour >= peakHourStart || hour < peakHourEnd;
        }
    }

    /**
     * Calculate intervals between requests to achieve the desired distribution.
     * @return Array of intervals in milliseconds between requests
     */
    public long[] calculateIntervals() {
        long[] intervals = new long[totalRequests - 1];

        // Total milliseconds in the distribution period
        long totalMs = durationHours * 60 * 60 * 1000;

        // For even distribution, all intervals are the same
        if (pattern == DistributionPattern.EVEN) {
            long interval = totalMs / totalRequests;
            for (int i = 0; i < intervals.length; i++) {
                intervals[i] = interval;
            }
            return intervals;
        }

        // For other patterns, calculate based on hourly weights
        double[] cumulativeWeights = new double[totalRequests];
        for (int i = 0; i < totalRequests; i++) {
            cumulativeWeights[i] = (double)i / totalRequests;
        }

        // Convert weights to timestamps
        long[] timestamps = new long[totalRequests];
        for (int i = 0; i < totalRequests; i++) {
            timestamps[i] = (long)(cumulativeWeights[i] * totalMs);
        }

        // Calculate intervals from timestamps
        for (int i = 0; i < intervals.length; i++) {
            intervals[i] = timestamps[i + 1] - timestamps[i];

            // Ensure no zero or negative intervals
            if (intervals[i] <= 0) {
                intervals[i] = 1000; // Minimum 1 second interval
            }
        }

        return intervals;
    }

    /**
     * Get the total number of requests.
     * @return Total requests
     */
    public int getTotalRequests() {
        return totalRequests;
    }

    /**
     * Get the distribution duration in hours.
     * @return Duration in hours
     */
    public int getDurationHours() {
        return durationHours;
    }

    /**
     * Get the distribution pattern.
     * @return Distribution pattern
     */
    public DistributionPattern getPattern() {
        return pattern;
    }

    /**
     * Get the hourly weights.
     * @return Map of hour to weight
     */
    public Map<Integer, Float> getHourlyWeights() {
        return new HashMap<>(hourlyWeights);
    }

    /**
     * Set peak hour configuration.
     * @param startHour Peak period start hour (0-23)
     * @param endHour Peak period end hour (0-23)
     * @param weight Weight of traffic during peak hours (0.0-1.0)
     */
    public void setPeakHourConfig(int startHour, int endHour, float weight) {
        this.peakHourStart = startHour;
        this.peakHourEnd = endHour;
        this.peakTrafficWeight = weight;

        // If using peak hours pattern, recalculate weights
        if (pattern == DistributionPattern.PEAK_HOURS) {
            initializePeakHourWeights();
        }
    }
}