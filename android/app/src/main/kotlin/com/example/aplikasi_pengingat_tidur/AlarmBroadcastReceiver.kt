package com.example.aplikasi_pengingat_tidur

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmBroadcastReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmBroadcastReceiver"
        private const val NOTIFICATION_ID = 999
        private const val CHANNEL_ID = "alarm_auto_launch"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "==========================================")
        Log.d(TAG, "ALARM BROADCAST RECEIVED!")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "==========================================")
        
        // Wake up the device screen
        wakeUpScreen(context)
        
        // Launch MainActivity directly with full-screen intent
        launchMainActivity(context)
    }
    
    private fun wakeUpScreen(context: Context) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "aplikasi_pengingat_tidur:alarm_receiver_wake"
            )
            wakeLock.acquire(30000) // 30 seconds
            Log.d(TAG, "Screen wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to wake screen: ${e.message}")
        }
    }
    
    private fun launchMainActivity(context: Context) {
        try {
            Log.d(TAG, "Launching MainActivity...")
            
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("alarm_triggered", true)
                putExtra("show_alarm_overlay", true)
            }
            
            context.startActivity(launchIntent)
            Log.d(TAG, "MainActivity launch intent sent!")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity: ${e.message}")
            // Fallback: Show notification with full-screen intent
            showFullScreenNotification(context)
        }
    }
    
    private fun showFullScreenNotification(context: Context) {
        Log.d(TAG, "Showing full-screen notification as fallback")
        
        createNotificationChannel(context)
        
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("alarm_triggered", true)
            putExtra("show_alarm_overlay", true)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🌙 Waktunya Tidur!")
            .setContentText("Ketuk untuk membuka pengingat tidur")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(true)
            .build()
        
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.d(TAG, "Full-screen notification shown")
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Auto Launch",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Channel for auto-launching alarm screen"
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
