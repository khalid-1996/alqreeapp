package net.alqareeapp.alqaree

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Reads the same JSON files the Flutter app bundles (assets/data (wamdat.json, adhkar.json)), so widgets
 * work on their own, change every day, and always match the app.
 */
object WidgetContent {
    data class Item(val id: String, val text: String, val source: String, val count: Int = 1)

    private val wamdaTypes = listOf("hadith", "dua", "ayah")
    private val wamdaLabels = mapOf("hadith" to "حديث", "dua" to "دعاء", "ayah" to "آية")

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    private fun asset(context: Context, name: String): JSONObject? = try {
        context.assets.open("flutter_assets/assets/data/$name").bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()) }
    } catch (e: Exception) {
        null
    }

    /** Days since epoch for the local calendar date; same formula as LocalContent.dayIndex in Dart. */
    fun dayIndex(): Long {
        val local = Calendar.getInstance()
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        utc.clear()
        utc.set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
        return utc.timeInMillis / 86_400_000L
    }

    fun today(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d-%02d".format(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
    }

    /** Today's ومضة: (type label, item). Prefers what the app shared, so all surfaces match. */
    fun wamda(context: Context): Pair<String, Item>? {
        try {
            val shared = prefs(context).getString("wamda_days", null)
            val day = shared?.let { JSONObject(it).optJSONObject(today()) }
            if (day != null && day.optString("text").isNotBlank()) {
                return day.optString("label") to Item("shared", day.optString("text"), day.optString("source"))
            }
        } catch (e: Exception) {
        }
        val json = asset(context, "wamdat.json") ?: return null
        // Same formula as LocalContent.wamdaFor: hadith + dua + ayah sorted by FNV-1a("type:index").
        val pool = mutableListOf<Triple<Long, String, Pair<String, JSONObject>>>()
        for (t in wamdaTypes) {
            val a = json.optJSONArray(t) ?: continue
            for (k in 0 until a.length()) pool.add(Triple(mixRank("$t:$k"), "$t:$k", t to a.getJSONObject(k)))
        }
        if (pool.isEmpty()) return null
        pool.sortWith(compareBy({ it.first }, { it.second }))
        val (type, o) = pool[(dayIndex() % pool.size).toInt()].third
        return (wamdaLabels[type] ?: "") to Item(type, o.optString("text"), o.optString("source"))
    }

    fun mixRank(key: String): Long {
        var h = 0x811c9dc5L
        for (c in key) h = ((h xor c.code.toLong()) * 0x01000193L) and 0xffffffffL
        h = h xor (h ushr 16)
        h = (h * 0x85ebca6bL) and 0xffffffffL
        h = h xor (h ushr 13)
        h = (h * 0xc2b2ae35L) and 0xffffffffL
        return h xor (h ushr 16)
    }

    fun isEvening(): Boolean {
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return h >= 15 || h < 4
    }

    fun adhkar(context: Context, evening: Boolean): List<Item> {
        val list = asset(context, "adhkar.json")?.optJSONArray(if (evening) "evening" else "morning") ?: return emptyList()
        return (0 until list.length()).map {
            val o = list.getJSONObject(it)
            Item(o.optString("id"), o.optString("text"), o.optString("source"), o.optInt("count", 1))
        }
    }

    /** Today's counts by dhikr id, shared with the app (key "adhkar_state"). */
    fun counts(context: Context): MutableMap<String, Int> {
        val out = mutableMapOf<String, Int>()
        val raw = prefs(context).getString("adhkar_state", null) ?: return out
        try {
            val j = JSONObject(raw)
            if (j.optString("date") != today()) return out
            val c = j.optJSONObject("counts") ?: return out
            c.keys().forEach { k -> out[k] = c.optInt(k) }
        } catch (e: Exception) {
        }
        return out
    }

    fun saveCounts(context: Context, counts: Map<String, Int>) {
        val c = JSONObject()
        counts.forEach { (k, v) -> c.put(k, v) }
        val j = JSONObject().put("date", today()).put("counts", c)
        prefs(context).edit().putString("adhkar_state", j.toString()).apply()
    }
}
