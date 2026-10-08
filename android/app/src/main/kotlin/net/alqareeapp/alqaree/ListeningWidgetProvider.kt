package net.alqareeapp.alqaree

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Last surah, reciter and where the user stopped; tapping resumes from that point. */
class ListeningWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val title = widgetData.getString("last_title", null)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_listening).apply {
                if (title != null) {
                    setTextViewText(R.id.last_title, title)
                    setTextViewText(R.id.last_artist, widgetData.getString("last_artist", ""))
                    setTextViewText(R.id.last_letter, widgetData.getString("last_letter", "ق"))
                    val pos = widgetData.getString("last_position", null)
                    if (pos != null) {
                        setTextViewText(R.id.last_position, "وقفت عند $pos")
                        setViewVisibility(R.id.last_position, View.VISIBLE)
                    }
                    setViewVisibility(R.id.last_play, View.VISIBLE)
                }
                val open = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse(if (title != null) "alqaree://resume" else "alqaree://home"),
                )
                setOnClickPendingIntent(R.id.widget_root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
