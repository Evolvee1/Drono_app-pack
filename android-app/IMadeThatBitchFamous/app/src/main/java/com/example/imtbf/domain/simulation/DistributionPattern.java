package com.example.imtbf.domain.simulation;

/**
 * Enum representing different traffic distribution patterns.
 */
public enum DistributionPattern {
    /**
     * Distributes traffic evenly throughout the time period.
     */
    EVEN("Even Distribution"),

    /**
     * Concentrates more traffic during configured peak hours.
     */
    PEAK_HOURS("Peak Hours"),

    /**
     * Randomizes traffic but maintains the overall volume.
     */
    RANDOM("Random Distribution"),

    /**
     * Creates clusters of traffic with quiet periods in between.
     */
    BURST("Burst Mode");

    private final String displayName;

    DistributionPattern(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }

    /**
     * Get pattern from string representation.
     * @param patternName Pattern name
     * @return DistributionPattern or EVEN if not found
     */
    public static DistributionPattern fromString(String patternName) {
        try {
            return valueOf(patternName);
        } catch (IllegalArgumentException e) {
            return EVEN; // Default to EVEN if pattern not found
        }
    }
}