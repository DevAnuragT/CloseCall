package com.closecall.closecall

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Helpers for vendor background limits. Android exposes no read API for
 * autostart permissions, so only battery-optimization state is reported.
 */
internal object BackgroundReliability {
    private val oemScreens: Map<String, List<ComponentName>> = mapOf(
        "xiaomi" to listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        ),
        "oppo" to coloros(),
        "realme" to coloros(),
        "oneplus" to coloros(),
        "vivo" to listOf(
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        ),
        "huawei" to huawei(),
        "honor" to huawei(),
        "samsung" to listOf(
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        ),
    )

    private fun coloros() = listOf(
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        ComponentName("com.oplus.battery", "com.oplus.startupapp.view.StartupAppListActivity"),
    )

    private fun huawei() = listOf(
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
    )

    private fun manufacturer() = Build.MANUFACTURER.lowercase()

    fun status(context: Context): Map<String, Any> {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "ignoringBatteryOptimizations" to power.isIgnoringBatteryOptimizations(context.packageName),
            "manufacturer" to manufacturer(),
            "hasVendorAutostartScreen" to (oemScreens[manufacturer()]?.isNotEmpty() == true),
        )
    }

    fun requestBatteryExemption(context: Context): Boolean {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(context, direct) ||
            start(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Returns "vendor" when a manufacturer screen opened, else "app" or "none". */
    fun openAutostart(context: Context): String {
        for (component in oemScreens[manufacturer()].orEmpty()) {
            if (start(context, Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))) {
                return "vendor"
            }
        }
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return if (start(context, details)) "app" else "none"
    }

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent)
        true
    } catch (_: Exception) {
        // Missing or unexported vendor screens are expected on other firmware.
        false
    }
}
