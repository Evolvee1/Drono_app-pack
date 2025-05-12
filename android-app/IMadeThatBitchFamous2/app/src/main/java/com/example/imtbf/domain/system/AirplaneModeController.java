package com.example.imtbf2.domain.system;

import android.content.Context;
import android.os.Looper;

import com.example.imtbf2.data.network.NetworkStateMonitor;
import com.example.imtbf2.utils.Logger;

import java.io.DataOutputStream;
import java.io.IOException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Controller for airplane mode toggling that exclusively uses root commands.
 */
public class AirplaneModeController {

    private static final String TAG = "AirplaneController";
    private static final int DEFAULT_RECONNECTION_TIMEOUT_MS = 30000; // 30 seconds
    private static final int MAX_RETRY_ATTEMPTS = 2; // Maximum number of retry attempts

    private final Context context;
    private final NetworkStateMonitor networkStateMonitor;
    private int airplaneModeDelay;
    private final AtomicBoolean isRotatingIp = new AtomicBoolean(false);
    private OperationListener operationListener;

    /**
     * Constructor that initializes the controller with required dependencies.
     * @param context Application context
     * @param networkStateMonitor Network state monitor
     * @param airplaneModeDelay Delay between toggling airplane mode on and off (ms)
     */
    public AirplaneModeController(
            Context context,
            NetworkStateMonitor networkStateMonitor,
            int airplaneModeDelay) {
        this.context = context;
        this.networkStateMonitor = networkStateMonitor;
        this.airplaneModeDelay = airplaneModeDelay;
    }

    /**
     * Interface for listening to airplane mode operations status
     */
    public interface OperationListener {
        void onOperationStatusChanged(boolean isOperating);
    }

    /**
     * Set a listener for airplane mode operations
     * @param listener Operation listener
     */
    public void setOperationListener(OperationListener listener) {
        this.operationListener = listener;
    }

    /**
     * Reset the state of the controller.
     * This should be called when the app starts to ensure no stuck flags.
     */
    public void resetState() {
        isRotatingIp.set(false);
        Logger.d(TAG, "Reset airplane mode controller state");
    }

    /**
     * Rotate IP address using root method only.
     * @return CompletableFuture with IP rotation result
     */
    public CompletableFuture<IpRotationResult> rotateIp() {
        // Force reset any stuck flags
        if (isRotatingIp.get()) {
            Logger.w(TAG, "Forced reset of stuck rotation flag");
            isRotatingIp.set(false);
        }

        // Don't allow multiple rotations at the same time
        if (isRotatingIp.get()) {
            Logger.w(TAG, "IP rotation already in progress, ignoring request");
            return CompletableFuture.completedFuture(new IpRotationResult(
                    false,
                    "Unknown",
                    "Unknown",
                    "IP rotation already in progress",
                    0
            ));
        }

        return CompletableFuture.supplyAsync(() -> {
            isRotatingIp.set(true);
            if (operationListener != null) {
                operationListener.onOperationStatusChanged(true);
            }

            try {
                Logger.i(TAG, "Starting IP rotation using root method only");

                // Get current IP before toggling
                String previousIp = networkStateMonitor.getCurrentIpAddress().getValue();
                boolean wasConnected = networkStateMonitor.isNetworkAvailable();

                if (!wasConnected) {
                    Logger.w(TAG, "Network not connected before IP rotation");
                    return new IpRotationResult(false, previousIp, previousIp,
                            "Network not connected", 0);
                }

                Logger.d(TAG, "Current IP before rotation: " + previousIp);

                // Check if device is rooted first
                if (!isRooted()) {
                    Logger.e(TAG, "Device is not rooted - cannot perform IP rotation");
                    return new IpRotationResult(false, previousIp, previousIp,
                            "Device is not rooted", 0);
                }

                // Perform IP rotation via root
                IpRotationResult result = rotateIpViaRootMethod(previousIp);

                // If first attempt failed, retry once
                if (!result.isSuccess()) {
                    Logger.w(TAG, "First root method attempt failed, retrying...");
                    // Small delay before retry
                    Thread.sleep(1000);
                    result = rotateIpViaRootMethod(previousIp);
                }

                return result;

            } catch (Exception e) {
                Logger.e(TAG, "Unexpected error during IP rotation", e);
                return new IpRotationResult(false,
                        networkStateMonitor.getCurrentIpAddress().getValue(),
                        networkStateMonitor.getCurrentIpAddress().getValue(),
                        "Unexpected error: " + e.getMessage(),
                        0
                );
            } finally {
                isRotatingIp.set(false);
                if (operationListener != null) {
                    operationListener.onOperationStatusChanged(false);
                }
            }
        });
    }

    /**
     * Rotate IP via root method.
     * @param previousIp Previous IP address
     * @return IP rotation result
     */
    private IpRotationResult rotateIpViaRootMethod(String previousIp) {
        try {
            Logger.i(TAG, "Starting IP rotation via root with airplane mode delay: " + airplaneModeDelay + "ms");
            
            // Use forceful airplane mode toggle commands
            Process process = Runtime.getRuntime().exec("su");
            DataOutputStream os = new DataOutputStream(process.getOutputStream());

            // Make sure we toggle regardless of current state
            // First disable airplane mode (to be sure)
            os.writeBytes("settings put global airplane_mode_on 0\n");
            os.writeBytes("am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false\n");
            os.flush();
            Thread.sleep(1000); // Small delay
            
            // Then enable airplane mode
            os.writeBytes("settings put global airplane_mode_on 1\n");
            os.writeBytes("am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true\n");
            os.flush();

            Logger.i(TAG, "Enabled airplane mode via root, waiting for " + airplaneModeDelay + "ms");
            Thread.sleep(airplaneModeDelay);

            // Then disable airplane mode
            os.writeBytes("settings put global airplane_mode_on 0\n");
            os.writeBytes("am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false\n");
            os.writeBytes("exit\n");
            os.flush();
            os.close();

            int exitValue = process.waitFor();
            Logger.i(TAG, "Root commands executed with exit value: " + exitValue);

            // Wait for network reconnection
            long startTime = System.currentTimeMillis();
            boolean reconnected = networkStateMonitor.waitForReconnection(DEFAULT_RECONNECTION_TIMEOUT_MS);
            long reconnectionTime = System.currentTimeMillis() - startTime;

            if (!reconnected) {
                Logger.e(TAG, "Network failed to reconnect after root method");
                return new IpRotationResult(false, previousIp, previousIp,
                        "Network failed to reconnect", reconnectionTime);
            }

            // Wait a moment for IP to update
            Thread.sleep(1000);

            // Fetch new IP
            networkStateMonitor.fetchCurrentIpAddress();

            // Wait for IP address to be fetched
            int attempts = 0;
            String newIp = networkStateMonitor.getCurrentIpAddress().getValue();
            while ((newIp == null || newIp.isEmpty() || newIp.equals("Unknown")) && attempts < 10) {
                Thread.sleep(500);
                attempts++;
                networkStateMonitor.fetchCurrentIpAddress(); // Force refresh
                newIp = networkStateMonitor.getCurrentIpAddress().getValue();
            }

            boolean ipChanged = !previousIp.equals(newIp) && !newIp.isEmpty() && !newIp.equals("Unknown");

            Logger.i(TAG, "Root method result: " + (ipChanged ? "Success" : "Failed") +
                    ", Previous IP: " + previousIp + ", New IP: " + newIp);

            return new IpRotationResult(
                    ipChanged,
                    previousIp,
                    newIp,
                    ipChanged ? "Root method successful" : "IP did not change",
                    reconnectionTime
            );
        } catch (Exception e) {
            Logger.e(TAG, "Root IP rotation method failed", e);
            return new IpRotationResult(
                    false,
                    previousIp,
                    previousIp,
                    "Root method error: " + e.getMessage(),
                    0
            );
        }
    }

    /**
     * Check if the device is rooted.
     * @return True if rooted, false otherwise
     */
    private boolean isRooted() {
        try {
            Process process = Runtime.getRuntime().exec("su -c exit");
            int exitValue = process.waitFor();
            Logger.d(TAG, "Root check result: " + (exitValue == 0 ? "Rooted" : "Not rooted"));
            return exitValue == 0;
        } catch (Exception e) {
            Logger.w(TAG, "Error checking root: " + e.getMessage());
            return false;
        }
    }

    /**
     * Set the airplane mode toggle delay.
     * @param delayMs Delay in milliseconds
     */
    public void setAirplaneModeDelay(int delayMs) {
        this.airplaneModeDelay = delayMs;
        Logger.d(TAG, "Airplane mode delay set to " + delayMs + "ms");
    }

    /**
     * Result class for IP rotation operations.
     */
    public static class IpRotationResult {
        private final boolean success;
        private final String previousIp;
        private final String newIp;
        private final String message;
        private final long reconnectionTimeMs;

        public IpRotationResult(boolean success, String previousIp, String newIp,
                                String message, long reconnectionTimeMs) {
            this.success = success;
            this.previousIp = previousIp;
            this.newIp = newIp;
            this.message = message;
            this.reconnectionTimeMs = reconnectionTimeMs;
        }

        public boolean isSuccess() {
            return success;
        }

        public String getPreviousIp() {
            return previousIp;
        }

        public String getNewIp() {
            return newIp;
        }

        public String getMessage() {
            return message;
        }

        public long getReconnectionTimeMs() {
            return reconnectionTimeMs;
        }

        @Override
        public String toString() {
            return "IpRotationResult{" +
                    "success=" + success +
                    ", previousIp='" + previousIp + '\'' +
                    ", newIp='" + newIp + '\'' +
                    ", message='" + message + '\'' +
                    ", reconnectionTimeMs=" + reconnectionTimeMs +
                    '}';
        }
    }
}