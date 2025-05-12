package com.example.imtbf.data.models;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Represents a network monitoring session.
 */
public class NetworkSession {
    private String sessionId;
    private long startTime;
    private long endTime;
    private long totalBytesUploaded;
    private long totalBytesDownloaded;
    private int requestCount;
    private List<NetworkStats> snapshots;
    private boolean isActive;

    /**
     * Create a new network session
     */
    public NetworkSession() {
        this.sessionId = UUID.randomUUID().toString();
        this.startTime = System.currentTimeMillis();
        this.totalBytesUploaded = 0;
        this.totalBytesDownloaded = 0;
        this.requestCount = 0;
        this.snapshots = new ArrayList<>();
        this.isActive = true;
    }

    /**
     * Add bytes to the session counters
     * @param uploadBytes Bytes uploaded
     * @param downloadBytes Bytes downloaded
     */
    public void addBytes(long uploadBytes, long downloadBytes) {
        if (!isActive) return;

        this.totalBytesUploaded += uploadBytes;
        this.totalBytesDownloaded += downloadBytes;
    }

    /**
     * Increment the request counter
     */
    public void incrementRequestCount() {
        if (isActive) {
            this.requestCount++;
        }
    }

    /**
     * Add a snapshot of current network stats
     * @param stats Network stats snapshot
     */
    public void addSnapshot(NetworkStats stats) {
        if (isActive) {
            this.snapshots.add(stats);
        }
    }

    /**
     * End the session
     */
    public void endSession() {
        this.endTime = System.currentTimeMillis();
        this.isActive = false;
    }

    /**
     * Check if the session is active
     * @return True if active, false if ended
     */
    public boolean isActive() {
        return isActive;
    }

    /**
     * Get the session duration in milliseconds
     * @return Duration in milliseconds
     */
    public long getDurationMs() {
        if (endTime == 0) {
            return System.currentTimeMillis() - startTime;
        }
        return endTime - startTime;
    }

    /**
     * Get the average download speed in bytes per second
     * @return Average download speed
     */
    public float getAverageDownloadSpeed() {
        if (snapshots.isEmpty()) return 0;

        float sum = 0;
        for (NetworkStats stats : snapshots) {
            sum += stats.getDownloadSpeed();
        }
        return sum / snapshots.size();
    }

    /**
     * Get the average upload speed in bytes per second
     * @return Average upload speed
     */
    public float getAverageUploadSpeed() {
        if (snapshots.isEmpty()) return 0;

        float sum = 0;
        for (NetworkStats stats : snapshots) {
            sum += stats.getUploadSpeed();
        }
        return sum / snapshots.size();
    }

    // Getters
    public String getSessionId() {
        return sessionId;
    }

    public long getStartTime() {
        return startTime;
    }

    public long getEndTime() {
        return endTime;
    }

    public long getTotalBytesUploaded() {
        return totalBytesUploaded;
    }

    public long getTotalBytesDownloaded() {
        return totalBytesDownloaded;
    }

    public long getTotalBytes() {
        return totalBytesUploaded + totalBytesDownloaded;
    }

    public int getRequestCount() {
        return requestCount;
    }

    public List<NetworkStats> getSnapshots() {
        return new ArrayList<>(snapshots);
    }
}