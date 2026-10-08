package net.alqareeapp.alqaree

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** ومضات اليوم: works without opening the app and changes every day. */
class DailyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val wamda = WidgetContent.wamda(context)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_daily).apply {
                if (wamda != null) {
                    setTextViewText(R.id.daily_type, wamda.first)
                    setTextViewText(R.id.daily_text, wamda.second.text)
                    setTextViewText(R.id.daily_source, wamda.second.source)
                }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("alqaree://wamda")),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
