package com.example.aplikasi_pengingat_tidur

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.aplikasi_pengingat_tidur/alarm"
        private const val NOTIFICATION_CHANNEL_ID = "alarm_channel"
    }
    
    private var alarmReceiver: BroadcastReceiver? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate")
        
        // Allow app to show over lock screen and turn screen on
        showOverLockScreen()
        
        // Create notification channel
        createNotificationChannel()
        
        // Register for alarm events
        registerAlarmReceiver()
        
        // Check if launched from alarm
        if (intent?.getBooleanExtra("alarm_triggered", false) == true) {
            Log.d(TAG, "App launched from alarm trigger!")
        }
    }
    
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Pengingat Tidur",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm pengingat tidur"
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun registerAlarmReceiver() {
        alarmReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "Alarm broadcast received in MainActivity!")
                
                // Wake up the screen
                wakeUpScreen()
                
                // The Flutter side will handle showing the overlay
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.gdelataillade.alarm.ALARM_RING")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(alarmReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(alarmReceiver, filter)
        }
    }
    
    private fun wakeUpScreen() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "aplikasi_pengingat_tidur:alarm_wake_lock"
        )
        wakeLock.acquire(10000) // 10 seconds
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToForeground" -> {
                    bringAppToForeground()
                    result.success(true)
                }
                "wakeScreen" -> {
                    wakeUpScreen()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun bringAppToForeground() {
        Log.d(TAG, "Bringing app to foreground")
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        alarmReceiver?.let { unregisterReceiver(it) }
    }
}
