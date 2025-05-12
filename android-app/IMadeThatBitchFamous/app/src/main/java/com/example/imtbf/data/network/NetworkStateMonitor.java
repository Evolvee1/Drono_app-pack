package com.example.imtbf.data.network;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiManager;

import androidx.annotation.NonNull;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.imtbf.utils.Logger;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

/**
 * Monitors network state changes and provides information about connectivity.
 * This is essential for detecting when the network has reconnected after toggling airplane mode.
 */
public class NetworkStateMonitor {

    private static final String TAG = "NetworkStateMonitor";
    private static final String IP_CHECK_URL = "https://api.ipify.org/";
    private static final int CONNECTION_TIMEOUT = 5000; // 5 seconds

    private final Context context;
    private final ConnectivityManager connectivityManager;
    private final Executor networkExecutor;

    private final MutableLiveData<Boolean> isConnected = new MutableLiveData<>();
    private final MutableLiveData<String> currentIpAddress = new MutableLiveData<>();
    private final MutableLiveData<Boolean> isAirplaneModeOn = new MutableLiveData<>();

    private BroadcastReceiver networkReceiver;
    private BroadcastReceiver airplaneModeReceiver;
    private boolean isRegistered = false;

    /**
     * Constructor that initializes the monitor with the given context.
     * @param context Application context
     */
    public NetworkStateMonitor(@NonNull Context context) {
        this.context = context.getApplicationContext();
        this.connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        this.networkExecutor = Executors.newSingleThreadExecutor();

        // Initialize default values
        isConnected.setValue(isNetworkAvailable());
        isAirplaneModeOn.setValue(false);
        currentIpAddress.setValue("");

        // Initialize the receivers
        initializeReceivers();
    }

    /**
     * Initialize the broadcast receivers for network and airplane mode changes.
     */
    private void initializeReceivers() {
        // Network state change receiver
        networkReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                boolean connected = isNetworkAvailable();
                Logger.d(TAG, "Network state changed. Connected: " + connected);
                isConnected.postValue(connected);

                if (connected) {
                    fetchCurrentIpAddress();
                } else {
                    currentIpAddress.postValue("");
                }
            }
        };

        // Airplane mode change receiver
        airplaneModeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                boolean airplaneMode = intent.getBooleanExtra("state", false);
                Logger.d(TAG, "Airplane mode changed. On: " + airplaneMode);
                isAirplaneModeOn.postValue(airplaneMode);
            }
        };
    }

    /**
     * Register the receivers to start monitoring.
     */
    public void register() {
        if (!isRegistered) {
            // Register network state receiver
            IntentFilter networkFilter = new IntentFilter();
            networkFilter.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
            networkFilter.addAction(WifiManager.WIFI_STATE_CHANGED_ACTION);
            context.registerReceiver(networkReceiver, networkFilter);

            // Register airplane mode receiver
            IntentFilter airplaneModeFilter = new IntentFilter();
            airplaneModeFilter.addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED);
            context.registerReceiver(airplaneModeReceiver, airplaneModeFilter);

            isRegistered = true;
            Logger.d(TAG, "NetworkStateMonitor registered");

            // Initial check with higher priority
            if (isNetworkAvailable()) {
                // Do immediate fetch on main thread to ensure quick initial loading
                fetchCurrentIpAddress();
            }
        }
    }

    /**
     * Unregister the receivers to stop monitoring.
     */
    public void unregister() {
        if (isRegistered) {
            try {
                context.unregisterReceiver(networkReceiver);
                context.unregisterReceiver(airplaneModeReceiver);
                isRegistered = false;
                Logger.d(TAG, "NetworkStateMonitor unregistered");
            } catch (IllegalArgumentException e) {
                Logger.e(TAG, "Error unregistering receivers", e);
            }
        }
    }

    /**
     * Check if the network is available.
     * @return True if connected, false otherwise
     */
    public boolean isNetworkAvailable() {
        if (connectivityManager == null) {
            return false;
        }

        NetworkInfo activeNetwork = connectivityManager.getActiveNetworkInfo();
        return activeNetwork != null && activeNetwork.isConnected();
    }

    /**
     * Check if airplane mode is on.
     * @return True if airplane mode is on, false otherwise
     */
    public boolean isAirplaneModeOn() {
        Boolean value = isAirplaneModeOn.getValue();
        return value != null && value;
    }

    /**
     * Get live data for network connectivity state.
     * @return LiveData of connectivity state
     */
    public LiveData<Boolean> getIsConnected() {
        return isConnected;
    }

    /**
     * Get live data for current IP address.
     * @return LiveData of current IP address
     */
    public LiveData<String> getCurrentIpAddress() {
        return currentIpAddress;
    }

    /**
     * Get live data for airplane mode state.
     * @return LiveData of airplane mode state
     */
    public LiveData<Boolean> getIsAirplaneModeOn() {
        return isAirplaneModeOn;
    }

    /**
     * Fetch the current public IP address.
     * This is done asynchronously on a background thread.
     */
    public void fetchCurrentIpAddress() {
        networkExecutor.execute(() -> {
            try {
                if (!isNetworkAvailable()) {
                    currentIpAddress.postValue("");
                    Logger.d(TAG, "Cannot fetch IP address: Network unavailable");
                    return;
                }

                Logger.d(TAG, "Starting IP address fetch...");

                // First try ipify API
                String ip = fetchFromIpify();
                if (ip != null && !ip.isEmpty()) {
                    Logger.i(TAG, "Successfully fetched IP address from ipify: " + ip);
                    currentIpAddress.postValue(ip);
                    return;
                }

                // Try alternative service if first one fails
                ip = fetchFromAlternativeService();
                if (ip != null && !ip.isEmpty()) {
                    Logger.i(TAG, "Successfully fetched IP address from alternative service: " + ip);
                    currentIpAddress.postValue(ip);
                    return;
                }

                // Fallback to InetAddress
                ip = fetchFromInetAddress();
                if (ip != null && !ip.isEmpty()) {
                    Logger.i(TAG, "Successfully fetched IP address from InetAddress: " + ip);
                    currentIpAddress.postValue(ip);
                    return;
                }

                // If all methods fail
                Logger.w(TAG, "Failed to determine IP address using all methods");
                currentIpAddress.postValue("Unknown");

            } catch (Exception e) {
                Logger.e(TAG, "Error fetching IP address: " + e.getMessage());
                currentIpAddress.postValue("Error");
            }
        });
    }

    /**
     * Fetch IP address from ipify API.
     * @return IP address or null if failed
     */
    private String fetchFromIpify() {
        HttpURLConnection connection = null;
        try {
            URL url = new URL(IP_CHECK_URL);
            connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(CONNECTION_TIMEOUT);
            connection.setReadTimeout(CONNECTION_TIMEOUT);

            if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
                // Read the response
                java.util.Scanner scanner = new java.util.Scanner(connection.getInputStream());
                scanner.useDelimiter("\\A");
                String ip = scanner.hasNext() ? scanner.next() : "";
                scanner.close();
                return ip.trim();
            }
        } catch (IOException e) {
            Logger.d(TAG, "Error fetching from ipify: " + e.getMessage());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
        return null;
    }

    /**
     * Fetch IP address using InetAddress.
     * Note: This may not always return the public IP address.
     * @return IP address or null if failed
     */
    private String fetchFromInetAddress() {
        try {
            return InetAddress.getLocalHost().getHostAddress();
        } catch (Exception e) {
            Logger.d(TAG, "Error fetching from InetAddress: " + e.getMessage());
            return null;
        }
    }

    /**
     * Check if the IP address has changed since the last check.
     * @param previousIp Previous IP address
     * @return True if changed, false otherwise
     */
    public boolean hasIpChanged(String previousIp) {
        String currentIp = currentIpAddress.getValue();
        return currentIp != null && !currentIp.isEmpty() &&
                !currentIp.equals(previousIp) &&
                !currentIp.equals("Unknown") &&
                !currentIp.equals("Error");
    }

    /**
     * Wait for the network to reconnect after toggling airplane mode.
     * @param timeoutMs Timeout in milliseconds
     * @return True if reconnected within timeout, false otherwise
     */
    public boolean waitForReconnection(long timeoutMs) {
        long startTime = System.currentTimeMillis();
        boolean connected = false;

        while (!connected && (System.currentTimeMillis() - startTime < timeoutMs)) {
            connected = isNetworkAvailable();
            if (!connected) {
                try {
                    Thread.sleep(500); // Check every 500ms
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }

        if (connected) {
            fetchCurrentIpAddress();
        }

        return connected;
    }

    /**
     * Try to fetch IP from an alternative service as backup
     */
    private String fetchFromAlternativeService() {
        HttpURLConnection connection = null;
        try {
            URL url = new URL("https://api.ipify.org/");
            connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(3000); // Faster timeout for alternative
            connection.setReadTimeout(3000);

            if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
                // Read the response
                java.util.Scanner scanner = new java.util.Scanner(connection.getInputStream());
                scanner.useDelimiter("\\A");
                String ip = scanner.hasNext() ? scanner.next() : "";
                scanner.close();
                return ip.trim();
            }
        } catch (IOException e) {
            Logger.d(TAG, "Error fetching from alternative service: " + e.getMessage());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
        return null;
    }

}