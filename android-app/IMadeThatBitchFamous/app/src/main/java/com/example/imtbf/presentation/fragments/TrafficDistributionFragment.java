package com.example.imtbf.presentation.fragments;

import android.content.Context;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.imtbf.InstagramTrafficSimulatorApp;
import com.example.imtbf.R;
import com.example.imtbf.data.local.PreferencesManager;
import com.example.imtbf.domain.simulation.DistributionPattern;
import com.example.imtbf.utils.Logger;
import com.google.android.material.slider.Slider;
import com.google.android.material.switchmaterial.SwitchMaterial;
import com.example.imtbf.domain.simulation.DistributionPattern;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class TrafficDistributionFragment extends Fragment {
    private static final String TAG = "TrafficDistFragment";

    private PreferencesManager preferencesManager;

    // UI Components
    private SwitchMaterial switchScheduledMode;
    private LinearLayout layoutDistributionSettings;
    private Spinner spinnerDistributionPattern;
    private Slider sliderDurationHours;
    private TextView tvDurationValue;
    private LinearLayout layoutPeakHoursSettings;
    private Spinner spinnerPeakHourStart;
    private Spinner spinnerPeakHourEnd;
    private Slider sliderPeakWeight;
    private TextView tvPeakWeightValue;
    private FrameLayout chartContainer;
    private LinearLayout layoutDistributionStatus;
    private ProgressBar progressDistribution;
    private TextView tvDistributionProgress;
    private TextView tvTimeRemaining;
    private TextView tvCompletionTime;

    // Callback interface for fragment interactions
    public interface TrafficDistributionListener {
        void onScheduledModeChanged(boolean enabled);
        void onDistributionSettingsChanged(DistributionPattern pattern, int durationHours,
                                           int peakHourStart, int peakHourEnd, float peakWeight);
    }

    private TrafficDistributionListener listener;

    @Override
    public void onAttach(@NonNull Context context) {
        super.onAttach(context);

        // Try to get the listener from the parent activity
        if (context instanceof TrafficDistributionListener) {
            listener = (TrafficDistributionListener) context;
        }

        // Get preferences manager
        if (context.getApplicationContext() instanceof InstagramTrafficSimulatorApp) {
            preferencesManager = ((InstagramTrafficSimulatorApp) context.getApplicationContext())
                    .getPreferencesManager();
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.traffic_distribution_layout, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        // Initialize UI components
        initializeViews(view);

        // Load saved settings
        loadSettings();

        // Set up listeners
        setupListeners();
    }

    /**
     * Initialize UI views.
     */
    private void initializeViews(View view) {
        switchScheduledMode = view.findViewById(R.id.switchScheduledMode);
        layoutDistributionSettings = view.findViewById(R.id.layoutDistributionSettings);
        spinnerDistributionPattern = view.findViewById(R.id.spinnerDistributionPattern);
        sliderDurationHours = view.findViewById(R.id.sliderDurationHours);
        tvDurationValue = view.findViewById(R.id.tvDurationValue);
        layoutPeakHoursSettings = view.findViewById(R.id.layoutPeakHoursSettings);
        spinnerPeakHourStart = view.findViewById(R.id.spinnerPeakHourStart);
        spinnerPeakHourEnd = view.findViewById(R.id.spinnerPeakHourEnd);
        sliderPeakWeight = view.findViewById(R.id.sliderPeakWeight);
        tvPeakWeightValue = view.findViewById(R.id.tvPeakWeightValue);
        chartContainer = view.findViewById(R.id.chartContainer);
        layoutDistributionStatus = view.findViewById(R.id.layoutDistributionStatus);
        progressDistribution = view.findViewById(R.id.progressDistribution);
        tvDistributionProgress = view.findViewById(R.id.tvDistributionProgress);
        tvTimeRemaining = view.findViewById(R.id.tvTimeRemaining);
        tvCompletionTime = view.findViewById(R.id.tvCompletionTime);

        // Set up spinners
        setupSpinners();
    }

    /**
     * Set up spinner adapters.
     */
    private void setupSpinners() {
        // Distribution pattern spinner
        ArrayAdapter<CharSequence> patternAdapter = ArrayAdapter.createFromResource(
                requireContext(),
                R.array.distribution_patterns,
                android.R.layout.simple_spinner_item
        );
        patternAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinnerDistributionPattern.setAdapter(patternAdapter);

        // Hour spinners
        String[] hours = new String[24];
        for (int i = 0; i < 24; i++) {
            hours[i] = String.format(Locale.getDefault(), "%02d:00", i);
        }

        ArrayAdapter<String> hoursAdapter = new ArrayAdapter<>(
                requireContext(),
                android.R.layout.simple_spinner_item,
                hours
        );
        hoursAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

        spinnerPeakHourStart.setAdapter(hoursAdapter);
        spinnerPeakHourEnd.setAdapter(hoursAdapter);
    }

    /**
     * Load saved settings from preferences.
     */
    private void loadSettings() {
        if (preferencesManager != null) {
            // Load scheduled mode
            boolean scheduledMode = preferencesManager.isScheduledModeEnabled();
            switchScheduledMode.setChecked(scheduledMode);
            layoutDistributionSettings.setVisibility(scheduledMode ? View.VISIBLE : View.GONE);

            // Load distribution pattern
            String patternName = preferencesManager.getDistributionPattern();
            DistributionPattern pattern = DistributionPattern.fromString(patternName);
            int patternIndex = pattern.ordinal();
            if (patternIndex >= 0 && patternIndex < spinnerDistributionPattern.getAdapter().getCount()) {
                spinnerDistributionPattern.setSelection(patternIndex);
            }

            // Show/hide peak hours settings
            boolean isPeakHoursPattern = pattern == DistributionPattern.PEAK_HOURS;
            layoutPeakHoursSettings.setVisibility(isPeakHoursPattern ? View.VISIBLE : View.GONE);

            // Load duration
            int durationHours = preferencesManager.getDistributionDurationHours();
            sliderDurationHours.setValue(durationHours);
            tvDurationValue.setText(getString(R.string.hours_format, durationHours));

            // Load peak hours settings
            int peakStart = preferencesManager.getPeakHourStart();
            int peakEnd = preferencesManager.getPeakHourEnd();
            float peakWeight = preferencesManager.getPeakTrafficWeight();

            spinnerPeakHourStart.setSelection(peakStart);
            spinnerPeakHourEnd.setSelection(peakEnd);
            sliderPeakWeight.setValue(peakWeight);
            int weightPercent = (int) (peakWeight * 100);
            tvPeakWeightValue.setText(getString(R.string.percent_format, weightPercent));
        }
    }

    /**
     * Set up UI listeners.
     */
    private void setupListeners() {
        // Scheduled mode switch
        switchScheduledMode.setOnCheckedChangeListener((buttonView, isChecked) -> {
            layoutDistributionSettings.setVisibility(isChecked ? View.VISIBLE : View.GONE);

            // Save preference
            if (preferencesManager != null) {
                preferencesManager.setScheduledModeEnabled(isChecked);
            }

            // Notify listener
            if (listener != null) {
                listener.onScheduledModeChanged(isChecked);
            }

            Logger.i(TAG, "Scheduled mode " + (isChecked ? "enabled" : "disabled"));
        });

        // Distribution pattern spinner
        spinnerDistributionPattern.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // Map position to pattern
                DistributionPattern pattern = DistributionPattern.values()[position];

                // Save preference
                if (preferencesManager != null) {
                    preferencesManager.setDistributionPattern(pattern.name());
                }

                // Show/hide peak hours settings
                boolean isPeakHoursPattern = pattern == DistributionPattern.PEAK_HOURS;
                layoutPeakHoursSettings.setVisibility(isPeakHoursPattern ? View.VISIBLE : View.GONE);

                // Notify settings changed
                notifySettingsChanged();

                Logger.d(TAG, "Selected distribution pattern: " + pattern.getDisplayName());
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // Not used
            }
        });

        // Duration slider
        sliderDurationHours.addOnChangeListener((slider, value, fromUser) -> {
            int hours = (int) value;
            tvDurationValue.setText(getString(R.string.hours_format, hours));

            if (fromUser && preferencesManager != null) {
                preferencesManager.setDistributionDurationHours(hours);
            }

            if (fromUser) {
                notifySettingsChanged();
                Logger.d(TAG, "Set distribution duration: " + hours + " hours");
            }
        });

        // Peak hour start spinner
        spinnerPeakHourStart.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (preferencesManager != null) {
                    preferencesManager.setPeakHourStart(position);
                }
                notifySettingsChanged();
                Logger.d(TAG, "Set peak hour start: " + position + ":00");
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // Not used
            }
        });

        // Peak hour end spinner
        spinnerPeakHourEnd.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (preferencesManager != null) {
                    preferencesManager.setPeakHourEnd(position);
                }
                notifySettingsChanged();
                Logger.d(TAG, "Set peak hour end: " + position + ":00");
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // Not used
            }
        });

        // Peak weight slider
        sliderPeakWeight.addOnChangeListener((slider, value, fromUser) -> {
            int weightPercent = (int) (value * 100);
            tvPeakWeightValue.setText(getString(R.string.percent_format, weightPercent));

            if (fromUser && preferencesManager != null) {
                preferencesManager.setPeakTrafficWeight(value);
            }

            if (fromUser) {
                notifySettingsChanged();
                Logger.d(TAG, "Set peak traffic weight: " + weightPercent + "%");
            }
        });
    }

    /**
     * Notify the listener that distribution settings have changed.
     */
    private void notifySettingsChanged() {
        if (listener != null) {
            // Get current values
            DistributionPattern pattern = DistributionPattern.values()[
                    spinnerDistributionPattern.getSelectedItemPosition()];
            int durationHours = (int) sliderDurationHours.getValue();
            int peakHourStart = spinnerPeakHourStart.getSelectedItemPosition();
            int peakHourEnd = spinnerPeakHourEnd.getSelectedItemPosition();
            float peakWeight = sliderPeakWeight.getValue();

            // Notify listener
            listener.onDistributionSettingsChanged(
                    pattern, durationHours, peakHourStart, peakHourEnd, peakWeight);
        }
    }

    /**
     * Update the distribution status UI.
     * @param running Whether distribution is running
     * @param progress Current progress (0-100)
     * @param currentRequest Current request index
     * @param totalRequests Total number of requests
     * @param remainingTimeMs Remaining time in milliseconds
     * @param completionTimeMs Completion time in milliseconds since epoch
     */
    public void updateDistributionStatus(boolean running, int progress, int currentRequest,
                                         int totalRequests, long remainingTimeMs, long completionTimeMs) {
        if (getActivity() == null || !isAdded()) {
            return;
        }

        getActivity().runOnUiThread(() -> {
            // Show status section if scheduled mode is enabled
            layoutDistributionStatus.setVisibility(
                    switchScheduledMode.isChecked() ? View.VISIBLE : View.GONE);

            // Update progress
            progressDistribution.setProgress(progress);
            tvDistributionProgress.setText(getString(
                    R.string.progress_format, currentRequest, totalRequests));

            // Update time remaining
            String remainingTime = formatDuration(remainingTimeMs);
            tvTimeRemaining.setText(getString(R.string.time_remaining, remainingTime));

            // Update completion time
            SimpleDateFormat sdf = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());
            String completionTime = sdf.format(new Date(completionTimeMs));
            tvCompletionTime.setText(getString(R.string.estimated_completion, completionTime));
        });
    }

    /**
     * Format duration in milliseconds to "HH:mm:ss" format.
     * @param durationMs Duration in milliseconds
     * @return Formatted duration string
     */
    private String formatDuration(long durationMs) {
        long seconds = (durationMs / 1000) % 60;
        long minutes = (durationMs / (1000 * 60)) % 60;
        long hours = durationMs / (1000 * 60 * 60);
        return String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, minutes, seconds);
    }
}