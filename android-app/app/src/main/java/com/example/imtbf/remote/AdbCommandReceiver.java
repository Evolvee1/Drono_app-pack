/**
     * Refresh the MainActivity UI after settings changes.
     * This sends a broadcast that will be received by MainActivity
     * to reload its UI with new settings.
     * 
     * @param context Application context
     */
    private void refreshMainActivityUI(Context context) {
        try {
            Logger.i(TAG, "Sending UI refresh broadcast");
            
            // Force stop the app and restart it to ensure UI is refreshed
            String packageName = context.getPackageName();
            
            // Send broadcast to refresh UI (for apps that are still running)
            Intent refreshIntent = new Intent("com.example.imtbf.REFRESH_UI");
            refreshIntent.setPackage(packageName);
            context.sendBroadcast(refreshIntent);
            
            // Force restart the app (most reliable way to ensure UI updates)
            try {
                // First, create an intent to restart the app
                Intent restartIntent = new Intent(context, MainActivity.class);
                restartIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                
                // Second, send a delayed PendingIntent to start the app again after it's stopped
                PendingIntent pendingIntent = PendingIntent.getActivity(
                    context, 
                    123456, 
                    restartIntent,
                    PendingIntent.FLAG_CANCEL_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                
                // Use AlarmManager to trigger the pending intent after a short delay
                AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
                alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 500, pendingIntent);
                
                // Now stop the current app process
                Intent stopIntent = new Intent(context, MainActivity.class);
                stopIntent.setAction("com.example.imtbf.FORCE_STOP");
                stopIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                context.startActivity(stopIntent);
                
                Logger.i(TAG, "App restart requested for UI refresh");
            } catch (Exception e) {
                Logger.e(TAG, "Error trying to restart app", e);
                
                // Fallback to old method if restart fails
                Intent directIntent = new Intent(context, MainActivity.class);
                directIntent.setAction("com.example.imtbf.REFRESH_UI");
                directIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(directIntent);
            }
            
            Logger.i(TAG, "UI refresh signals sent");
        } catch (Exception e) {
            Logger.e(TAG, "Error sending UI refresh signal", e);
        }
    } 