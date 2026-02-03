package com.afsheen.pinknote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PomodoroWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_pomodoro)
        val widgetData = HomeWidgetPlugin.getData(context)

        // Fetch data
        val statusRaw = widgetData.getString("pomo_status", "focus") ?: "focus"
        val time = widgetData.getString("pomo_time", "25:00")
        val isRunning = widgetData.getBoolean("pomo_is_running", false)
        
        // 1. Force Lowercase for Aesthetic
        val status = statusRaw.lowercase()

        // 2. Dynamic Background Logic
        // If NOT running (paused or app closed/reset), use Grey.
        // Otherwise, use the color based on the status.
        val bgDrawable = if (!isRunning) {
            R.drawable.rounded_grey_bg
        } else {
            when (status) {
                "quick recharge", "short break" -> R.drawable.rounded_blue_bg
                "stretch & breathe", "long break" -> R.drawable.rounded_green_bg
                else -> R.drawable.rounded_pink_bg // Default to "focus" (Pink)
            }
        }
        
        // Apply the background to the root layout
        views.setInt(R.id.pomodoro_root, "setBackgroundResource", bgDrawable)

        // Update Text
        views.setTextViewText(R.id.pomo_status, status)
        views.setTextViewText(R.id.pomo_timer, time)
        
        // --- Click Listener ---
        // Navigation (Open App)
        val navIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("pinknote://pomodoro/view")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val navPending = PendingIntent.getActivity(
            context, 500, navIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.pomodoro_root, navPending)

        manager.updateAppWidget(id, views)
    }
}