package com.example.imtbf.utils;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.example.imtbf.InstagramTrafficSimulatorApp;
import com.example.imtbf.data.local.PreferencesManager;
import com.example.imtbf.presentation.activities.MainActivity;

/**
 * Receives boot completed broadcast to restart simulations after device reboot.
 */
public class BootReceiver extends BroadcastReceiver {

    private static final String TAG = "BootReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            Logger.i(TAG, "Boot completed received");

            // Check if simulation was running
            PreferencesManager preferencesManager =
                    ((InstagramTrafficSimulatorApp) context.getApplicationContext())
                            .getPreferencesManager();

            if (preferencesManager.isSimulationRunning()) {
                Logger.i(TAG, "Simulation was running, launching app");

                // Launch the app
                Intent launchIntent = new Intent(context, MainActivity.class);
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(launchIntent);
            }
        }
    }
}