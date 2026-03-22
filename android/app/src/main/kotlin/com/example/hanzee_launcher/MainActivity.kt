package com.example.hanzee_launcher

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*
import android.annotation.SuppressLint
import java.lang.reflect.Method
import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.hanzee/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTodayUsage" -> {
                    result.success(getTodayTotalUsage())
                }
                "getSpecificAppUsage" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(getAppUsage(packageName))
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                "openNotifications" -> {
                    expandStatusBar("expandNotificationsPanel")
                    result.success(null)
                }
                "openQuickSettings" -> {
                    expandStatusBar("expandSettingsPanel")
                    result.success(null)    
                }
                // --- PINDAHKAN LOGIC LOCKSCREEN KE SINI ---
                "lockScreen" -> {
                    val service = HanZeeAccessibilityService.instance
                    if (service != null) {
                        service.lockScreen()
                        result.success(true)
                    } else {
                        // Jika belum aktif, buka settings Accessibility
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.error("SERVICE_OFF", "Mohon aktifkan aksesibilitas HanZee", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getTodayTotalUsage(): Int {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )

        var totalTime = 0L
        for (usageStats in stats) {
            totalTime += usageStats.totalTimeInForeground
        }
        return (totalTime / 1000 / 60).toInt()
    }

    private fun getAppUsage(packageName: String): Int {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )

        val appStats = stats.find { it.packageName == packageName }
        val timeInMs = appStats?.totalTimeInForeground ?: 0L
        return (timeInMs / 1000 / 60).toInt()
    }

    private fun expandStatusBar(methodName: String) {
        try {
            @SuppressLint("WrongConstant")
            val statusBarService = getSystemService("statusbar")
            val statusBarManager: Class<*> = Class.forName("android.app.StatusBarManager")
            val method: Method = statusBarManager.getMethod(methodName)
            method.invoke(statusBarService)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

// --- CLASS SERVICE (Diletakkan di luar MainActivity) ---
class HanZeeAccessibilityService : AccessibilityService() {
    companion object {
        var instance: HanZeeAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // Fungsi untuk mematikan layar
    fun lockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        }
    }
}