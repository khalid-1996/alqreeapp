package net.alqareeapp.alqaree

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Morning/evening adhkar: progress, the current dhikr, and a button that counts
 * one repetition right from the home screen. Counts are shared with the app.
 */
class AdhkarWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val ACTION_COUNT = "net.alqareeapp.alqaree.ADHKAR_COUNT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_COUNT) {
            val evening = WidgetContent.isEvening()
            val list = WidgetContent.adhkar(context, evening)
            val counts = WidgetContent.counts(context)
            val current = list.firstOrNull { (counts[it.id] ?: 0) < it.count }
            if (current != null) {
                counts[current.id] = (counts[current.id] ?: 0) + 1
                WidgetContent.saveCounts(context, counts)
            }
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, AdhkarWidgetProvider::class.java))
            onUpdate(context, mgr, ids, WidgetContent.prefs(context))
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val evening = WidgetContent.isEvening()
        val list = WidgetContent.adhkar(context, evening)
        val counts = WidgetContent.counts(context)
        val done = list.count { (counts[it.id] ?: 0) >= it.count }
        val current = list.firstOrNull { (counts[it.id] ?: 0) < it.count }
        val title = if (evening) "أذكار المساء" else "أذكار الصباح"

        val countIntent = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, AdhkarWidgetProvider::class.java).setAction(ACTION_COUNT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_adhkar).apply {
                setTextViewText(R.id.adhkar_title, title)
                setTextViewText(R.id.adhkar_progress, "$done / ${list.size}")
                if (current == null && list.isNotEmpty()) {
                    setTextViewText(R.id.adhkar_text, "أتممت $title ✓\nتقبّل الله منك")
                    setTextViewText(R.id.adhkar_source, "")
                    setViewVisibility(R.id.adhkar_count_row, View.GONE)
                } else if (current != null) {
                    val left = current.count - (counts[current.id] ?: 0)
                    setTextViewText(R.id.adhkar_text, current.text)
                    setTextViewText(R.id.adhkar_source, current.source)
                    setTextViewText(R.id.adhkar_left, "باقي $left")
                    setViewVisibility(R.id.adhkar_count_row, View.VISIBLE)
                    setOnClickPendingIntent(R.id.adhkar_count, countIntent)
                }
                setOnClickPendingIntent(
                    R.id.adhkar_body,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("alqaree://adhkar")),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
