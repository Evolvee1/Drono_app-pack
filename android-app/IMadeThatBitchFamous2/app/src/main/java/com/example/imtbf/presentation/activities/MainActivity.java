package com.example.imtbf2.presentation.activities;

import android.os.Bundle;
import android.os.Handler;
import android.text.method.ScrollingMovementMethod;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.webkit.WebView;
import android.webkit.WebSettings;
import android.widget.Button;
import android.widget.CompoundButton;
import com.google.android.material.switchmaterial.SwitchMaterial;
import android.widget.Toast;
import android.widget.ImageButton;
import androidx.core.widget.NestedScrollView;
import android.content.Context;
import java.util.UUID;
import android.widget.TextView;
import android.widget.FrameLayout;

import androidx.appcompat.app.AppCompatActivity;

import com.example.imtbf2.InstagramTrafficSimulatorApp;
import com.example.imtbf2.R;
import com.example.imtbf2.data.local.PreferencesManager;
import com.example.imtbf2.data.models.DeviceProfile;
import com.example.imtbf2.data.models.UserAgentData;
import com.example.imtbf2.data.network.HttpRequestManager;
import com.example.imtbf2.data.network.NetworkStateMonitor;
import com.example.imtbf2.data.network.WebViewRequestManager;
import com.example.imtbf2.databinding.ActivityMainBinding;
import com.example.imtbf2.domain.simulation.BehaviorEngine;
import com.example.imtbf2.domain.simulation.SessionManager;
import com.example.imtbf2.data.network.SessionClearingManager;
import com.example.imtbf2.domain.simulation.TimingDistributor;
import com.example.imtbf2.domain.system.AirplaneModeController;
import com.example.imtbf2.domain.webview.WebViewController;
import com.example.imtbf2.utils.Constants;
import com.example.imtbf2.utils.Logger;
import com.example.imtbf2.domain.simulation.DistributionPattern;
import com.example.imtbf2.domain.simulation.TrafficDistributionManager;
import com.example.imtbf2.presentation.fragments.TrafficDistributionFragment;
import com.example.imtbf2.data.network.NetworkStatsTracker;
import com.example.imtbf2.data.network.NetworkStatsInterceptor;
import com.example.imtbf2.data.models.NetworkStats;
import com.example.imtbf2.data.models.NetworkSession;
import com.example.imtbf2.presentation.views.NetworkSpeedGaugeView;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.appcompat.app.AlertDialog;
import com.example.imtbf2.data.local.ConfigurationManager;
import com.example.imtbf2.data.models.AppConfiguration;
import com.example.imtbf2.presentation.adapters.ConfigFileAdapter;
import com.google.android.material.textfield.TextInputEditText;
import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import com.example.imtbf2.utils.FileLogger;
import android.content.Intent;
import com.example.imtbf2.remote.CommandExecutor;
import android.content.BroadcastReceiver;
import android.content.IntentFilter;

/**
 * Main activity for the Instagram Traffic Simulator app.
 */
public class MainActivity extends AppCompatActivity implements TrafficDistributionFragment.TrafficDistributionListener {

    private static final String TAG = "MainActivity";

    // Constants for new preferences
    private static final String PREF_DELAY_MIN = "delay_min";
    private static final String PREF_DELAY_MAX = "delay_max";
    private static final int DEFAULT_DELAY_MIN = 1; // 1 second
    private static final int DEFAULT_DELAY_MAX = 5; // 5 seconds

    private WebView webView;
    private WebViewController webViewController;
    private boolean useWebViewMode = false;
    private boolean isConfigExpanded = true;

    private ActivityMainBinding binding;
    private PreferencesManager preferencesManager;
    private NetworkStateMonitor networkStateMonitor;
    private WebViewRequestManager webViewRequestManager;
    private HttpRequestManager httpRequestManager;
    private AirplaneModeController airplaneModeController;

    private SessionClearingManager sessionClearingManager;
    private BehaviorEngine behaviorEngine;
    private TimingDistributor timingDistributor;
    private SessionManager sessionManager;
    private long simulationStartTime = 0;

    private TrafficDistributionManager trafficDistributionManager;
    private TrafficDistributionFragment trafficDistributionFragment;

    // Network statistics tracking
    private NetworkStatsTracker networkStatsTracker;
    private NetworkSpeedGaugeView networkSpeedView;
    private Handler networkUpdateHandler = new Handler();
    private Runnable networkUpdateRunnable = new Runnable() {
        @Override
        public void run() {
            updateNetworkStats();
            networkUpdateHandler.postDelayed(this, 1000); // Update every second
        }
    };

    // Fields for time tracking
    private long startTimeMs = 0;
    private long pauseTimeMs = 0; // Time when the session was paused
    private long totalPausedTimeMs = 0; // Total time spent in paused state
    private Handler timeUpdateHandler = new Handler();
    private Runnable timeUpdateRunnable = new Runnable() {
        @Override
        public void run() {
            updateElapsedTime();
            timeUpdateHandler.postDelayed(this, 1000); // Update every second
        }
    };

    private ConfigurationManager configurationManager;
    private FileLogger fileLogger;
    
    // BroadcastReceiver to handle UI refresh requests
    private final BroadcastReceiver uiRefreshReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if ("com.example.imtbf2.REFRESH_UI".equals(intent.getAction())) {
                Logger.i(TAG, "Received UI refresh broadcast");
                runOnUiThread(() -> {
                    reloadSettingsFromPreferences();
                    Toast.makeText(MainActivity.this, "Settings updated", Toast.LENGTH_SHORT).show();
                });
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        // Initialize components
        initializeComponents();

        // Load initial IP address
        loadInitialIpAddress();

        // Set up UI
        setupUI();

        // Set up listeners
        setupListeners();

        // Observe network state
        observeNetworkState();

        // Load saved settings
        loadSettings();

        // Ensure clean state for airplane mode controller
        if (airplaneModeController != null) {
            airplaneModeController.resetState();
        }

        if (webView != null) {
            webViewController.configureWebViewForIncognito(webView);
        }
        
        // Initialize file logger
        initializeFileLogger();
    }

    @Override
    protected void onResume() {
        super.onResume();
        
        // Register UI refresh receiver
        IntentFilter filter = new IntentFilter("com.example.imtbf2.REFRESH_UI");
        registerReceiver(uiRefreshReceiver, filter);
        
        // Start network monitoring
        if (networkStatsTracker != null) {
            networkStatsTracker.startTracking();
            networkUpdateHandler.post(networkUpdateRunnable);
        }

        // Register network state monitor
        networkStateMonitor.register();

        // Fetch current IP
        networkStateMonitor.fetchCurrentIpAddress();

        // Update UI based on session state
        updateUIBasedOnSessionState();
        
        // Reload settings from preferences
        reloadSettingsFromPreferences();
    }

    @Override
    protected void onPause() {
        // Unregister UI refresh receiver
        try {
            unregisterReceiver(uiRefreshReceiver);
        } catch (IllegalArgumentException e) {
            // Receiver not registered, ignore
        }
        
        super.onPause();

        // Pause network updates
        networkUpdateHandler.removeCallbacks(networkUpdateRunnable);

        // Save settings
        saveSettings();

        // Always save session state if the simulation is running
        if (sessionManager.isRunning()) {
            int currentIteration = Integer.parseInt(binding.tvProgress.getText().toString().split("/")[0].split(": ")[1]);
            int totalIterations = Integer.parseInt(binding.tvProgress.getText().toString().split("/")[1]);
            boolean isPaused = sessionManager.isPaused();
            long currentStartTime = startTimeMs;
            
            // If we're closing without pausing, automatically pause
            if (!isPaused) {
                sessionManager.pauseSession();
                isPaused = true;
                pauseTimeMs = System.currentTimeMillis();
                addLog("Session auto-paused on app exit");
            }
            
            // Save state with pause time information
            preferencesManager.saveSessionState(
                currentIteration, 
                totalIterations, 
                isPaused, 
                currentStartTime,
                totalPausedTimeMs,
                pauseTimeMs
            );
            
            addLog("Session state saved");
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // Unregister network state monitor
        networkStateMonitor.unregister();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.main_menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();

        if (id == R.id.action_settings) {
            // TODO: Open settings activity
            Toast.makeText(this, "Settings (Coming Soon)", Toast.LENGTH_SHORT).show();
            return true;
        } else if (id == R.id.action_clear_logs) {
            clearLogs();
            return true;
        } else if (id == R.id.action_export_config) {
            showExportConfigDialog();
            return true;
        } else if (id == R.id.action_import_config) {
            showImportConfigDialog();
            return true;
        } else if (id == R.id.action_view_logs) {
            openLogViewer();
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onScheduledModeChanged(boolean enabled) {
        trafficDistributionManager.setScheduledModeEnabled(enabled);

        // Update UI based on scheduled mode
        if (enabled) {
            // Configure traffic distribution
            int iterations = Integer.parseInt(binding.etIterations.getText().toString());
            int durationHours = preferencesManager.getDistributionDurationHours();
            DistributionPattern pattern = DistributionPattern.fromString(
                    preferencesManager.getDistributionPattern());

            trafficDistributionManager.configureSchedule(iterations, durationHours, pattern);

            // Set up session manager for scheduled requests
            String targetUrl = binding.etTargetUrl.getText().toString().trim();

            // Create initial device profile (or null for random)
            DeviceProfile deviceProfile = binding.switchRandomDevices.isChecked() ?
                    null : new DeviceProfile.Builder()
                    .deviceType(DeviceProfile.TYPE_MOBILE)
                    .platform(DeviceProfile.PLATFORM_ANDROID)
                    .deviceTier(DeviceProfile.TIER_MID_RANGE)
                    .userAgent(UserAgentData.getRandomUserAgent())
                    .region("slovakia")
                    .build();

            sessionManager.configureScheduledRequests(targetUrl, deviceProfile);

            addLog("Configured scheduled traffic distribution: " +
                    iterations + " requests over " + durationHours + " hours");
        } else {
            addLog("Switched to immediate traffic distribution mode");
        }
    }

    @Override
    public void onDistributionSettingsChanged(DistributionPattern pattern, int durationHours,
                                              int peakHourStart, int peakHourEnd, float peakWeight) {
        if (trafficDistributionManager != null) {
            // Update traffic distribution settings
            int iterations = Integer.parseInt(binding.etIterations.getText().toString());
            trafficDistributionManager.configureSchedule(iterations, durationHours, pattern);

            addLog("Updated distribution settings: " + pattern.getDisplayName() +
                    ", " + durationHours + " hours");
        }
    }

    /**
     * Initialize all components needed for the app.
     */
    private void initializeComponents() {
        // Get preferences manager
        preferencesManager = ((InstagramTrafficSimulatorApp) getApplication()).getPreferencesManager();

        // Initialize network state monitor
        networkStateMonitor = new NetworkStateMonitor(this);

        // Initialize WebView request manager
        webViewRequestManager = new WebViewRequestManager(this, networkStateMonitor);

        if (webViewRequestManager != null) {
            webViewRequestManager.setUseNewWebViewPerRequest(
                    preferencesManager.isNewWebViewPerRequestEnabled()
            );
        }

        // Initialize WebView controller
        webViewController = new WebViewController(this);

        // Initialize HTTP request manager
        httpRequestManager = new HttpRequestManager(this, networkStateMonitor);

        // Initialize timing distributor
        timingDistributor = new TimingDistributor(
                preferencesManager.getMinInterval(),
                preferencesManager.getMaxInterval(),
                Constants.DEFAULT_READING_TIME_MEAN_MS,
                Constants.DEFAULT_READING_TIME_STDDEV_MS,
                Constants.SCROLL_PROBABILITY
        );

        // Initialize behavior engine
        behaviorEngine = new BehaviorEngine(timingDistributor);

        // Initialize airplane mode controller
        airplaneModeController = new AirplaneModeController(
                this,
                networkStateMonitor,
                preferencesManager.getAirplaneModeDelay()
        );

        // Initialize session clearing manager
        sessionClearingManager = new SessionClearingManager(this);

        // Initialize session manager
        sessionManager = new SessionManager(
                this,
                networkStateMonitor,
                httpRequestManager,
                webViewRequestManager,
                airplaneModeController,
                behaviorEngine,
                timingDistributor
        );

        trafficDistributionManager = new TrafficDistributionManager(this, sessionManager);

        // Initialize Metapic redirect handling
        if (webViewRequestManager != null) {
            webViewRequestManager.setHandleMetapicRedirects(
                    preferencesManager.isHandleMarketingRedirectsEnabled()
            );
        }

        // Initialize network statistics tracking
        initializeNetworkMonitoring();

        configurationManager = new ConfigurationManager(this, preferencesManager);
        fileLogger = FileLogger.getInstance(getApplicationContext());
    }

    /**
     * Initialize network monitoring components
     */
    private void initializeNetworkMonitoring() {
        // Create network stats tracker
        networkStatsTracker = new NetworkStatsTracker(this);

        // Add network stats interceptor to OkHttpClient
        if (httpRequestManager != null) {
            NetworkStatsInterceptor interceptor = new NetworkStatsInterceptor(networkStatsTracker);
            // Add the interceptor to your OkHttpClient
            // Note: This requires modifying HttpRequestManager to accept interceptors
            // or adding a method to add them later
        }

        // Observe network stats changes
        networkStatsTracker.getCurrentStats().observe(this, this::onNetworkStatsChanged);
        networkStatsTracker.getSessionData().observe(this, this::onSessionDataChanged);
    }

    /**
     * Test the WebView functionality
     */
    private void testWebView() {
        String testUrl = "https://detiyavanny.com/";
        DeviceProfile testProfile = new DeviceProfile.Builder()
                .deviceType(DeviceProfile.TYPE_MOBILE)
                .platform(DeviceProfile.PLATFORM_ANDROID)
                .deviceTier(DeviceProfile.TIER_MID_RANGE)
                .userAgent(UserAgentData.getRandomUserAgent())
                .region("slovakia")
                .build();

        webViewRequestManager.makeRequest(testUrl, testProfile, null, new WebViewRequestManager.RequestCallback() {
            @Override
            public void onSuccess(int statusCode, long responseTimeMs) {
                addLog("WebView test successful - Loaded in " + responseTimeMs + "ms");
            }

            @Override
            public void onError(String error) {
                addLog("WebView test failed: " + error);
            }
        });
    }

    /**
     * Load the current IP address when the app starts
     */
    private void loadInitialIpAddress() {
        // Show loading state in the UI
        binding.tvCurrentIp.setText("Current IP: Loading...");

        // Add a log entry
        addLog("Fetching initial IP address...");

        // Set a timeout for the IP fetch operation
        final Handler handler = new Handler();
        final Runnable timeoutRunnable = () -> {
            if (binding.tvCurrentIp.getText().toString().contains("Loading")) {
                binding.tvCurrentIp.setText("Current IP: Fetch timed out. Try again.");
                addLog("IP address fetch timed out");
            }
        };

        // Set 5-second timeout
        handler.postDelayed(timeoutRunnable, 5000);

        // Observe the IP address LiveData
        networkStateMonitor.getCurrentIpAddress().observe(this, ipAddress -> {
            // Remove the timeout handler since we got a response
            handler.removeCallbacks(timeoutRunnable);

            if (ipAddress != null && !ipAddress.isEmpty()) {
                binding.tvCurrentIp.setText("Current IP: " + ipAddress);
                addLog("Initial IP Address: " + ipAddress);
            } else {
                // If the IP is empty but we got a response, update UI
                if (!binding.tvCurrentIp.getText().toString().contains("timed out")) {
                    binding.tvCurrentIp.setText("Current IP: Could not determine");
                    addLog("Could not determine IP address");
                }
            }
        });

        // Force a refresh of the IP address
        networkStateMonitor.fetchCurrentIpAddress();
    }

    /**
     * Set up WebView controls
     */
    private void setupWebViewControls() {
        // Use SwitchMaterial instead of Switch
        SwitchMaterial switchUseWebView = findViewById(R.id.switchUseWebView);
        Button btnHideWebView = findViewById(R.id.btnHideWebView);
        View cardWebView = findViewById(R.id.cardWebView);

        if (switchUseWebView == null || btnHideWebView == null) {
            Logger.e(TAG, "WebView controls not found in layout");
            return;
        }

        // Set initial state
        useWebViewMode = preferencesManager.getUseWebViewMode();
        switchUseWebView.setChecked(useWebViewMode);

        if (cardWebView != null) {
            cardWebView.setVisibility(useWebViewMode ? View.VISIBLE : View.GONE);
        }

        // Set up listener for the switch
        switchUseWebView.setOnCheckedChangeListener((buttonView, isChecked) -> {
            useWebViewMode = isChecked;

            // Show WebView card if in WebView mode
            if (cardWebView != null) {
                cardWebView.setVisibility(useWebViewMode ? View.VISIBLE : View.GONE);
            }

            // Update preference
            preferencesManager.setUseWebViewMode(useWebViewMode);

            // Log the change
            addLog("Switched to " + (useWebViewMode ? "WebView" : "HTTP") + " mode");
        });

        // Set up listener for the hide button
        btnHideWebView.setOnClickListener(v -> {
            if (cardWebView != null) {
                cardWebView.setVisibility(View.GONE);
            }
        });
    }

    /**
     * Set up the UI components.
     */
    private void setupUI() {
        // Set up logs text view
        binding.tvLogs.setMovementMethod(new ScrollingMovementMethod());

        // Set up initial status
        binding.tvStatusLabel.setText("Status: Ready");
        binding.tvProgress.setText("Progress: 0/0");
        binding.tvCurrentIp.setText("Current IP: Checking...");

        // Disable stop button initially
        binding.btnStop.setEnabled(false);

        // Initialize WebView
        webView = findViewById(R.id.webView);
        if (webView != null) {
            webViewController.configureWebView(webView, null); // Initial configuration
        }

        // Initialize config state
        isConfigExpanded = preferencesManager.getBoolean("config_expanded", true);
        View settingsSection = findViewById(R.id.settingsSection);
        if (settingsSection != null) {
            settingsSection.setVisibility(isConfigExpanded ? View.VISIBLE : View.GONE);
        }
        
        // Set up configuration toggle
        ImageButton btnToggleConfig = findViewById(R.id.btnToggleConfig);
        if (btnToggleConfig != null) {
            btnToggleConfig.setOnClickListener(v -> toggleConfigVisibility());
            btnToggleConfig.setImageResource(isConfigExpanded ?
                    android.R.drawable.arrow_up_float : android.R.drawable.arrow_down_float);
        }

        // Set up traffic distribution fragment
        if (findViewById(R.id.fragmentTrafficDistribution) != null) {
            trafficDistributionFragment = (TrafficDistributionFragment) getSupportFragmentManager()
                    .findFragmentById(R.id.fragmentTrafficDistribution);

            if (trafficDistributionFragment == null) {
                trafficDistributionFragment = new TrafficDistributionFragment();
                getSupportFragmentManager().beginTransaction()
                        .add(R.id.fragmentTrafficDistribution, trafficDistributionFragment)
                        .commit();
            }
        }

        // Setup network statistics UI
        setupNetworkStatsUI();
    }

    /**
     * Set up network statistics UI components
     */
    private void setupNetworkStatsUI() {
        // Find network stats views
        TextView tvDownloadSpeed = findViewById(R.id.tvDownloadSpeed);
        TextView tvUploadSpeed = findViewById(R.id.tvUploadSpeed);
        TextView tvDownloadTotal = findViewById(R.id.tvDownloadTotal);
        TextView tvUploadTotal = findViewById(R.id.tvUploadTotal);
        TextView tvTotalData = findViewById(R.id.tvTotalData);
        TextView tvRequestCount = findViewById(R.id.tvRequestCount);
        TextView tvSessionDuration = findViewById(R.id.tvSessionDuration);
        TextView tvNetworkStatus = findViewById(R.id.tvNetworkStatus);
        Button btnResetStats = findViewById(R.id.btnResetStats);

        // Create network speed gauge
        FrameLayout networkGraphContainer = findViewById(R.id.networkGraphContainer);
        if (networkGraphContainer != null) {
            networkGraphContainer.removeAllViews();

            networkSpeedView = new NetworkSpeedGaugeView(this);
            networkGraphContainer.addView(networkSpeedView, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT));
        }

        // Set up reset button
        if (btnResetStats != null) {
            btnResetStats.setOnClickListener(v -> {
                if (networkStatsTracker != null) {
                    networkStatsTracker.stopTracking();
                    networkStatsTracker.startTracking();
                    if (networkSpeedView != null) {
                        networkSpeedView.reset();
                    }
                    addLog("Network statistics reset");
                }
            });
        }
    }

    /**
     * Set up the "New WebView Per Request" switch
     */
    private void setupNewWebViewPerRequestSwitch() {
        SwitchMaterial switchNewWebViewPerRequest = findViewById(R.id.switchNewWebViewPerRequest);
        if (switchNewWebViewPerRequest != null) {
            // Set initial state from preferences
            switchNewWebViewPerRequest.setChecked(
                    preferencesManager.isNewWebViewPerRequestEnabled()
            );

            // Set listener for switch
            switchNewWebViewPerRequest.setOnCheckedChangeListener((buttonView, isChecked) -> {
                // Save preference
                preferencesManager.setNewWebViewPerRequestEnabled(isChecked);

                // Update WebViewRequestManager if it exists
                if (webViewRequestManager != null) {
                    webViewRequestManager.setUseNewWebViewPerRequest(isChecked);
                }

                // Log the change
                addLog("New WebView Per Request: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
    }

    /**
     * Toggle the visibility of the configuration settings section
     */
    private void toggleConfigVisibility() {
        isConfigExpanded = !isConfigExpanded;
        View settingsSection = findViewById(R.id.settingsSection);
        ImageButton btnToggleConfig = findViewById(R.id.btnToggleConfig);

        if (settingsSection != null) {
            settingsSection.setVisibility(isConfigExpanded ? View.VISIBLE : View.GONE);
        }

        if (btnToggleConfig != null) {
            btnToggleConfig.setImageResource(isConfigExpanded ?
                    android.R.drawable.arrow_up_float : android.R.drawable.arrow_down_float);
        }

        // Store preference
        preferencesManager.setBoolean("config_expanded", isConfigExpanded);
    }

    /**
     * Prepare a WebView configured for incognito browsing
     */
    private WebView prepareIncognitoWebView(Context context, DeviceProfile deviceProfile) {
        try {
            // Create a fresh WebView for each request
            WebView freshWebView = new WebView(context);

            // Configure WebView with incognito settings and device profile
            webViewController.configureWebView(freshWebView, deviceProfile);

            // Additional optional configurations for incognito mode
            WebSettings settings = freshWebView.getSettings();

            // Ensure no tracking
            settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);

            // Clear any potential existing data
            freshWebView.clearCache(true);
            freshWebView.clearHistory();
            freshWebView.clearFormData();

            // Add a unique identifier for the session
            freshWebView.setTag(UUID.randomUUID().toString());

            // Optional: Log the preparation
            Logger.d(TAG, "Prepared incognito WebView with unique ID: " + freshWebView.getTag());

            return freshWebView;
        } catch (Exception e) {
            // Fallback to standard WebView if something goes wrong
            Logger.e(TAG, "Error preparing incognito WebView", e);
            return new WebView(context);
        }
    }

    /**
     * Set up button click listeners and input field change listeners.
     */
    private void setupListeners() {
        // Start button
        binding.btnStart.setOnClickListener(v -> {
            if (validateInputs()) {
                startSimulation();
            }
        });

        // Pause button
        binding.btnPause.setOnClickListener(v -> {
            pauseOrResumeSimulation();
        });

        // Stop button
        binding.btnStop.setOnClickListener(v -> {
            stopSimulation();
        });
        
        // Add auto-save listeners to text fields
        setupTextChangedListeners();
        
        // Add auto-save listeners to switches
        setupSwitchListeners();
    }

    /**
     * Set up text change listeners for automatic saving
     */
    private void setupTextChangedListeners() {
        // Add text changed listeners to all EditText fields with a small delay
        addDelayedTextChangedListener(binding.etTargetUrl, text -> {
            preferencesManager.setTargetUrl(text.toString().trim());
        });
        
        addDelayedTextChangedListener(binding.etMinInterval, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setMinInterval(value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
        
        addDelayedTextChangedListener(binding.etMaxInterval, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setMaxInterval(value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
        
        addDelayedTextChangedListener(binding.etIterations, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setIterations(value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
        
        addDelayedTextChangedListener(binding.etDelayMin, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setInt(PREF_DELAY_MIN, value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
        
        addDelayedTextChangedListener(binding.etDelayMax, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setInt(PREF_DELAY_MAX, value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
        
        addDelayedTextChangedListener(binding.etAirplaneModeDelay, text -> {
            try {
                int value = Integer.parseInt(text.toString());
                preferencesManager.setAirplaneModeDelay(value);
            } catch (NumberFormatException e) {
                // Skip invalid values
            }
        });
    }

    /**
     * Helper method to add a text changed listener with a delay to prevent excessive saves
     * @param editText The EditText to monitor
     * @param onTextChanged Callback when text has changed and delay has passed
     */
    private void addDelayedTextChangedListener(com.google.android.material.textfield.TextInputEditText editText, 
                                              java.util.function.Consumer<CharSequence> onTextChanged) {
        if (editText == null) return;
        
        final Handler handler = new Handler();
        final long DELAY = 1000; // 1 second delay
        final Runnable[] inputFinished = {null};
        
        editText.addTextChangedListener(new android.text.TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(android.text.Editable s) {
                // Remove any pending callbacks
                if (inputFinished[0] != null) {
                    handler.removeCallbacks(inputFinished[0]);
                }
                
                // Create a new callback
                inputFinished[0] = () -> {
                    if (s != null && !s.toString().isEmpty()) {
                        onTextChanged.accept(s);
                    }
                };
                
                // Schedule the callback after the delay
                handler.postDelayed(inputFinished[0], DELAY);
            }
        });
    }

    /**
     * Set up switch change listeners for automatic saving
     */
    private void setupSwitchListeners() {
        // WebView mode switch
        SwitchMaterial switchUseWebView = findViewById(R.id.switchUseWebView);
        if (switchUseWebView != null) {
            // Set initial state
            useWebViewMode = preferencesManager.getUseWebViewMode();
            switchUseWebView.setChecked(useWebViewMode);
            
            // Set initial visibility of WebView card
            View cardWebView = findViewById(R.id.cardWebView);
            if (cardWebView != null) {
                cardWebView.setVisibility(useWebViewMode ? View.VISIBLE : View.GONE);
            }
            
            // Set listener
            switchUseWebView.setOnCheckedChangeListener((buttonView, isChecked) -> {
                useWebViewMode = isChecked;
                preferencesManager.setUseWebViewMode(isChecked);
                
                // Show WebView card if in WebView mode
                if (cardWebView != null) {
                    cardWebView.setVisibility(useWebViewMode ? View.VISIBLE : View.GONE);
                }
                
                // Log the change
                addLog("Switched to " + (useWebViewMode ? "WebView" : "HTTP") + " mode");
            });
        }
        
        // Aggressive session clearing switch
        SwitchMaterial switchAggressiveSessionClearing = findViewById(R.id.switchAggressiveSessionClearing);
        if (switchAggressiveSessionClearing != null) {
            // Set initial state
            switchAggressiveSessionClearing.setChecked(preferencesManager.isAggressiveSessionClearingEnabled());
            
            // Set listener
            switchAggressiveSessionClearing.setOnCheckedChangeListener((buttonView, isChecked) -> {
                preferencesManager.setAggressiveSessionClearingEnabled(isChecked);
                addLog("Aggressive Session Clearing: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
        
        // New WebView per request switch
        SwitchMaterial switchNewWebViewPerRequest = findViewById(R.id.switchNewWebViewPerRequest);
        if (switchNewWebViewPerRequest != null) {
            // Set initial state
            switchNewWebViewPerRequest.setChecked(preferencesManager.isNewWebViewPerRequestEnabled());
            
            // Set listener
            switchNewWebViewPerRequest.setOnCheckedChangeListener((buttonView, isChecked) -> {
                preferencesManager.setNewWebViewPerRequestEnabled(isChecked);
                
                // Update WebViewRequestManager if it exists
                if (webViewRequestManager != null) {
                    webViewRequestManager.setUseNewWebViewPerRequest(isChecked);
                }
                
                addLog("New WebView Per Request: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
        
        // Handle marketing redirects switch
        SwitchMaterial switchHandleRedirects = findViewById(R.id.switchHandleRedirects);
        if (switchHandleRedirects != null) {
            // Set initial state
            switchHandleRedirects.setChecked(preferencesManager.isHandleMarketingRedirectsEnabled());
            
            // Set listener
            switchHandleRedirects.setOnCheckedChangeListener((buttonView, isChecked) -> {
                preferencesManager.setHandleMarketingRedirectsEnabled(isChecked);
                
                // Update WebViewRequestManager if it exists
                if (webViewRequestManager != null) {
                    webViewRequestManager.setHandleMetapicRedirects(isChecked);
                }
                
                addLog("Marketing Redirect Handling: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
        
        // Rotate IP switch
        SwitchMaterial switchRotateIp = findViewById(R.id.switchRotateIp);
        if (switchRotateIp != null) {
            // Set initial state
            switchRotateIp.setChecked(preferencesManager.getBoolean("rotate_ip", true));
            
            // Set listener
            switchRotateIp.setOnCheckedChangeListener((buttonView, isChecked) -> {
                preferencesManager.setBoolean("rotate_ip", isChecked);
                addLog("IP Rotation: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
        
        // Random devices switch
        SwitchMaterial switchRandomDevices = findViewById(R.id.switchRandomDevices);
        if (switchRandomDevices != null) {
            // Set initial state
            switchRandomDevices.setChecked(preferencesManager.getBoolean("use_random_device_profile", true));
            
            // Set listener
            switchRandomDevices.setOnCheckedChangeListener((buttonView, isChecked) -> {
                preferencesManager.setBoolean("use_random_device_profile", isChecked);
                addLog("Random Device Profiles: " + (isChecked ? "Enabled" : "Disabled"));
            });
        }
        
        // Setup hide WebView button
        Button btnHideWebView = findViewById(R.id.btnHideWebView);
        View cardWebView = findViewById(R.id.cardWebView);
        if (btnHideWebView != null && cardWebView != null) {
            btnHideWebView.setOnClickListener(v -> {
                cardWebView.setVisibility(View.GONE);
            });
        }
    }

    /**
     * Observe network state changes.
     */
    private void observeNetworkState() {
        // Observe connection state
        networkStateMonitor.getIsConnected().observe(this, isConnected -> {
            String status = isConnected ? "Connected" : "Disconnected";
            addLog("Network: " + status);
        });

        // Observe IP address
        networkStateMonitor.getCurrentIpAddress().observe(this, ipAddress -> {
            if (ipAddress != null && !ipAddress.isEmpty()) {
                binding.tvCurrentIp.setText("Current IP: " + ipAddress);
                addLog("IP Address: " + ipAddress);
            } else {
                binding.tvCurrentIp.setText("Current IP: Unknown");
            }
        });

        // Observe airplane mode
        networkStateMonitor.getIsAirplaneModeOn().observe(this, isOn -> {
            addLog("Airplane Mode: " + (isOn ? "On" : "Off"));
        });
    }

    /**
     * Load saved settings from preferences.
     */
    private void loadSettings() {
        binding.etTargetUrl.setText(preferencesManager.getTargetUrl());
        binding.etMinInterval.setText(String.valueOf(preferencesManager.getMinInterval()));
        binding.etMaxInterval.setText(String.valueOf(preferencesManager.getMaxInterval()));
        binding.etIterations.setText(String.valueOf(preferencesManager.getIterations()));

        // Load custom delay settings
        binding.etDelayMin.setText(String.valueOf(
                preferencesManager.getInt(PREF_DELAY_MIN, DEFAULT_DELAY_MIN)));
        binding.etDelayMax.setText(String.valueOf(
                preferencesManager.getInt(PREF_DELAY_MAX, DEFAULT_DELAY_MAX)));

        // Add this line to load airplane mode delay
        binding.etAirplaneModeDelay.setText(String.valueOf(
                preferencesManager.getAirplaneModeDelay()));

        // Load WebView mode setting
        useWebViewMode = preferencesManager.getUseWebViewMode();
        SwitchMaterial switchUseWebView = findViewById(R.id.switchUseWebView);
        if (switchUseWebView != null) {
            switchUseWebView.setChecked(useWebViewMode);
        }

        // Load configuration expansion state
        isConfigExpanded = preferencesManager.getBoolean("config_expanded", true);

        SwitchMaterial switchAggressiveSessionClearing =
                findViewById(R.id.switchAggressiveSessionClearing);
        if (switchAggressiveSessionClearing != null) {
            switchAggressiveSessionClearing.setChecked(
                    preferencesManager.isAggressiveSessionClearingEnabled()
            );
        }

        SwitchMaterial switchNewWebViewPerRequest = findViewById(R.id.switchNewWebViewPerRequest);
        if (switchNewWebViewPerRequest != null) {
            switchNewWebViewPerRequest.setChecked(
                    preferencesManager.isNewWebViewPerRequestEnabled()
            );
        }

        SwitchMaterial switchHandleRedirects = findViewById(R.id.switchHandleRedirects);
        if (switchHandleRedirects != null) {
            switchHandleRedirects.setChecked(
                    preferencesManager.isHandleMarketingRedirectsEnabled()
            );
        }
    }

    /**
     * Save settings to preferences.
     */
    private void saveSettings() {
        try {
            String targetUrl = binding.etTargetUrl.getText().toString().trim();
            if (!targetUrl.isEmpty()) {
                preferencesManager.setTargetUrl(targetUrl);
            }

            int minInterval = Integer.parseInt(binding.etMinInterval.getText().toString());
            preferencesManager.setMinInterval(minInterval);

            int maxInterval = Integer.parseInt(binding.etMaxInterval.getText().toString());
            preferencesManager.setMaxInterval(maxInterval);

            int iterations = Integer.parseInt(binding.etIterations.getText().toString());
            preferencesManager.setIterations(iterations);

            // Save custom delay settings
            int delayMin = Integer.parseInt(binding.etDelayMin.getText().toString());
            int delayMax = Integer.parseInt(binding.etDelayMax.getText().toString());
            preferencesManager.setInt(PREF_DELAY_MIN, delayMin);
            preferencesManager.setInt(PREF_DELAY_MAX, delayMax);

            // Add this block to save airplane mode delay
            int airplaneModeDelay = Integer.parseInt(binding.etAirplaneModeDelay.getText().toString());
            preferencesManager.setAirplaneModeDelay(airplaneModeDelay);

            // Save WebView mode setting
            preferencesManager.setUseWebViewMode(useWebViewMode);

            preferencesManager.setBoolean("config_expanded", isConfigExpanded);

        } catch (NumberFormatException e) {
            Logger.e(TAG, "Error parsing numbers", e);
        }
    }

    /**
     * Validate user inputs.
     * @return True if inputs are valid, false otherwise
     */
    private boolean validateInputs() {
        String targetUrl = binding.etTargetUrl.getText().toString().trim();
        if (targetUrl.isEmpty() || !(targetUrl.startsWith("http://") || targetUrl.startsWith("https://"))) {
            Toast.makeText(this, "Please enter a valid URL", Toast.LENGTH_SHORT).show();
            return false;
        }

        try {
            int minInterval = Integer.parseInt(binding.etMinInterval.getText().toString());
            int maxInterval = Integer.parseInt(binding.etMaxInterval.getText().toString());
            int iterations = Integer.parseInt(binding.etIterations.getText().toString());
            int delayMin = Integer.parseInt(binding.etDelayMin.getText().toString());
            int delayMax = Integer.parseInt(binding.etDelayMax.getText().toString());
            // Add this line to parse airplane mode delay
            int airplaneModeDelay = Integer.parseInt(binding.etAirplaneModeDelay.getText().toString());

            if (minInterval <= 0 || maxInterval <= 0 || iterations <= 0 || delayMin <= 0 || delayMax <= 0 || airplaneModeDelay <= 0) {
                Toast.makeText(this, "Values must be greater than 0", Toast.LENGTH_SHORT).show();
                return false;
            }

            // Add specific validation for airplane mode delay
            if (airplaneModeDelay < 1000) {
                Toast.makeText(this, "Airplane mode delay should be at least 1000ms", Toast.LENGTH_SHORT).show();
                return false;
            }

            if (minInterval > maxInterval) {
                Toast.makeText(this, "Min interval cannot be greater than max interval", Toast.LENGTH_SHORT).show();
                return false;
            }

            if (delayMin > delayMax) {
                Toast.makeText(this, "Min delay cannot be greater than max delay", Toast.LENGTH_SHORT).show();
                return false;
            }

        } catch (NumberFormatException e) {
            Toast.makeText(this, "Please enter valid numbers", Toast.LENGTH_SHORT).show();
            return false;
        }

        return true;
    }

    /**
     * Start the simulation.
     */
    private void startSimulation() {
        // Get input values
        String targetUrl = binding.etTargetUrl.getText().toString().trim();
        int iterations = Integer.parseInt(binding.etIterations.getText().toString());
        boolean useRandomDeviceProfile = binding.switchRandomDevices.isChecked();
        boolean rotateIp = binding.switchRotateIp.isChecked();

        // Get timing values
        int minInterval = Integer.parseInt(binding.etMinInterval.getText().toString());
        int maxInterval = Integer.parseInt(binding.etMaxInterval.getText().toString());
        int delayMin = Integer.parseInt(binding.etDelayMin.getText().toString());
        int delayMax = Integer.parseInt(binding.etDelayMax.getText().toString());
        //Airplane-mode settings
        int airplaneModeDelay = Integer.parseInt(binding.etAirplaneModeDelay.getText().toString());
        airplaneModeController.setAirplaneModeDelay(airplaneModeDelay);

        // Update timing distributor settings for legacy code
        timingDistributor.setMinIntervalSeconds(minInterval);
        timingDistributor.setMaxIntervalSeconds(maxInterval);

        if (trafficDistributionManager != null &&
                trafficDistributionManager.isScheduledModeEnabled()) {
            // Start in scheduled mode
            trafficDistributionManager.startDistribution();
        }

        // Update UI
        binding.btnStart.setEnabled(false);
        binding.btnPause.setEnabled(true);
        binding.btnPause.setText("Pause");
        binding.btnStop.setEnabled(true);
        binding.tvStatusLabel.setText("Status: Running");
        binding.tvProgress.setText("Progress: 0/" + iterations);

        // Reset timer tracking variables
        startTimeMs = System.currentTimeMillis();
        pauseTimeMs = 0;
        totalPausedTimeMs = 0;
        updateElapsedTime();
        timeUpdateHandler.removeCallbacks(timeUpdateRunnable);
        timeUpdateHandler.postDelayed(timeUpdateRunnable, 1000);

        // Clear logs
        clearLogs();

        // Add start log
        addLog("Starting simulation: " + targetUrl + ", " +
                iterations + " iterations, " +
                "Random Devices: " + useRandomDeviceProfile + ", " +
                "Rotate IP: " + rotateIp + ", " +
                "Delays: " + delayMin + "-" + delayMax + "s, " +
                "Airplane Mode Delay: " + airplaneModeDelay + "ms, " +
                "Mode: " + (useWebViewMode ? "WebView" : "HTTP") + ", " +
                "New WebView Per Request: " + preferencesManager.isNewWebViewPerRequestEnabled());
        addLog("Target URL: " + targetUrl);

        // Set up airplane mode listener
        airplaneModeController.setOperationListener(this::showAirplaneModeOperation);

        // Reset airplane mode controller state
        airplaneModeController.resetState();

        // Set up progress observer
        sessionManager.setProgressListener((current, total) -> {
            runOnUiThread(() -> {
                binding.tvProgress.setText("Progress: " + current + "/" + total);
                
                // If progress changed, log it
                if (current % 5 == 0 || current == 1 || current == total) {
                    addLog("Progress: " + current + "/" + total);
                }

                // Update estimated time remaining
                if (current > 0) {
                    long elapsedMs = System.currentTimeMillis() - startTimeMs;
                    long avgTimePerIteration = elapsedMs / current;
                    long remainingMs = avgTimePerIteration * (total - current);

                    String remainingTime = formatTime(remainingMs);
                    binding.tvTimeRemaining.setText("Estimated time remaining: " + remainingTime);
                }
            });
        });

        // Check if aggressive session clearing is enabled
        boolean isAggressiveClearing =
                preferencesManager.isAggressiveSessionClearingEnabled();

        // Prepare WebView based on session clearing setting
        WebView simulationWebView = isAggressiveClearing
                ? sessionClearingManager.createCleanWebView()
                : new WebView(this);

        // Clear session data if aggressive clearing is on
        if (isAggressiveClearing) {
            sessionClearingManager.clearSessionData(simulationWebView);
        }

        // Start session with custom delay settings
        sessionManager.startSession(
                        targetUrl,
                        iterations,
                        useRandomDeviceProfile,
                        rotateIp,
                        delayMin,
                        delayMax,
                        useWebViewMode) // Pass the WebView mode flag
                .thenRun(() -> {
                    // Update UI when finished
                    runOnUiThread(() -> {
                        binding.btnStart.setEnabled(true);
                        binding.btnPause.setEnabled(true);
                        binding.btnPause.setText("Pause");
                        binding.btnStop.setEnabled(false);
                        binding.tvStatusLabel.setText("Status: Completed");
                        addLog("Simulation completed");
                        timeUpdateHandler.removeCallbacks(timeUpdateRunnable);
                    });
                })
                .exceptionally(throwable -> {
                    // Handle errors
                    runOnUiThread(() -> {
                        binding.btnStart.setEnabled(true);
                        binding.btnPause.setEnabled(true);
                        binding.btnPause.setText("Pause");
                        binding.btnStop.setEnabled(false);
                        binding.tvStatusLabel.setText("Status: Error");
                        addLog("Error: " + throwable.getMessage());
                        timeUpdateHandler.removeCallbacks(timeUpdateRunnable);
                    });
                    return null;
                });

        // Set up distribution listener
        trafficDistributionManager.addListener(new TrafficDistributionManager.DistributionListener() {
            @Override
            public void onDistributionStatusChanged(boolean running, int progress) {
                runOnUiThread(() -> {
                    if (!running && progress >= 100) {
                        // Completed
                        binding.btnStart.setEnabled(true);
                        binding.btnPause.setEnabled(true);
                        binding.btnPause.setText("Pause");
                        binding.btnStop.setEnabled(false);
                        binding.tvStatusLabel.setText("Status: Completed");
                        addLog("Scheduled simulation completed");
                    } else if (!running) {
                        // Stopped
                        binding.btnStart.setEnabled(true);
                        binding.btnPause.setEnabled(true);
                        binding.btnPause.setText("Pause");
                        binding.btnStop.setEnabled(false);
                        binding.tvStatusLabel.setText("Status: Stopped");
                        addLog("Scheduled simulation stopped");
                    }
                });
            }

            @Override
            public void onRequestScheduled(long scheduledTimeMs, int index, int totalRequests) {
                runOnUiThread(() -> {
                    binding.tvProgress.setText("Progress: " + index + "/" + totalRequests);

                    // Update fragment if available
                    if (trafficDistributionFragment != null) {
                        trafficDistributionFragment.updateDistributionStatus(
                                true,
                                (index * 100) / totalRequests,
                                index,
                                totalRequests,
                                trafficDistributionManager.getEstimatedRemainingTimeMs(),
                                trafficDistributionManager.getEstimatedCompletionTimeMs());
                    }
                });
            }
        });

        // Save settings
        preferencesManager.setSimulationRunning(true);
        saveSettings();

        // Log simulation start to file
        if (fileLogger != null) {
            fileLogger.log("Simulation started: " + iterations + " iterations, intervals " + 
                    minInterval + "-" + maxInterval + " sec, IP rotate: " + rotateIp);
        }
    }

    /**
     * Stop the simulation.
     */
    private void stopSimulation() {
        sessionManager.stopSession();

        // Update UI
        binding.btnStart.setEnabled(true);
        binding.btnPause.setEnabled(false);
        binding.btnPause.setText("Pause");
        binding.btnStop.setEnabled(false);
        binding.tvStatusLabel.setText("Status: Stopped");
        addLog("Simulation stopped");
        timeUpdateHandler.removeCallbacks(timeUpdateRunnable);

        // Save settings
        preferencesManager.setSimulationRunning(false);

        // Reset controller state to ensure clean state for next run
        airplaneModeController.resetState();

        // Stop the scheduled distribution if it's running
        if (trafficDistributionManager != null &&
                trafficDistributionManager.isScheduledModeEnabled() &&
                trafficDistributionManager.isRunning()) {
            trafficDistributionManager.stopDistribution();
        }

        // Log simulation stop to file
        if (fileLogger != null) {
            fileLogger.log("Simulation stopped at iteration " + 
                    binding.tvProgress.getText().toString() + ", elapsed time: " + 
                    binding.tvTimeElapsed.getText().toString());
        }
    }

    /**
     * Update UI based on session state.
     */
    private void updateUIBasedOnSessionState() {
        if (preferencesManager.isSimulationRunning()) {
            if (!sessionManager.isRunning()) {
                // Simulation was running but stopped (app restart)
                binding.tvStatusLabel.setText("Status: Stopped (App Restarted)");
                binding.btnStart.setEnabled(true);
                binding.btnPause.setEnabled(false);
                binding.btnStop.setEnabled(false);
                
                // Ask user if they want to restore the session
                askToRestoreSession();
            } else if (sessionManager.isPaused()) {
                // Session is paused
                binding.tvStatusLabel.setText("Status: Paused");
                binding.btnStart.setEnabled(false);
                binding.btnPause.setText("Resume");
                binding.btnPause.setEnabled(true);
                binding.btnStop.setEnabled(true);
            } else {
                // Session is running
                binding.tvStatusLabel.setText("Status: Running");
                binding.btnStart.setEnabled(false);
                binding.btnPause.setText("Pause");
                binding.btnPause.setEnabled(true);
                binding.btnStop.setEnabled(true);
            }
        } else {
            // No simulation running
            binding.tvStatusLabel.setText("Status: Ready");
            binding.btnStart.setEnabled(true);
            binding.btnPause.setEnabled(false);
            binding.btnStop.setEnabled(false);
        }

        // If using scheduled mode, check distribution manager state
        if (trafficDistributionManager != null && 
            trafficDistributionManager.isScheduledModeEnabled()) {
            
            if (trafficDistributionManager.isPaused()) {
                binding.tvStatusLabel.setText("Status: Paused (Scheduled)");
                binding.btnPause.setText("Resume");
            } else if (trafficDistributionManager.isRunning()) {
                binding.tvStatusLabel.setText("Status: Running (Scheduled)");
                binding.btnPause.setText("Pause");
            }
        }
    }

    /**
     * Ask user if they want to restore the previous session.
     */
    private void askToRestoreSession() {
        if (preferencesManager.hasSavedSessionState()) {
            // Show dialog to restore session
            new androidx.appcompat.app.AlertDialog.Builder(this)
                .setTitle("Restore Session")
                .setMessage("A previous session was interrupted. Would you like to restore it?")
                .setPositiveButton("Restore", (dialog, which) -> {
                    restoreSession();
                })
                .setNegativeButton("Start New", (dialog, which) -> {
                    // Clear saved session data
                    preferencesManager.clearSavedSessionState();
                })
                .setCancelable(false)
                .show();
        }
    }

    /**
     * Restore a previous session.
     */
    private void restoreSession() {
        addLog("Restoring previous session...");
        
        // Get saved values before restoration
        int current = preferencesManager.getSavedCurrentIndex();
        int total = preferencesManager.getSavedTotalRequests();
        boolean wasPaused = preferencesManager.wasSavedSessionPaused();
        startTimeMs = preferencesManager.getSavedSessionStartTime();
        
        // Restore pause tracking
        totalPausedTimeMs = preferencesManager.getSavedTotalPausedTime();
        pauseTimeMs = preferencesManager.getSavedPauseStartTime();
        
        // If we're restoring a paused session, update the pause time to now
        // since we don't know how long the app was closed
        if (wasPaused && pauseTimeMs > 0) {
            pauseTimeMs = System.currentTimeMillis();
        }
        
        // Restore session state
        if (sessionManager.restoreSession()) {
            // Update UI state
            runOnUiThread(() -> {
                // Update progress UI
                binding.tvProgress.setText("Progress: " + current + "/" + total);
                
                // Update UI state
                binding.btnStart.setEnabled(false);
                binding.btnPause.setEnabled(true);
                binding.btnStop.setEnabled(true);
                
                if (wasPaused) {
                    binding.tvStatusLabel.setText("Status: Paused (Restored)");
                    binding.btnPause.setText("Resume");
                } else {
                    // Even if the original session wasn't paused, we restore it in paused state
                    // for safety, so the user can explicitly resume when ready
                    binding.tvStatusLabel.setText("Status: Paused (Restored)");
                    binding.btnPause.setText("Resume");
                    sessionManager.pauseSession(); // Ensure it's paused
                }
                
                addLog("Session restored: " + current + "/" + total + " (Paused)");
                
                // Update elapsed time immediately
                if (startTimeMs > 0) {
                    updateElapsedTime();
                    
                    // Calculate estimated time remaining if there's progress
                    if (current > 0) {
                        long elapsedMs = System.currentTimeMillis() - startTimeMs;
                        long avgTimePerIteration = elapsedMs / current;
                        long remainingMs = avgTimePerIteration * (total - current);
                        
                        String remainingTime = formatTime(remainingMs);
                        binding.tvTimeRemaining.setText("Estimated time remaining: " + remainingTime);
                    }
                }
            });
        } else {
            // Failed to restore
            addLog("Failed to restore session");
            binding.tvStatusLabel.setText("Status: Ready");
            binding.btnStart.setEnabled(true);
            binding.btnPause.setEnabled(false);
            binding.btnStop.setEnabled(false);
        }
        
        // If in scheduled mode, try to restore distribution state too
        if (trafficDistributionManager != null && 
            trafficDistributionManager.isScheduledModeEnabled()) {
            
            if (trafficDistributionManager.restoreDistributionState()) {
                addLog("Restored scheduled distribution state");
            }
        }
    }

    /**
     * Pause or resume the simulation based on current state.
     */
    private void pauseOrResumeSimulation() {
        if (sessionManager.isPaused()) {
            // Resume the simulation
            addLog("Resuming simulation");
            
            if (sessionManager.resumeSession()) {
                // Set up progress observer to ensure UI is updated
                sessionManager.setProgressListener((current, total) -> {
                    runOnUiThread(() -> {
                        // Only update if progress has actually changed
                        String currentProgressText = binding.tvProgress.getText().toString();
                        String newProgressText = "Progress: " + current + "/" + total;
                        
                        // Only update if the progress text has actually changed to avoid spurious updates
                        if (!currentProgressText.equals(newProgressText)) {
                            binding.tvProgress.setText(newProgressText);

                            // Update estimated time remaining
                            if (current > 0) {
                                long elapsedMs = System.currentTimeMillis() - startTimeMs - totalPausedTimeMs;
                                if (pauseTimeMs > 0) {
                                    elapsedMs -= (System.currentTimeMillis() - pauseTimeMs);
                                }
                                
                                long avgTimePerIteration = elapsedMs / current;
                                long remainingMs = avgTimePerIteration * (total - current);

                                String remainingTime = formatTime(remainingMs);
                                binding.tvTimeRemaining.setText("Estimated time remaining: " + remainingTime);
                                
                                // Log progress updates at certain intervals
                                if (current % 5 == 0 || current == 1 || current == total) {
                                    addLog("Progress updated: " + current + "/" + total);
                                }
                            }
                        }
                    });
                });
                
                binding.tvStatusLabel.setText("Status: Running");
                binding.btnPause.setText("Pause");
                
                // Calculate and add the paused time
                if (pauseTimeMs > 0) {
                    totalPausedTimeMs += (System.currentTimeMillis() - pauseTimeMs);
                    pauseTimeMs = 0;
                }
                
                // Resume time updates
                timeUpdateHandler.removeCallbacks(timeUpdateRunnable);
                timeUpdateHandler.postDelayed(timeUpdateRunnable, 1000);
                
                // If in scheduled mode, also resume distribution
                if (trafficDistributionManager != null && 
                    trafficDistributionManager.isScheduledModeEnabled() &&
                    trafficDistributionManager.isPaused()) {
                    
                    trafficDistributionManager.resumeDistribution();
                }
                
                // Log resumption to file
                if (fileLogger != null) {
                    fileLogger.log("Simulation resumed at iteration " + 
                            binding.tvProgress.getText().toString() + ", elapsed time: " + 
                            binding.tvTimeElapsed.getText().toString());
                }
            } else {
                // Failed to resume
                addLog("Failed to resume simulation");
            }
        } else {
            // Pause the simulation
            addLog("Pausing simulation");
            sessionManager.pauseSession();
            binding.tvStatusLabel.setText("Status: Paused");
            binding.btnPause.setText("Resume");
            
            // Record the time when paused
            pauseTimeMs = System.currentTimeMillis();
            
            // Final update of elapsed time with current state
            updateElapsedTime();
            
            // If in scheduled mode, also pause distribution
            if (trafficDistributionManager != null && 
                trafficDistributionManager.isScheduledModeEnabled() &&
                trafficDistributionManager.isRunning()) {
                
                trafficDistributionManager.pauseDistribution();
            }
            
            // Log pause to file
            if (fileLogger != null) {
                fileLogger.log("Simulation paused at iteration " + 
                        binding.tvProgress.getText().toString() + ", elapsed time: " + 
                        binding.tvTimeElapsed.getText().toString());
            }
        }
        
        // Save current state for persistence
        saveSettings();
    }

    /**
     * Update elapsed time in UI.
     */
    private void updateElapsedTime() {
        if (startTimeMs > 0) {
            long currentTimeMs = System.currentTimeMillis();
            long elapsedRawMs = currentTimeMs - startTimeMs;
            
            // Subtract paused time for accurate elapsed time
            long actualElapsedMs = elapsedRawMs - totalPausedTimeMs;
            
            // If currently paused, don't include time since pause
            if (sessionManager.isPaused() && pauseTimeMs > 0) {
                actualElapsedMs -= (currentTimeMs - pauseTimeMs);
            }
            
            binding.tvTimeElapsed.setText("Time elapsed: " + formatTime(actualElapsedMs));
            
            // Log time updates periodically (once per minute)
            if (actualElapsedMs / 60000 > 0 && (actualElapsedMs / 60000) % 1 == 0) {
                Logger.d("MainActivity", "Time elapsed: " + formatTime(actualElapsedMs));
            }
        }
    }

    /**
     * Update network statistics display
     */
    private void updateNetworkStats() {
        if (networkStatsTracker == null) return;

        NetworkSession session = networkStatsTracker.getCurrentSession();
        if (session != null) {
            onSessionDataChanged(session);
        }
    }

    /**
     * Handle changes to network statistics
     */
    private void onNetworkStatsChanged(NetworkStats stats) {
        if (stats == null) return;

        // Update speed gauge
        if (networkSpeedView != null) {
            networkSpeedView.addNetworkStats(stats);
        }

        // Update speed text views
        runOnUiThread(() -> {
            TextView tvDownloadSpeed = findViewById(R.id.tvDownloadSpeed);
            TextView tvUploadSpeed = findViewById(R.id.tvUploadSpeed);

            if (tvDownloadSpeed != null) {
                tvDownloadSpeed.setText(NetworkStatsTracker.formatSpeed(stats.getDownloadSpeed()));
            }

            if (tvUploadSpeed != null) {
                tvUploadSpeed.setText(NetworkStatsTracker.formatSpeed(stats.getUploadSpeed()));
            }
        });
    }

    /**
     * Handle changes to network session data
     */
    private void onSessionDataChanged(NetworkSession session) {
        if (session == null) return;

        runOnUiThread(() -> {
            // Update totals
            TextView tvDownloadTotal = findViewById(R.id.tvDownloadTotal);
            TextView tvUploadTotal = findViewById(R.id.tvUploadTotal);
            TextView tvTotalData = findViewById(R.id.tvTotalData);
            TextView tvRequestCount = findViewById(R.id.tvRequestCount);
            TextView tvSessionDuration = findViewById(R.id.tvSessionDuration);
            TextView tvNetworkStatus = findViewById(R.id.tvNetworkStatus);

            if (tvDownloadTotal != null) {
                tvDownloadTotal.setText(NetworkStatsTracker.formatBytes(session.getTotalBytesDownloaded()));
            }

            if (tvUploadTotal != null) {
                tvUploadTotal.setText(NetworkStatsTracker.formatBytes(session.getTotalBytesUploaded()));
            }

            if (tvTotalData != null) {
                tvTotalData.setText(NetworkStatsTracker.formatBytes(session.getTotalBytes()));
            }

            if (tvRequestCount != null) {
                tvRequestCount.setText("Requests: " + session.getRequestCount());
            }

            if (tvSessionDuration != null) {
                long durationSec = session.getDurationMs() / 1000;
                String durationText = String.format("%02d:%02d", durationSec / 60, durationSec % 60);
                tvSessionDuration.setText("Duration: " + durationText);
            }

            if (tvNetworkStatus != null) {
                tvNetworkStatus.setText("Monitoring: " + (session.isActive() ? "On" : "Off"));
                tvNetworkStatus.setTextColor(getResources().getColor(
                        session.isActive() ? R.color.status_success : R.color.medium_gray));
            }
        });
    }

    /**
     * Method to show airplane mode operation status.
     */
    private void showAirplaneModeOperation(boolean isOperating) {
        runOnUiThread(() -> {
            if (isOperating) {
                binding.tvStatusLabel.setText("Status: Rotating IP...");
                addLog("IP rotation in progress");
                // Could add a progress indicator here if desired
            } else {
                binding.tvStatusLabel.setText("Status: Running");
                addLog("IP rotation completed");
            }
        });
    }

    /**
     * Add log message to the log view
     * @param message Log message
     */
    private void addLog(String message) {
        Logger.i(TAG, message);
        
        // Also log to file if available
        if (fileLogger != null) {
            fileLogger.log(message);
        }
        
        // Update UI log
        String currentText = binding.tvLogs.getText().toString();
        String newText = message + "\n" + currentText;
        binding.tvLogs.setText(newText);
    }

    /**
     * Format time in milliseconds to human-readable string.
     * @param timeMs Time in milliseconds
     * @return Formatted time string (HH:MM:SS)
     */
    private String formatTime(long timeMs) {
        long seconds = (timeMs / 1000) % 60;
        long minutes = (timeMs / (1000 * 60)) % 60;
        long hours = (timeMs / (1000 * 60 * 60));

        return String.format("%02d:%02d:%02d", hours, minutes, seconds);
    }

    /**
     * Clear all logs.
     */
    private void clearLogs() {
        binding.tvLogs.setText("");
    }

    /**
     * Show dialog for exporting the current configuration
     */
    private void showExportConfigDialog() {
        View dialogView = getLayoutInflater().inflate(R.layout.dialog_export_config, null);
        
        // Get current date as default config name
        String defaultConfigName = "config_" + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        TextInputEditText etConfigName = dialogView.findViewById(R.id.etConfigName);
        etConfigName.setText(defaultConfigName);
        
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setView(dialogView)
                .setPositiveButton("Export", null) // We'll set the listener later
                .setNegativeButton("Cancel", (dialog, which) -> dialog.dismiss());
        
        AlertDialog dialog = builder.create();
        
        // Set click listener after dialog is shown to prevent automatic dismissal
        dialog.setOnShowListener(dialogInterface -> {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                TextInputEditText etConfigDesc = dialogView.findViewById(R.id.etConfigDescription);
                String configName = etConfigName.getText().toString().trim();
                String configDesc = etConfigDesc.getText().toString().trim();
                
                if (configName.isEmpty()) {
                    etConfigName.setError("Configuration name is required");
                    return;
                }
                
                exportConfiguration(configName, configDesc);
                dialog.dismiss();
            });
        });
        
        dialog.show();
    }
    
    /**
     * Export the current configuration to a file
     * @param configName Configuration name
     * @param description Configuration description
     */
    private void exportConfiguration(String configName, String description) {
        // Save current UI values to preferences before exporting
        saveCurrentUIState();
        
        // Now create and export the configuration
        AppConfiguration config = configurationManager.createConfigurationFromCurrentSettings(configName, description);
        File configFile = configurationManager.exportConfiguration(config);
        
        if (configFile != null) {
            Toast.makeText(this, "Configuration exported to: " + configFile.getName(), Toast.LENGTH_LONG).show();
            addLog("Configuration exported to: " + configFile.getAbsolutePath());
        } else {
            Toast.makeText(this, "Failed to export configuration", Toast.LENGTH_SHORT).show();
            addLog("Failed to export configuration");
        }
    }
    
    /**
     * Save the current UI state to preferences
     */
    private void saveCurrentUIState() {
        try {
            // Read values directly from UI
            String targetUrl = binding.etTargetUrl.getText().toString().trim();
            if (!targetUrl.isEmpty()) {
                preferencesManager.setTargetUrl(targetUrl);
            }

            int minInterval = Integer.parseInt(binding.etMinInterval.getText().toString());
            preferencesManager.setMinInterval(minInterval);

            int maxInterval = Integer.parseInt(binding.etMaxInterval.getText().toString());
            preferencesManager.setMaxInterval(maxInterval);

            int iterations = Integer.parseInt(binding.etIterations.getText().toString());
            preferencesManager.setIterations(iterations);

            // Save custom delay settings
            int delayMin = Integer.parseInt(binding.etDelayMin.getText().toString());
            int delayMax = Integer.parseInt(binding.etDelayMax.getText().toString());
            preferencesManager.setInt(PREF_DELAY_MIN, delayMin);
            preferencesManager.setInt(PREF_DELAY_MAX, delayMax);

            // Save airplane mode delay
            int airplaneModeDelay = Integer.parseInt(binding.etAirplaneModeDelay.getText().toString());
            preferencesManager.setAirplaneModeDelay(airplaneModeDelay);

            // Save toggle states
            SwitchMaterial switchUseWebView = findViewById(R.id.switchUseWebView);
            if (switchUseWebView != null) {
                preferencesManager.setUseWebViewMode(switchUseWebView.isChecked());
            }

            SwitchMaterial switchAggressiveSessionClearing = findViewById(R.id.switchAggressiveSessionClearing);
            if (switchAggressiveSessionClearing != null) {
                preferencesManager.setAggressiveSessionClearingEnabled(switchAggressiveSessionClearing.isChecked());
            }

            SwitchMaterial switchNewWebViewPerRequest = findViewById(R.id.switchNewWebViewPerRequest);
            if (switchNewWebViewPerRequest != null) {
                preferencesManager.setNewWebViewPerRequestEnabled(switchNewWebViewPerRequest.isChecked());
            }

            SwitchMaterial switchHandleRedirects = findViewById(R.id.switchHandleRedirects);
            if (switchHandleRedirects != null) {
                preferencesManager.setHandleMarketingRedirectsEnabled(switchHandleRedirects.isChecked());
            }
            
            SwitchMaterial switchRotateIp = findViewById(R.id.switchRotateIp);
            if (switchRotateIp != null) {
                preferencesManager.setBoolean("rotate_ip", switchRotateIp.isChecked());
            }
            
            SwitchMaterial switchRandomDevices = findViewById(R.id.switchRandomDevices);
            if (switchRandomDevices != null) {
                preferencesManager.setBoolean("use_random_device_profile", switchRandomDevices.isChecked());
            }
            
            // Also save any traffic distribution settings - use values already in preferences
            // since TrafficDistributionManager doesn't expose getters
            if (trafficDistributionManager != null) {
                // Keep scheduled mode state which is available
                preferencesManager.setScheduledModeEnabled(trafficDistributionManager.isScheduledModeEnabled());
                
                // Distribution pattern, duration and other settings are already in preferences
                // so we don't need to update them here
            }

            // Save config expansion state
            preferencesManager.setBoolean("config_expanded", isConfigExpanded);

        } catch (NumberFormatException e) {
            // Just log the error but continue with valid values
            Logger.e(TAG, "Error parsing numbers during UI state save", e);
        }
    }
    
    /**
     * Show dialog for importing a configuration
     */
    private void showImportConfigDialog() {
        View dialogView = getLayoutInflater().inflate(R.layout.dialog_import_config, null);
        RecyclerView rvConfigList = dialogView.findViewById(R.id.rvConfigList);
        TextView tvNoConfigs = dialogView.findViewById(R.id.tvNoConfigs);
        
        List<File> configFiles = configurationManager.getSavedConfigurations();
        
        if (configFiles.isEmpty()) {
            tvNoConfigs.setVisibility(View.VISIBLE);
            rvConfigList.setVisibility(View.GONE);
        } else {
            tvNoConfigs.setVisibility(View.GONE);
            rvConfigList.setVisibility(View.VISIBLE);
            
            ConfigFileAdapter adapter = new ConfigFileAdapter(configFiles, this::importConfigurationFromFile);
            rvConfigList.setLayoutManager(new LinearLayoutManager(this));
            rvConfigList.setAdapter(adapter);
        }
        
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setView(dialogView)
                .setNegativeButton("Cancel", (dialog, which) -> dialog.dismiss());
        
        if (!configFiles.isEmpty()) {
            builder.setTitle("Select Configuration");
        }
        
        builder.create().show();
    }
    
    /**
     * Import a configuration from a file
     * @param configFile Configuration file
     */
    private void importConfigurationFromFile(File configFile) {
        AppConfiguration config = configurationManager.importConfiguration(configFile);
        
        if (config != null) {
            // Confirm import
            new AlertDialog.Builder(this)
                    .setTitle("Import Configuration")
                    .setMessage("Are you sure you want to import configuration '" + config.getConfigName() + "'? " +
                            "This will overwrite current settings.")
                    .setPositiveButton("Import", (dialog, which) -> {
                        configurationManager.applyConfigurationToSettings(config);
                        loadSettings(); // Reload UI with new settings
                        Toast.makeText(this, "Configuration imported successfully", Toast.LENGTH_SHORT).show();
                        addLog("Configuration imported from: " + configFile.getName());
                    })
                    .setNegativeButton("Cancel", (dialog, which) -> dialog.dismiss())
                    .create()
                    .show();
        } else {
            Toast.makeText(this, "Failed to import configuration", Toast.LENGTH_SHORT).show();
            addLog("Failed to import configuration from: " + configFile.getName());
        }
    }

    /**
     * Initialize file logger
     */
    private void initializeFileLogger() {
        // Generate a unique session ID if not already set
        if (preferencesManager.getBoolean("is_first_run", true)) {
            String sessionId = fileLogger.startNewSessionLog("App first launch");
            preferencesManager.setBoolean("is_first_run", false);
            preferencesManager.setString("current_session_id", sessionId);
            addLog("File logger initialized with session: " + sessionId);
        } else {
            // If we're coming from a saved state, continue with the same session
            if (sessionManager.isRunning()) {
                String savedSessionId = preferencesManager.getString("current_session_id", null);
                if (savedSessionId != null) {
                    fileLogger.setCurrentSessionId(savedSessionId);
                    fileLogger.log("Session restored from saved state");
                    addLog("Continuing with session: " + savedSessionId);
                } else {
                    String sessionId = fileLogger.startNewSessionLog("New session (restored state)");
                    preferencesManager.setString("current_session_id", sessionId);
                    addLog("Created new session for restored state: " + sessionId);
                }
            } else {
                // Otherwise start a new session
                String sessionId = fileLogger.startNewSessionLog("New app session");
                preferencesManager.setString("current_session_id", sessionId);
                addLog("Started new session: " + sessionId);
            }
        }
    }

    /**
     * Open the log viewer activity
     */
    private void openLogViewer() {
        Intent intent = new Intent(this, LogViewerActivity.class);
        startActivity(intent);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        
        // Handle remote command intents
        if (intent != null) {
            if (CommandExecutor.ACTION_REMOTE_COMMAND.equals(intent.getAction())) {
                String command = intent.getStringExtra(CommandExecutor.EXTRA_COMMAND);
                if (command != null) {
                    handleRemoteCommand(command);
                }
            } else if ("com.example.imtbf2.REFRESH_UI".equals(intent.getAction())) {
                // Handle direct intents for UI refresh
                Logger.i(TAG, "Received direct UI refresh intent");
                reloadSettingsFromPreferences();
                Toast.makeText(this, "Settings updated", Toast.LENGTH_SHORT).show();
            }
        }
    }
    
    /**
     * Handle remote commands received from ADB intent broadcasts
     * @param command The command to execute
     */
    private void handleRemoteCommand(String command) {
        Logger.i(TAG, "Received remote command: " + command);
        
        switch (command) {
            case CommandExecutor.COMMAND_START:
                if (validateInputs()) {
                    runOnUiThread(() -> {
                        addLog("Remote command: Start simulation");
                        startSimulation();
                    });
                } else {
                    addLog("Remote command START failed: Invalid input values");
                }
                break;
                
            case CommandExecutor.COMMAND_PAUSE:
                if (sessionManager.isRunning() && !sessionManager.isPaused()) {
                    runOnUiThread(() -> {
                        addLog("Remote command: Pause simulation");
                        pauseOrResumeSimulation();
                    });
                } else {
                    addLog("Remote command PAUSE failed: Simulation not running or already paused");
                }
                break;
                
            case CommandExecutor.COMMAND_RESUME:
                if (sessionManager.isRunning() && sessionManager.isPaused()) {
                    runOnUiThread(() -> {
                        addLog("Remote command: Resume simulation");
                        pauseOrResumeSimulation();
                    });
                } else {
                    addLog("Remote command RESUME failed: Simulation not running or not paused");
                }
                break;
                
            case CommandExecutor.COMMAND_STOP:
                if (sessionManager.isRunning()) {
                    runOnUiThread(() -> {
                        addLog("Remote command: Stop simulation");
                        stopSimulation();
                    });
                } else {
                    addLog("Remote command STOP failed: Simulation not running");
                }
                break;
                
            default:
                addLog("Unknown remote command: " + command);
                break;
        }
    }

    /**
     * Reload all settings from preferences and update the UI accordingly.
     * This is useful when settings are changed via ADB commands or other external methods.
     */
    private void reloadSettingsFromPreferences() {
        Logger.i(TAG, "Reloading settings from preferences");
        
        // Load settings from preferences
        binding.etTargetUrl.setText(preferencesManager.getTargetUrl());
        binding.etMinInterval.setText(String.valueOf(preferencesManager.getMinInterval()));
        binding.etMaxInterval.setText(String.valueOf(preferencesManager.getMaxInterval()));
        binding.etIterations.setText(String.valueOf(preferencesManager.getIterations()));

        // Load custom delay settings
        binding.etDelayMin.setText(String.valueOf(
                preferencesManager.getInt(PREF_DELAY_MIN, DEFAULT_DELAY_MIN)));
        binding.etDelayMax.setText(String.valueOf(
                preferencesManager.getInt(PREF_DELAY_MAX, DEFAULT_DELAY_MAX)));

        // Load airplane mode delay
        binding.etAirplaneModeDelay.setText(String.valueOf(
                preferencesManager.getAirplaneModeDelay()));

        // Load WebView mode setting
        useWebViewMode = preferencesManager.getUseWebViewMode();
        SwitchMaterial switchUseWebView = findViewById(R.id.switchUseWebView);
        if (switchUseWebView != null) {
            switchUseWebView.setChecked(useWebViewMode);
        }

        // Update WebView visibility
        View cardWebView = findViewById(R.id.cardWebView);
        if (cardWebView != null) {
            cardWebView.setVisibility(useWebViewMode ? View.VISIBLE : View.GONE);
        }

        // Load other switch states
        SwitchMaterial switchAggressiveSessionClearing =
                findViewById(R.id.switchAggressiveSessionClearing);
        if (switchAggressiveSessionClearing != null) {
            switchAggressiveSessionClearing.setChecked(
                    preferencesManager.isAggressiveSessionClearingEnabled()
            );
        }

        SwitchMaterial switchNewWebViewPerRequest = findViewById(R.id.switchNewWebViewPerRequest);
        if (switchNewWebViewPerRequest != null) {
            switchNewWebViewPerRequest.setChecked(
                    preferencesManager.isNewWebViewPerRequestEnabled()
            );
        }

        SwitchMaterial switchHandleRedirects = findViewById(R.id.switchHandleRedirects);
        if (switchHandleRedirects != null) {
            switchHandleRedirects.setChecked(
                    preferencesManager.isHandleMarketingRedirectsEnabled()
            );
        }
        
        SwitchMaterial switchRotateIp = findViewById(R.id.switchRotateIp);
        if (switchRotateIp != null) {
            switchRotateIp.setChecked(
                    preferencesManager.getBoolean("rotate_ip", true)
            );
        }
        
        SwitchMaterial switchRandomDevices = findViewById(R.id.switchRandomDevices);
        if (switchRandomDevices != null) {
            switchRandomDevices.setChecked(
                    preferencesManager.getBoolean("use_random_device_profile", true)
            );
        }
        
        // Update timingDistributor if needed
        if (timingDistributor != null) {
            timingDistributor.setDelayRange(
                preferencesManager.getMinInterval() * 1000,  // Convert to ms
                preferencesManager.getMaxInterval() * 1000   // Convert to ms
            );
        }
        
        // Update controller settings if needed
        if (airplaneModeController != null) {
            airplaneModeController.setDelay(preferencesManager.getAirplaneModeDelay());
        }
        
        if (webViewRequestManager != null) {
            webViewRequestManager.setUseNewWebViewPerRequest(
                preferencesManager.isNewWebViewPerRequestEnabled()
            );
            webViewRequestManager.setHandleMetapicRedirects(
                preferencesManager.isHandleMarketingRedirectsEnabled()
            );
        }
        
        // Log the reload
        Logger.i(TAG, "Settings reloaded from preferences");
        addLog("Settings refreshed from preferences");
    }
}