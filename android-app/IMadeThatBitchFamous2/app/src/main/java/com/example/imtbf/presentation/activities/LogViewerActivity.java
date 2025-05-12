package com.example.imtbf2.presentation.activities;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;

import com.example.imtbf2.R;
import com.example.imtbf2.utils.FileLogger;
import com.google.android.material.textfield.TextInputEditText;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * Activity for viewing log files
 */
public class LogViewerActivity extends AppCompatActivity {

    private Spinner spinnerLogFiles;
    private TextView tvLogContent;
    private Button btnRefresh;
    private Button btnShare;
    private Button btnClearLog;
    private TextInputEditText etLogFilter;
    
    private FileLogger fileLogger;
    private File[] logFiles;
    private String currentLogContent = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_log_viewer);
        
        // Enable back button in action bar
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle("Log Viewer");
        }
        
        // Initialize components
        fileLogger = FileLogger.getInstance(getApplicationContext());
        initializeViews();
        setupListeners();
        loadLogFiles();
    }
    
    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            finish();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
    
    private void initializeViews() {
        spinnerLogFiles = findViewById(R.id.spinnerLogFiles);
        tvLogContent = findViewById(R.id.tvLogContent);
        btnRefresh = findViewById(R.id.btnRefresh);
        btnShare = findViewById(R.id.btnShare);
        btnClearLog = findViewById(R.id.btnClearLog);
        etLogFilter = findViewById(R.id.etLogFilter);
    }
    
    private void setupListeners() {
        btnRefresh.setOnClickListener(v -> loadLogFiles());
        
        btnShare.setOnClickListener(v -> shareCurrentLog());
        
        btnClearLog.setOnClickListener(v -> {
            if (logFiles != null && logFiles.length > 0 && spinnerLogFiles.getSelectedItemPosition() >= 0) {
                confirmClearLog(logFiles[spinnerLogFiles.getSelectedItemPosition()]);
            } else {
                Toast.makeText(this, "No log file selected", Toast.LENGTH_SHORT).show();
            }
        });
        
        spinnerLogFiles.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (logFiles != null && position < logFiles.length) {
                    loadLogContent(logFiles[position]);
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                tvLogContent.setText("");
            }
        });
        
        etLogFilter.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                filterLogContent(s.toString());
            }
        });
    }
    
    private void loadLogFiles() {
        logFiles = fileLogger.getLogFiles();
        
        if (logFiles == null || logFiles.length == 0) {
            Toast.makeText(this, "No log files found", Toast.LENGTH_SHORT).show();
            tvLogContent.setText("No log files available");
            
            // Set empty adapter
            spinnerLogFiles.setAdapter(new ArrayAdapter<>(this, 
                    android.R.layout.simple_spinner_dropdown_item, 
                    new String[]{"No logs available"}));
            
            btnShare.setEnabled(false);
            btnClearLog.setEnabled(false);
            return;
        }
        
        // Sort logs by last modified date (newest first)
        Arrays.sort(logFiles, Comparator.comparing(File::lastModified).reversed());
        
        // Create file names for spinner
        List<String> fileNames = new ArrayList<>();
        for (File file : logFiles) {
            fileNames.add(file.getName());
        }
        
        // Set up adapter
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, 
                android.R.layout.simple_spinner_dropdown_item, 
                fileNames);
        
        spinnerLogFiles.setAdapter(adapter);
        
        // Load the first log by default
        if (logFiles.length > 0) {
            spinnerLogFiles.setSelection(0);
            loadLogContent(logFiles[0]);
            btnShare.setEnabled(true);
            btnClearLog.setEnabled(true);
        }
    }
    
    private void loadLogContent(File logFile) {
        try (BufferedReader reader = new BufferedReader(new FileReader(logFile))) {
            StringBuilder content = new StringBuilder();
            String line;
            
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            
            currentLogContent = content.toString();
            
            // Apply filter if exists
            String filter = etLogFilter.getText().toString().trim();
            if (!filter.isEmpty()) {
                filterLogContent(filter);
            } else {
                tvLogContent.setText(currentLogContent);
            }
            
        } catch (IOException e) {
            Toast.makeText(this, "Error reading log file", Toast.LENGTH_SHORT).show();
            tvLogContent.setText("Error reading log file: " + e.getMessage());
        }
    }
    
    private void filterLogContent(String filter) {
        if (filter.isEmpty()) {
            tvLogContent.setText(currentLogContent);
            return;
        }
        
        String filterLowerCase = filter.toLowerCase();
        StringBuilder filteredContent = new StringBuilder();
        
        String[] lines = currentLogContent.split("\n");
        for (String line : lines) {
            if (line.toLowerCase().contains(filterLowerCase)) {
                filteredContent.append(line).append("\n");
            }
        }
        
        if (filteredContent.length() == 0) {
            tvLogContent.setText("No matching log entries found");
        } else {
            tvLogContent.setText(filteredContent.toString());
        }
    }
    
    private void shareCurrentLog() {
        if (logFiles == null || logFiles.length == 0 || spinnerLogFiles.getSelectedItemPosition() < 0) {
            Toast.makeText(this, "No log file to share", Toast.LENGTH_SHORT).show();
            return;
        }
        
        File logFile = logFiles[spinnerLogFiles.getSelectedItemPosition()];
        
        // Create URI using FileProvider
        Uri fileUri = FileProvider.getUriForFile(this,
                getApplicationContext().getPackageName() + ".fileprovider", logFile);
        
        // Create share intent
        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.setType("text/plain");
        shareIntent.putExtra(Intent.EXTRA_STREAM, fileUri);
        shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        
        // Start the share activity
        startActivity(Intent.createChooser(shareIntent, "Share Log File"));
    }
    
    private void confirmClearLog(File logFile) {
        new AlertDialog.Builder(this)
                .setTitle("Clear Log")
                .setMessage("Are you sure you want to clear this log? This action cannot be undone.")
                .setPositiveButton("Clear", (dialog, which) -> clearLog(logFile))
                .setNegativeButton("Cancel", null)
                .show();
    }
    
    private void clearLog(File logFile) {
        if (logFile.exists()) {
            boolean deleted = logFile.delete();
            if (deleted) {
                Toast.makeText(this, "Log cleared successfully", Toast.LENGTH_SHORT).show();
                loadLogFiles(); // Refresh the list
            } else {
                Toast.makeText(this, "Failed to clear log", Toast.LENGTH_SHORT).show();
            }
        }
    }
} 