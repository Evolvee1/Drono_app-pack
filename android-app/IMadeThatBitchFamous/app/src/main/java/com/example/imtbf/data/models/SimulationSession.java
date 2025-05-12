package com.example.imtbf.data.models;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Represents a single simulation session.
 * Contains information about the session such as start time, end time,
 * number of requests, success rate, etc.
 */
public class SimulationSession {

    private String sessionId;
    private long startTime;
    private long endTime;
    private int totalRequests;
    private int successfulRequests;
    private String targetUrl;
    private DeviceProfile deviceProfile;
    private List<RequestResult> requestResults;
    private boolean isCompleted;
    private int ipRotationCount;
    private String initialIpAddress;
    private String finalIpAddress;
    private List<String> ipAddresses;

    /**
     * Default constructor that initializes a new session.
     */
    public SimulationSession() {
        this.sessionId = UUID.randomUUID().toString();
        this.startTime = System.currentTimeMillis();
        this.totalRequests = 0;
        this.successfulRequests = 0;
        this.requestResults = new ArrayList<>();
        this.isCompleted = false;
        this.ipRotationCount = 0;
        this.ipAddresses = new ArrayList<>();
    }

    /**
     * Constructor with target URL and device profile.
     */
    public SimulationSession(String targetUrl, DeviceProfile deviceProfile) {
        this();
        this.targetUrl = targetUrl;
        this.deviceProfile = deviceProfile;
    }

    /**
     * Add a request result to this session.
     * @param result Request result
     */
    public void addRequestResult(RequestResult result) {
        requestResults.add(result);
        totalRequests++;
        if (result.isSuccessful()) {
            successfulRequests++;
        }
    }

    /**
     * Record an IP address change.
     * @param newIpAddress New IP address
     */
    public void recordIpChange(String newIpAddress) {
        if (ipAddresses.isEmpty()) {
            initialIpAddress = newIpAddress;
        }

        if (!ipAddresses.contains(newIpAddress)) {
            ipAddresses.add(newIpAddress);
            ipRotationCount++;
        }

        finalIpAddress = newIpAddress;
    }

    /**
     * Complete the session and record the end time.
     */
    public void completeSession() {
        this.endTime = System.currentTimeMillis();
        this.isCompleted = true;
    }

    /**
     * Get the success rate as a percentage.
     * @return Success rate (0-100)
     */
    public float getSuccessRate() {
        if (totalRequests == 0) {
            return 0;
        }
        return (float) successfulRequests / totalRequests * 100;
    }

    /**
     * Get the session duration in milliseconds.
     * @return Session duration
     */
    public long getDurationMs() {
        if (endTime == 0) {
            return System.currentTimeMillis() - startTime;
        }
        return endTime - startTime;
    }

    /**
     * Get the session ID.
     * @return Session ID
     */
    public String getSessionId() {
        return sessionId;
    }

    /**
     * Get the start time.
     * @return Start time
     */
    public long getStartTime() {
        return startTime;
    }

    /**
     * Get the start time in milliseconds (alias for getStartTime for better code readability).
     * @return Start time in milliseconds
     */
    public long getStartTimeMs() {
        return startTime;
    }

    /**
     * Set the start time in milliseconds.
     * @param startTimeMs Start time in milliseconds
     */
    public void setStartTimeMs(long startTimeMs) {
        this.startTime = startTimeMs;
    }

    /**
     * Get the end time.
     * @return End time
     */
    public long getEndTime() {
        return endTime;
    }

    /**
     * Get the total number of requests.
     * @return Total requests
     */
    public int getTotalRequests() {
        return totalRequests;
    }

    /**
     * Get the number of successful requests.
     * @return Successful requests
     */
    public int getSuccessfulRequests() {
        return successfulRequests;
    }

    /**
     * Get the target URL.
     * @return Target URL
     */
    public String getTargetUrl() {
        return targetUrl;
    }

    /**
     * Set the target URL.
     * @param targetUrl Target URL
     */
    public void setTargetUrl(String targetUrl) {
        this.targetUrl = targetUrl;
    }

    /**
     * Get the device profile.
     * @return Device profile
     */
    public DeviceProfile getDeviceProfile() {
        return deviceProfile;
    }

    /**
     * Set the device profile.
     * @param deviceProfile Device profile
     */
    public void setDeviceProfile(DeviceProfile deviceProfile) {
        this.deviceProfile = deviceProfile;
    }

    /**
     * Get the request results.
     * @return List of request results
     */
    public List<RequestResult> getRequestResults() {
        return requestResults;
    }

    /**
     * Check if the session is completed.
     * @return True if the session is completed, false otherwise
     */
    public boolean isCompleted() {
        return isCompleted;
    }

    /**
     * Get the IP rotation count.
     * @return IP rotation count
     */
    public int getIpRotationCount() {
        return ipRotationCount;
    }

    /**
     * Get the initial IP address.
     * @return Initial IP address
     */
    public String getInitialIpAddress() {
        return initialIpAddress;
    }

    /**
     * Get the final IP address.
     * @return Final IP address
     */
    public String getFinalIpAddress() {
        return finalIpAddress;
    }

    /**
     * Get all IP addresses used in this session.
     * @return List of IP addresses
     */
    public List<String> getIpAddresses() {
        return ipAddresses;
    }

    /**
     * Request result class.
     * Represents the result of a single HTTP request.
     */
    public static class RequestResult {
        private final long timestamp;
        private final int httpStatusCode;
        private final boolean isSuccessful;
        private final long responseTimeMs;
        private final String ipAddress;
        private final String errorMessage;

        /**
         * Constructor for a successful request.
         */
        public RequestResult(int httpStatusCode, long responseTimeMs, String ipAddress) {
            this.timestamp = System.currentTimeMillis();
            this.httpStatusCode = httpStatusCode;
            this.isSuccessful = httpStatusCode >= 200 && httpStatusCode < 300;
            this.responseTimeMs = responseTimeMs;
            this.ipAddress = ipAddress;
            this.errorMessage = null;
        }

        /**
         * Constructor for a failed request.
         */
        public RequestResult(String errorMessage, String ipAddress) {
            this.timestamp = System.currentTimeMillis();
            this.httpStatusCode = 0;
            this.isSuccessful = false;
            this.responseTimeMs = 0;
            this.ipAddress = ipAddress;
            this.errorMessage = errorMessage;
        }

        /**
         * Get the timestamp.
         * @return Timestamp
         */
        public long getTimestamp() {
            return timestamp;
        }

        /**
         * Get the HTTP status code.
         * @return HTTP status code
         */
        public int getHttpStatusCode() {
            return httpStatusCode;
        }

        /**
         * Check if the request was successful.
         * @return True if the request was successful, false otherwise
         */
        public boolean isSuccessful() {
            return isSuccessful;
        }

        /**
         * Get the response time in milliseconds.
         * @return Response time
         */
        public long getResponseTimeMs() {
            return responseTimeMs;
        }

        /**
         * Get the IP address.
         * @return IP address
         */
        public String getIpAddress() {
            return ipAddress;
        }

        /**
         * Get the error message.
         * @return Error message or null if the request was successful
         */
        public String getErrorMessage() {
            return errorMessage;
        }
    }
}