package com.example.hanzee_launcher

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.hanzee/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getTodayUsage") {
                if (!hasUsageStatsPermission()) {
                    // If no permission, open settings for the user
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.error("PERMISSION_DENIED", "Usage access permission not granted", null)
                } else {
                    result.success(getTodayUsageInMinutes())
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getTodayUsageInMinutes(): Long {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        var totalTime = 0L
        for (usageStat in stats) {
            totalTime += usageStat.totalTimeInForeground
        }
        
        return totalTime / 1000 / 60 // Convert milliseconds to minutes
    }
}