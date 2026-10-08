package net.alqareeapp.alqaree

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Hadith or dua of the day. Data is written by the Flutter side (HomeWidgets.updateDaily). */
class DailyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_daily).apply {
                widgetData.getString("daily_label", null)?.let { setTextViewText(R.id.daily_label, it) }
                widgetData.getString("daily_text", null)?.let { setTextViewText(R.id.daily_text, it) }
                setTextViewText(R.id.daily_source, widgetData.getString("daily_source", ""))
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
