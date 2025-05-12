package com.example.imtbf2.domain.simulation;

import android.content.Context;

import com.example.imtbf2.data.models.DeviceProfile;
import com.example.imtbf2.data.models.SimulationSession;
import com.example.imtbf2.data.models.UserAgentData;
import com.example.imtbf2.data.network.HttpRequestManager;
import com.example.imtbf2.data.network.WebViewRequestManager;
import com.example.imtbf2.data.network.NetworkStateMonitor;
import com.example.imtbf2.domain.system.AirplaneModeController;
import com.example.imtbf2.utils.Logger;
import com.example.imtbf2.InstagramTrafficSimulatorApp;

import android.content.Context;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

/**
 * Manages simulation sessions.
 * This class is responsible for orchestrating the various components involved in a simulation.
 */
public class SessionManager {

    private static final String TAG = "SessionManager";

    private final Context context;
    private final NetworkStateMonitor networkStateMonitor;
    private final HttpRequestManager httpRequestManager;
    private final WebViewRequestManager webViewRequestManager;
    private final AirplaneModeController airplaneModeController;
    private final BehaviorEngine behaviorEngine;
    private final TimingDistributor timingDistributor;
    private final Set<String> usedIpAddresses = new HashSet<>();

    private SimulationSession currentSession;
    private boolean isRunning = false;
    private boolean isPaused = false;
    private ProgressListener progressListener;
    private long lastRequestTime = 0;
    private int currentIteration = 0;
    private int totalIterations = 0;

    // For scheduled requests
    private boolean scheduledRequestInProgress = false;
    private String scheduledTargetUrl = null;
    private DeviceProfile scheduledDeviceProfile = null;

    /**
     * Constructor that initializes the session manager with required dependencies.
     * @param context Application context
     * @param networkStateMonitor Network state monitor
     * @param httpRequestManager HTTP request manager
     * @param webViewRequestManager WebView request manager
     * @param airplaneModeController Airplane mode controller
     * @param behaviorEngine Behavior engine
     * @param timingDistributor Timing distributor
     */
    public SessionManager(
            Context context,
            NetworkStateMonitor networkStateMonitor,
            HttpRequestManager httpRequestManager,
            WebViewRequestManager webViewRequestManager,
            AirplaneModeController airplaneModeController,
            BehaviorEngine behaviorEngine,
            TimingDistributor timingDistributor) {
        this.context = context;
        this.networkStateMonitor = networkStateMonitor;
        this.httpRequestManager = httpRequestManager;
        this.webViewRequestManager = webViewRequestManager;
        this.airplaneModeController = airplaneModeController;
        this.behaviorEngine = behaviorEngine;
        this.timingDistributor = timingDistributor;
    }

    /**
     * Progress listener interface
     */
    public interface ProgressListener {
        void onProgressUpdated(int current, int total);
    }

    /**
     * Set a progress listener
     * @param listener Progress listener
     */
    public void setProgressListener(ProgressListener listener) {
        this.progressListener = listener;
    }

    /**
     * Make a request using either HTTP or WebView and wait for the result.
     * @param url Target URL
     * @param deviceProfile Device profile
     * @param session Current session
     * @param useWebView Whether to use WebView for the request
     */
    private boolean makeRequestAndWait(
            String url,
            DeviceProfile deviceProfile,
            SimulationSession session,
            boolean useWebView) {

        CompletableFuture<Boolean> requestFuture = new CompletableFuture<>();
        long currentTime = System.currentTimeMillis();
        String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();

        Logger.d(TAG, "Making " + (useWebView ? "WebView" : "HTTP") + " request to " + url);

        // Add logging for timing between requests
        if (lastRequestTime > 0) {
            long timeSinceLastRequest = currentTime - lastRequestTime;
            Logger.i(TAG, "Time since last request: " + timeSinceLastRequest + "ms");
        }
        lastRequestTime = currentTime;

        if (useWebView && webViewRequestManager != null) {
            // Create WebView-specific callback
            WebViewRequestManager.RequestCallback webViewCallback = new WebViewRequestManager.RequestCallback() {
                @Override
                public void onSuccess(int statusCode, long responseTimeMs) {
                    Logger.i(TAG, "WebView request successful: " + statusCode + " in " + responseTimeMs + "ms");
                    requestFuture.complete(true);
                }

                @Override
                public void onError(String error) {
                    Logger.e(TAG, "WebView request failed: " + error);
                    requestFuture.complete(false);
                }
            };

            webViewRequestManager.makeRequest(url, deviceProfile, session, webViewCallback);
        } else {
            // HTTP request handling (keep your existing code)
            HttpRequestManager.RequestCallback httpCallback = new HttpRequestManager.RequestCallback() {
                @Override
                public void onSuccess(int statusCode, long responseTimeMs) {
                    Logger.i(TAG, "HTTP request successful: " + statusCode + " in " + responseTimeMs + "ms");
                    requestFuture.complete(true);
                }

                @Override
                public void onError(String error) {
                    Logger.e(TAG, "HTTP request failed: " + error);
                    requestFuture.complete(false);
                }
            };

            httpRequestManager.makeRequest(url, deviceProfile, session, httpCallback);
        }

        try {
            // Wait for the request to complete with a timeout
            return requestFuture.get(120, TimeUnit.SECONDS); // Longer timeout for behavior simulation
        } catch (Exception e) {
            Logger.e(TAG, "Error waiting for request", e);
            return false;
        }
    }

    /**
     * Start a new simulation session with WebView support.
     * @param targetUrl Target URL
     * @param iterations Number of iterations
     * @param useRandomDeviceProfile Whether to use random device profiles
     * @param rotateIp Whether to rotate IP addresses
     * @param delayMin Minimum delay between iterations in seconds
     * @param delayMax Maximum delay between iterations in seconds
     * @param useWebView Whether to use WebView for requests
     * @return CompletableFuture that completes when the session is started
     */
    public CompletableFuture<Void> startSession(
            String targetUrl,
            int iterations,
            boolean useRandomDeviceProfile,
            boolean rotateIp,
            int delayMin,
            int delayMax,
            boolean useWebView) {

        if (isRunning) {
            Logger.w(TAG, "Session already running");
            return CompletableFuture.completedFuture(null);
        }

        isRunning = true;
        isPaused = false;
        usedIpAddresses.clear();
        
        // Store iteration values for persistence
        currentIteration = 0;
        totalIterations = iterations;

        // Update timing distributor with custom delay values
        timingDistributor.setMinIntervalSeconds(delayMin);
        timingDistributor.setMaxIntervalSeconds(delayMax);

        Logger.i(TAG, "Using custom timing: min=" + delayMin + "s, max=" + delayMax + "s");
        Logger.i(TAG, "Using " + (useWebView ? "WebView" : "HTTP") + " mode");

        // Create initial device profile
        DeviceProfile initialDeviceProfile = useRandomDeviceProfile ?
                UserAgentData.getSlovakDemographicProfile() :
                new DeviceProfile.Builder()
                        .deviceType(DeviceProfile.TYPE_MOBILE)
                        .platform(DeviceProfile.PLATFORM_ANDROID)
                        .deviceTier(DeviceProfile.TIER_MID_RANGE)
                        .userAgent(UserAgentData.getRandomUserAgent())
                        .region("slovakia")
                        .build();

        // Create a new session
        currentSession = new SimulationSession(targetUrl, initialDeviceProfile);

        // Start the session loop
        return CompletableFuture.runAsync(() -> {
            try {
                // Initial IP check
                String initialIp = networkStateMonitor.getCurrentIpAddress().getValue();
                if (initialIp != null && !initialIp.isEmpty()) {
                    currentSession.recordIpChange(initialIp);
                    usedIpAddresses.add(initialIp);
                }

                Logger.i(TAG, "Starting simulation session: " +
                        iterations + " iterations, target: " + targetUrl);

                // Run iterations
                for (int i = 0; i < iterations && isRunning; i++) {
                    int currentIterationIndex = i + 1;
                    Logger.i(TAG, "Starting iteration " + currentIterationIndex + "/" + iterations);

                    // Skip execution if paused
                    while (isPaused && isRunning) {
                        Thread.sleep(500);
                    }
                    
                    // Exit if stopped
                    if (!isRunning) {
                        break;
                    }

                    // Rotate IP if requested and not the first iteration, or if IP already used
                    if (rotateIp && (i > 0 || usedIpAddresses.contains(initialIp))) {
                        if (usedIpAddresses.contains(initialIp)) {
                            Logger.i(TAG, "IP address already used, forcing rotation");
                        }
                        rotateIpAndWait();
                    }

                    // Final device profile for this iteration
                    final DeviceProfile deviceProfile = useRandomDeviceProfile ?
                            UserAgentData.getSlovakDemographicProfile() :
                            initialDeviceProfile;

                    Logger.d(TAG, "Using device profile: " +
                            deviceProfile.getPlatform() + ", " +
                            deviceProfile.getDeviceType() + ", " +
                            deviceProfile.getDeviceTier());

                    // Make the request - passing the WebView mode parameter
                    boolean requestSucceeded = makeRequestAndWait(targetUrl, deviceProfile, currentSession, useWebView);
                    
                    // Only increment progress if the request was successful
                    if (requestSucceeded) {
                        // Update progress counter
                        currentIteration = currentIterationIndex;
                        
                        // Notify of progress update 
                        notifyProgress(currentIteration, totalIterations);
                        
                        // Track IP used
                        String newIp = networkStateMonitor.getCurrentIpAddress().getValue();
                        if (newIp != null && !newIp.isEmpty() && !newIp.equals("Unknown")) {
                            usedIpAddresses.add(newIp);
                        }
                        
                        // Simulate human behavior
                        behaviorEngine.simulateSession(deviceProfile, 50).get(); // 50 = medium content length
                    } else {
                        Logger.w(TAG, "Request failed, not incrementing progress counter");
                        // Retry the same iteration 
                        i--;
                    }

                    // Wait for the next iteration if not the last one
                    if (isRunning && i < iterations - 1 && !isPaused) {
                        int intervalSeconds = timingDistributor.getHumanLikeIntervalSeconds();
                        Logger.d(TAG, "Waiting " + intervalSeconds +
                                " seconds before next iteration");

                        // Sleep with periodic checks to allow cancellation
                        for (int j = 0; j < intervalSeconds && isRunning && !isPaused; j++) {
                            Thread.sleep(1000); // 1 second
                        }
                    }
                }

                // Complete the session
                if (currentSession != null) {
                    currentSession.completeSession();

                    Logger.i(TAG, "Session completed: " +
                            currentSession.getTotalRequests() + " requests, " +
                            currentSession.getSuccessRate() + "% success rate, " +
                            currentSession.getIpRotationCount() + " IP rotations, " +
                            TimeUnit.MILLISECONDS.toSeconds(currentSession.getDurationMs()) +
                            " seconds duration");
                }

            } catch (Exception e) {
                Logger.e(TAG, "Error in simulation session", e);
            } finally {
                isRunning = false;
            }
        });
    }

    /**
     * Start a new simulation session with custom delay settings (backward compatibility).
     * @param targetUrl Target URL
     * @param iterations Number of iterations
     * @param useRandomDeviceProfile Whether to use random device profiles
     * @param rotateIp Whether to rotate IP addresses
     * @param delayMin Minimum delay between iterations in seconds
     * @param delayMax Maximum delay between iterations in seconds
     * @return CompletableFuture that completes when the session is started
     */
    public CompletableFuture<Void> startSession(
            String targetUrl,
            int iterations,
            boolean useRandomDeviceProfile,
            boolean rotateIp,
            int delayMin,
            int delayMax) {

        // Default to HTTP mode
        return startSession(targetUrl, iterations, useRandomDeviceProfile, rotateIp, delayMin, delayMax, false);
    }

    /**
     * Stop the current session.
     */
    public void stopSession() {
        if (!isRunning) {
            return;
        }

        Logger.i(TAG, "Stopping session");
        isRunning = false;
        isPaused = false;

        // Reset session persistence state
        if (context instanceof Context) {
            InstagramTrafficSimulatorApp app = (InstagramTrafficSimulatorApp) context.getApplicationContext();
            app.getPreferencesManager().clearSavedSessionState();
        }

        if (currentSession != null) {
            currentSession.completeSession();
        }
    }

    /**
     * Rotate the IP address and wait for the change to complete.
     */
    private void rotateIpAndWait() {
        try {
            Logger.d(TAG, "Rotating IP address");

            // Get current IP before rotation
            String beforeIp = networkStateMonitor.getCurrentIpAddress().getValue();
            if (beforeIp != null) {
                Logger.i(TAG, "Current IP before rotation: " + beforeIp);
            } else {
                Logger.w(TAG, "Unable to determine current IP before rotation");
            }

            // Ensure the airplane mode controller is initialized
            if (airplaneModeController == null) {
                Logger.e(TAG, "AirplaneModeController is null, cannot rotate IP");
                return;
            }
            
            // Explicitly ensure airplane mode is properly configured
            if (context instanceof Context) {
                int delay = ((InstagramTrafficSimulatorApp)((Context)context).getApplicationContext())
                    .getPreferencesManager().getAirplaneModeDelay();
                airplaneModeController.setAirplaneModeDelay(delay);
                Logger.i(TAG, "Updated airplane mode delay to: " + delay + "ms");
            }

            // Rotate IP and wait for completion
            Logger.i(TAG, "Initiating IP rotation via airplane mode toggle...");
            AirplaneModeController.IpRotationResult result =
                    airplaneModeController.rotateIp().get();

            if (result.isSuccess()) {
                Logger.i(TAG, "IP rotation successful: " +
                        result.getPreviousIp() + " -> " + result.getNewIp());

                // Record the IP change in the session
                if (currentSession != null) {
                    currentSession.recordIpChange(result.getNewIp());
                    Logger.i(TAG, "IP change recorded in session, rotation count: " + 
                           currentSession.getIpRotationCount());
                }

                // Add to used IPs
                if (result.getNewIp() != null && !result.getNewIp().isEmpty()) {
                    usedIpAddresses.add(result.getNewIp());
                    Logger.i(TAG, "Added IP to used IPs list: " + result.getNewIp());
                }

            } else {
                Logger.w(TAG, "IP rotation failed: " + result.getMessage());
                
                // Force a refresh of IP address
                networkStateMonitor.fetchCurrentIpAddress();
                
                // Wait briefly for network to stabilize
                Thread.sleep(2000);
                
                // Get current IP anyway
                String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();
                if (currentIp != null && !currentIp.isEmpty()) {
                    Logger.i(TAG, "Current IP after failed rotation attempt: " + currentIp);
                    
                    // Record it in session
                    if (currentSession != null) {
                        currentSession.recordIpChange(currentIp);
                    }
                    
                    usedIpAddresses.add(currentIp);
                }
            }

        } catch (Exception e) {
            Logger.e(TAG, "Error rotating IP", e);
            
            // Try to recover by getting the current IP
            try {
                networkStateMonitor.fetchCurrentIpAddress();
                Thread.sleep(2000);
                String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();
                if (currentIp != null && !currentIp.isEmpty()) {
                    Logger.i(TAG, "Current IP after error: " + currentIp);
                }
            } catch (Exception ex) {
                Logger.e(TAG, "Error recovering from IP rotation failure", ex);
            }
        }
    }

    /**
     * Check if a session is currently running.
     * @return True if a session is running, false otherwise
     */
    public boolean isRunning() {
        return isRunning;
    }

    /**
     * Get the current session.
     * @return Current session or null if no session is running
     */
    public SimulationSession getCurrentSession() {
        return currentSession;
    }

    /**
     * Execute a single scheduled request.
     * This is called by the TrafficDistributionManager when using scheduled distribution.
     * @return True if request was initiated successfully
     */
    /**
     * Execute a single scheduled request.
     * This is called by the TrafficDistributionManager when using scheduled distribution.
     * @return True if request was initiated successfully
     */
    public boolean executeScheduledRequest() {
        if (scheduledRequestInProgress || !isRunning()) {
            Logger.w(TAG, "Cannot execute scheduled request: " +
                    (scheduledRequestInProgress ? "Another request in progress" : "Session not running"));
            return false;
        }

        scheduledRequestInProgress = true;

        try {
            // Use the saved target URL and device profile
            String targetUrl = scheduledTargetUrl != null ?
                    scheduledTargetUrl : getCurrentSession().getTargetUrl();

            DeviceProfile deviceProfile = scheduledDeviceProfile != null ?
                    scheduledDeviceProfile : getCurrentSession().getDeviceProfile();

            // Make a request using the same parameters as the session
            boolean useRandomDeviceProfile = deviceProfile == null;

            if (useRandomDeviceProfile) {
                deviceProfile = UserAgentData.getSlovakDemographicProfile();
            }

            // Get current IP
            String currentIp = networkStateMonitor.getCurrentIpAddress().getValue();

            // Make the actual request
            boolean useWebView = webViewRequestManager != null &&
                    (context instanceof Context &&
                            ((InstagramTrafficSimulatorApp)((Context)context).getApplicationContext())
                                    .getPreferencesManager().getUseWebViewMode());

            if (useWebView && webViewRequestManager != null) {
                webViewRequestManager.makeRequest(targetUrl, deviceProfile, currentSession,
                        new WebViewRequestManager.RequestCallback() {
                            @Override
                            public void onSuccess(int statusCode, long responseTimeMs) {
                                Logger.i(TAG, "Scheduled WebView request successful: " +
                                        statusCode + " in " + responseTimeMs + "ms");
                                scheduledRequestInProgress = false;
                            }

                            @Override
                            public void onError(String error) {
                                Logger.e(TAG, "Scheduled WebView request failed: " + error);
                                scheduledRequestInProgress = false;
                            }
                        });
            } else {
                // Fallback to HTTP request
                httpRequestManager.makeRequest(targetUrl, deviceProfile, currentSession,
                        new HttpRequestManager.RequestCallback() {
                            @Override
                            public void onSuccess(int statusCode, long responseTimeMs) {
                                Logger.i(TAG, "Scheduled HTTP request successful: " +
                                        statusCode + " in " + responseTimeMs + "ms");
                                scheduledRequestInProgress = false;
                            }

                            @Override
                            public void onError(String error) {
                                Logger.e(TAG, "Scheduled HTTP request failed: " + error);
                                scheduledRequestInProgress = false;
                            }
                        });
            }

            return true;
        } catch (Exception e) {
            Logger.e(TAG, "Error executing scheduled request: " + e.getMessage());
            scheduledRequestInProgress = false;
            return false;
        }
    }

    /**
     * Configure parameters for scheduled requests.
     * @param targetUrl Target URL for scheduled requests
     * @param deviceProfile Device profile for scheduled requests
     */
    public void configureScheduledRequests(String targetUrl, DeviceProfile deviceProfile) {
        this.scheduledTargetUrl = targetUrl;
        this.scheduledDeviceProfile = deviceProfile;
        Logger.d(TAG, "Configured scheduled requests: URL=" + targetUrl);
    }

    /**
     * Check if the session is currently paused.
     * @return True if paused, false otherwise
     */
    public boolean isPaused() {
        return isPaused;
    }

    /**
     * Pause the current session.
     * @return True if session was paused, false if it was not running
     */
    public boolean pauseSession() {
        if (!isRunning || isPaused) {
            Logger.w(TAG, "Cannot pause: session not running or already paused");
            return false;
        }

        Logger.i(TAG, "Pausing session");
        isPaused = true;

        // Store current state for persistence
        if (context instanceof Context) {
            InstagramTrafficSimulatorApp app = (InstagramTrafficSimulatorApp) context.getApplicationContext();
            app.getPreferencesManager().saveSessionState(
                    currentIteration, 
                    totalIterations, 
                    isPaused, 
                    currentSession != null ? currentSession.getStartTimeMs() : 0
            );
        }

        return true;
    }

    /**
     * Resume a paused session.
     * @return True if session was resumed, false if it was not paused
     */
    public boolean resumeSession() {
        if (!isRunning || !isPaused) {
            Logger.w(TAG, "Cannot resume: session not running or not paused");
            return false;
        }

        Logger.i(TAG, "Resuming session");
        isPaused = false;

        // Update session state
        if (context instanceof Context) {
            InstagramTrafficSimulatorApp app = (InstagramTrafficSimulatorApp) context.getApplicationContext();
            app.getPreferencesManager().saveSessionState(
                    currentIteration, 
                    totalIterations, 
                    isPaused, 
                    currentSession != null ? currentSession.getStartTimeMs() : 0
            );
        }
        
        // Clear any previously used IPs (to ensure rotation)
        // when resuming we want to always rotate IPs
        usedIpAddresses.clear();
        
        // Force IP rotation on first resumed request
        final boolean shouldRotateIp = true;
        
        // Actually continue the execution where we left off
        CompletableFuture.runAsync(() -> {
            try {
                // Continue from where we left off - currentIteration is the last COMPLETED iteration
                // so we continue from currentIteration + 1
                int remainingIterations = totalIterations - currentIteration;
                Logger.i(TAG, "Continuing execution with " + remainingIterations + " remaining iterations");
                
                // Get input values from current session
                String targetUrl = currentSession.getTargetUrl();
                
                // Continue simulation from current position (we've already completed currentIteration iterations)
                for (int i = currentIteration; i < totalIterations && isRunning; i++) {
                    // Skip if session is paused, keep checking until resumed or stopped
                    while (isPaused && isRunning) {
                        Thread.sleep(500);
                    }
                    
                    // Exit if session was stopped
                    if (!isRunning) {
                        break;
                    }
                    
                    // Current iteration is the one we're about to execute (i+1)
                    int iterationNumber = i + 1;
                    Logger.i(TAG, "Resuming iteration " + iterationNumber + "/" + totalIterations);
                    
                    // Always rotate IP on first iteration after resume, then follow normal rules
                    if (shouldRotateIp || i > currentIteration) {
                        Logger.i(TAG, "Rotating IP as part of resumed session");
                        rotateIpAndWait();
                    }
                    
                    // Determine device profile based on current session
                    DeviceProfile deviceProfile = currentSession.getDeviceProfile();
                    boolean useRandomDeviceProfile = deviceProfile == null;
                    if (useRandomDeviceProfile) {
                        deviceProfile = UserAgentData.getSlovakDemographicProfile();
                        Logger.i(TAG, "Using random device profile for resumed request");
                    } else {
                        Logger.i(TAG, "Using existing device profile for resumed request");
                    }
                    
                    // Determine if we should use WebView
                    boolean useWebView = context instanceof Context &&
                        ((InstagramTrafficSimulatorApp)context.getApplicationContext())
                            .getPreferencesManager().getUseWebViewMode();
                    
                    Logger.i(TAG, "Making resumed request to: " + targetUrl + 
                            " using " + (useWebView ? "WebView" : "HTTP"));
                    
                    // Make the request and only increment progress if successful
                    boolean requestSucceeded = false;
                    try {
                        // Make the request
                        CompletableFuture<Boolean> requestFuture = new CompletableFuture<>();
                        
                        if (useWebView && webViewRequestManager != null) {
                            webViewRequestManager.makeRequest(targetUrl, deviceProfile, currentSession,
                                new WebViewRequestManager.RequestCallback() {
                                    @Override
                                    public void onSuccess(int statusCode, long responseTimeMs) {
                                        Logger.i(TAG, "WebView request successful: " + statusCode + " in " + responseTimeMs + "ms");
                                        requestFuture.complete(true);
                                    }
                                    
                                    @Override
                                    public void onError(String error) {
                                        Logger.e(TAG, "WebView request failed: " + error);
                                        requestFuture.complete(false);
                                    }
                                });
                        } else {
                            httpRequestManager.makeRequest(targetUrl, deviceProfile, currentSession,
                                new HttpRequestManager.RequestCallback() {
                                    @Override
                                    public void onSuccess(int statusCode, long responseTimeMs) {
                                        Logger.i(TAG, "HTTP request successful: " + statusCode + " in " + responseTimeMs + "ms");
                                        requestFuture.complete(true);
                                    }
                                    
                                    @Override
                                    public void onError(String error) {
                                        Logger.e(TAG, "HTTP request failed: " + error);
                                        requestFuture.complete(false);
                                    }
                                });
                        }
                        
                        // Wait for the request to complete
                        requestSucceeded = requestFuture.get(60, TimeUnit.SECONDS);
                    } catch (Exception e) {
                        Logger.e(TAG, "Error during request execution", e);
                        requestSucceeded = false;
                    }
                    
                    // Only update progress if the request succeeded
                    if (requestSucceeded) {
                        // Update progress counter
                        currentIteration = iterationNumber;
                        
                        // Notify of progress update
                        notifyProgress(currentIteration, totalIterations);
                        
                        // Track IP used
                        String newIp = networkStateMonitor.getCurrentIpAddress().getValue();
                        if (newIp != null && !newIp.isEmpty() && !newIp.equals("Unknown")) {
                            Logger.i(TAG, "Tracking IP used in resumed session: " + newIp);
                            usedIpAddresses.add(newIp);
                        }
                        
                        // Simulate human behavior
                        Logger.i(TAG, "Simulating human behavior in resumed session");
                        behaviorEngine.simulateSession(deviceProfile, 50).get(); // 50 = medium content length
                    } else {
                        Logger.w(TAG, "Request failed, not incrementing progress counter");
                        // Retry the same iteration
                        i--;
                    }
                    
                    // Wait for the next iteration if not the last one
                    if (isRunning && i < totalIterations - 1 && !isPaused) {
                        int intervalSeconds = timingDistributor.getHumanLikeIntervalSeconds();
                        Logger.i(TAG, "Waiting " + intervalSeconds + " seconds before next resumed iteration");
                        
                        // Sleep with periodic checks to allow cancellation or pausing
                        for (int j = 0; j < intervalSeconds && isRunning && !isPaused; j++) {
                            Thread.sleep(1000); // 1 second
                        }
                    }
                }
                
                // Complete the session if all iterations are done
                if (isRunning && currentIteration >= totalIterations && currentSession != null) {
                    currentSession.completeSession();
                    
                    Logger.i(TAG, "Session completed: " +
                            currentSession.getTotalRequests() + " requests, " +
                            currentSession.getSuccessRate() + "% success rate, " +
                            currentSession.getIpRotationCount() + " IP rotations, " +
                            TimeUnit.MILLISECONDS.toSeconds(currentSession.getDurationMs()) +
                            " seconds duration");
                }
                
            } catch (Exception e) {
                Logger.e(TAG, "Error in resumed session execution", e);
            }
        });

        return true;
    }

    /**
     * Restore session from saved state.
     * @return True if session was restored successfully
     */
    public boolean restoreSession() {
        if (isRunning) {
            Logger.w(TAG, "Cannot restore: session already running");
            return false;
        }

        if (!(context instanceof Context)) {
            Logger.e(TAG, "Cannot restore: invalid context");
            return false;
        }

        InstagramTrafficSimulatorApp app = (InstagramTrafficSimulatorApp) context.getApplicationContext();
        if (!app.getPreferencesManager().hasSavedSessionState()) {
            Logger.w(TAG, "Cannot restore: no saved session state");
            return false;
        }

        try {
            // Restore session state
            // IMPORTANT: currentIteration should be the COMPLETED iterations, not the next one to run
            currentIteration = app.getPreferencesManager().getSavedCurrentIndex();
            totalIterations = app.getPreferencesManager().getSavedTotalRequests();
            isPaused = app.getPreferencesManager().wasSavedSessionPaused();
            long startTime = app.getPreferencesManager().getSavedSessionStartTime();
    
            Logger.i(TAG, "Restoring session: progress=" + currentIteration + "/" + totalIterations +
                    ", paused=" + isPaused + ", startTime=" + startTime);
    
            // Create a new session with the restored state
            String targetUrl = app.getPreferencesManager().getTargetUrl();
            DeviceProfile deviceProfile = new DeviceProfile.Builder()
                    .deviceType(DeviceProfile.TYPE_MOBILE)
                    .platform(DeviceProfile.PLATFORM_ANDROID)
                    .deviceTier(DeviceProfile.TIER_MID_RANGE)
                    .userAgent(UserAgentData.getRandomUserAgent())
                    .region("slovakia")
                    .build();
                    
            currentSession = new SimulationSession(targetUrl, deviceProfile);
            currentSession.setStartTimeMs(startTime > 0 ? startTime : System.currentTimeMillis());
            
            // Initialize timing distributor
            timingDistributor.setMinIntervalSeconds(app.getPreferencesManager().getMinInterval());
            timingDistributor.setMaxIntervalSeconds(app.getPreferencesManager().getMaxInterval());
            
            // Reset IP address set
            usedIpAddresses.clear();
            
            isRunning = true;
            
            // Notify progress (current progress is the completed iterations)
            notifyProgress(currentIteration, totalIterations);
            
            return true;
        } catch (Exception e) {
            Logger.e(TAG, "Error restoring session: " + e.getMessage());
            return false;
        }
    }

    /**
     * Notify the progress listener of current progress.
     * @param current Current progress
     * @param total Total progress
     */
    private void notifyProgress(int current, int total) {
        if (progressListener != null) {
            progressListener.onProgressUpdated(current, total);
        }
    }
}