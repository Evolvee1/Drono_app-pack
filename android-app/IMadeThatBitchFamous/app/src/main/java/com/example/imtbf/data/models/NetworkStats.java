package com.example.imtbf.data.models;

/**
 * Represents network statistics for upload and download data.
 */
public class NetworkStats {
    private long bytesUploaded;
    private long bytesDownloaded;
    private float uploadSpeed; // Bytes per second
    private float downloadSpeed; // Bytes per second
    private long timestamp;

    public NetworkStats() {
        this.bytesUploaded = 0;
        this.bytesDownloaded = 0;
        this.uploadSpeed = 0;
        this.downloadSpeed = 0;
        this.timestamp = System.currentTimeMillis();
    }

    public NetworkStats(long bytesUploaded, long bytesDownloaded, float uploadSpeed, float downloadSpeed) {
        this.bytesUploaded = bytesUploaded;
        this.bytesDownloaded = bytesDownloaded;
        this.uploadSpeed = uploadSpeed;
        this.downloadSpeed = downloadSpeed;
        this.timestamp = System.currentTimeMillis();
    }

    // Getters and setters
    public long getBytesUploaded() {
        return bytesUploaded;
    }

    public void setBytesUploaded(long bytesUploaded) {
        this.bytesUploaded = bytesUploaded;
    }

    public long getBytesDownloaded() {
        return bytesDownloaded;
    }

    public void setBytesDownloaded(long bytesDownloaded) {
        this.bytesDownloaded = bytesDownloaded;
    }

    public float getUploadSpeed() {
        return uploadSpeed;
    }

    public void setUploadSpeed(float uploadSpeed) {
        this.uploadSpeed = uploadSpeed;
    }

    public float getDownloadSpeed() {
        return downloadSpeed;
    }

    public void setDownloadSpeed(float downloadSpeed) {
        this.downloadSpeed = downloadSpeed;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public long getTotalBytes() {
        return bytesUploaded + bytesDownloaded;
    }

    public float getTotalSpeed() {
        return uploadSpeed + downloadSpeed;
    }
}