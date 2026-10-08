package net.alqareeapp.alqaree

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Last surah listened to; tapping opens the app. */
class ListeningWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_listening).apply {
                widgetData.getString("last_title", null)?.let { setTextViewText(R.id.last_title, it) }
                widgetData.getString("last_artist", null)?.let { setTextViewText(R.id.last_artist, it) }
                widgetData.getString("last_letter", null)?.let { setTextViewText(R.id.last_letter, it) }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
