package com.example.imtbf.presentation.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.imtbf.R;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Adapter for displaying configuration files in a RecyclerView
 */
public class ConfigFileAdapter extends RecyclerView.Adapter<ConfigFileAdapter.ConfigFileViewHolder> {
    
    private List<File> configFiles;
    private OnConfigFileSelectedListener listener;
    
    /**
     * Interface for handling configuration file selection
     */
    public interface OnConfigFileSelectedListener {
        void onConfigFileSelected(File configFile);
    }
    
    /**
     * Constructor
     * @param configFiles List of configuration files
     * @param listener Listener for configuration file selection
     */
    public ConfigFileAdapter(List<File> configFiles, OnConfigFileSelectedListener listener) {
        this.configFiles = configFiles;
        this.listener = listener;
    }
    
    @NonNull
    @Override
    public ConfigFileViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_config_file, parent, false);
        return new ConfigFileViewHolder(view);
    }
    
    @Override
    public void onBindViewHolder(@NonNull ConfigFileViewHolder holder, int position) {
        File configFile = configFiles.get(position);
        holder.bind(configFile);
    }
    
    @Override
    public int getItemCount() {
        return configFiles.size();
    }
    
    /**
     * Update the list of configuration files
     * @param configFiles New list of configuration files
     */
    public void updateConfigFiles(List<File> configFiles) {
        this.configFiles = configFiles;
        notifyDataSetChanged();
    }
    
    /**
     * ViewHolder for configuration files
     */
    class ConfigFileViewHolder extends RecyclerView.ViewHolder {
        
        private TextView tvConfigName;
        private TextView tvConfigDate;
        
        public ConfigFileViewHolder(@NonNull View itemView) {
            super(itemView);
            tvConfigName = itemView.findViewById(R.id.tvConfigName);
            tvConfigDate = itemView.findViewById(R.id.tvConfigDate);
            
            itemView.setOnClickListener(v -> {
                int position = getAdapterPosition();
                if (position != RecyclerView.NO_POSITION && listener != null) {
                    listener.onConfigFileSelected(configFiles.get(position));
                }
            });
        }
        
        /**
         * Bind data to the view holder
         * @param configFile Configuration file
         */
        public void bind(File configFile) {
            // Get filename without extension
            String filename = configFile.getName();
            if (filename.endsWith(".json")) {
                filename = filename.substring(0, filename.length() - 5);
            }
            
            tvConfigName.setText(filename);
            
            // Format the last modified date
            long lastModified = configFile.lastModified();
            String formattedDate = new SimpleDateFormat("MMM dd, yyyy HH:mm", Locale.getDefault())
                    .format(new Date(lastModified));
            tvConfigDate.setText(formattedDate);
        }
    }
} 