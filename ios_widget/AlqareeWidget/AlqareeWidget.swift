import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Shared data

private let appGroup = "group.net.alqareeapp.alqaree"
private let card = Color(red: 5 / 255, green: 23 / 255, blue: 85 / 255)
private let accent = Color(red: 59 / 255, green: 167 / 255, blue: 1.0)
private let muted = Color(red: 169 / 255, green: 179 / 255, blue: 214 / 255)
private let soft = Color(red: 221 / 255, green: 227 / 255, blue: 247 / 255)

struct ContentItem {
    let id: String
    let text: String
    let source: String
    let count: Int
}

/// Reads the JSON files the Flutter app bundles (assets/data/*.json) straight from the
/// containing app, so ومضات and adhkar work without opening the app.
enum WidgetContent {
    static func asset(_ name: String) -> [String: Any]? {
        // .../Runner.app/PlugIns/AlqareeWidget.appex -> .../Runner.app
        let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        let url = app.appendingPathComponent("Frameworks/App.framework/flutter_assets/assets/data/\(name)")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }

    /// Days since epoch for the local calendar date; same formula as the Dart and Kotlin code.
    static func dayIndex(_ date: Date = Date()) -> Int {
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let d = utc.date(from: parts) ?? date
        return Int(floor(d.timeIntervalSince1970 / 86400))
    }

    static func today() -> String {
        let p = gregorian.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04ld-%02ld-%02ld", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    static func dateKey(_ date: Date) -> String {
        let p = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    /// Prefers what the app shared (next 14 days), so the widget, the app and notifications match.
    static func wamda(_ date: Date = Date()) -> (label: String, item: ContentItem)? {
        if let raw = defaults?.string(forKey: "wamda_days"),
           let data = raw.data(using: .utf8),
           let days = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: String]],
           let d = days[dateKey(date)], let text = d["text"], !text.isEmpty {
            return (d["label"] ?? "", ContentItem(id: "shared", text: text, source: d["source"] ?? "", count: 1))
        }
        guard let json = asset("wamdat.json") else { return nil }
        let i = dayIndex(date)
        let types = ["hadith", "dua", "ayah"]
        let labels = ["hadith": "حديث", "dua": "دعاء", "ayah": "آية"]
        let type = types[i % 3]
        guard let list = json[type] as? [[String: Any]], !list.isEmpty else { return nil }
        let o = list[(i / 3) % list.count]
        return (labels[type] ?? "", ContentItem(id: type, text: o["text"] as? String ?? "", source: o["source"] as? String ?? "", count: 1))
    }

    static func isEvening(_ date: Date = Date()) -> Bool {
        let h = gregorian.component(.hour, from: date)
        return h >= 15 || h < 4
    }

    static func adhkar(evening: Bool) -> [ContentItem] {
        guard let json = asset("adhkar.json"), let list = json[evening ? "evening" : "morning"] as? [[String: Any]] else { return [] }
        return list.map {
            ContentItem(id: $0["id"] as? String ?? "", text: $0["text"] as? String ?? "", source: $0["source"] as? String ?? "", count: ($0["count"] as? NSNumber)?.intValue ?? 1)
        }
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Today's counts, shared with the app under "adhkar_state".
    static func counts() -> [String: Int] {
        guard let raw = defaults?.string(forKey: "adhkar_state"),
              let data = raw.data(using: .utf8),
              let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              j["date"] as? String == today(),
              let c = j["counts"] as? [String: Any] else { return [:] }
        var out: [String: Int] = [:]
        for (k, v) in c { out[k] = (v as? NSNumber)?.intValue ?? 0 }
        return out
    }

    static func countOne() {
        let list = adhkar(evening: isEvening())
        var c = counts()
        guard let current = list.first(where: { (c[$0.id] ?? 0) < $0.count }) else { return }
        c[current.id] = (c[current.id] ?? 0) + 1
        let j: [String: Any] = ["date": today(), "counts": c]
        if let data = try? JSONSerialization.data(withJSONObject: j), let s = String(data: data, encoding: .utf8) {
            defaults?.set(s, forKey: "adhkar_state")
        }
    }
}

// MARK: - Timeline

struct AlqareeEntry: TimelineEntry {
    let date: Date
}

struct AlqareeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlqareeEntry { AlqareeEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (AlqareeEntry) -> Void) {
        completion(AlqareeEntry(date: Date()))
    }

    /// Refresh every hour and exactly at midnight, so the ومضة and the adhkar set change on time.
    func getTimeline(in context: Context, completion: @escaping (Timeline<AlqareeEntry>) -> Void) {
        let now = Date()
        let cal = WidgetContent.gregorian
        var dates = [now]
        for h in 1...6 { if let d = cal.date(byAdding: .hour, value: h, to: now) { dates.append(cal.date(bySetting: .minute, value: 0, of: d) ?? d) } }
        if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) { dates.append(midnight) }
        let entries = Array(Set(dates)).sorted().map { AlqareeEntry(date: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension View {
    @ViewBuilder
    func alqareeBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(card, for: .widget)
        } else {
            self.padding().background(card)
        }
    }
}

// MARK: - ومضات اليوم

struct WamdaView: View {
    let entry: AlqareeEntry

    var body: some View {
        let w = WidgetContent.wamda(entry.date)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("ومضات اليوم").font(.system(size: 13, weight: .bold)).foregroundColor(accent)
                if let label = w?.label {
                    Text(label).font(.system(size: 11)).foregroundColor(soft)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.white.opacity(0.08)).clipShape(Capsule())
                }
                Spacer()
                Text("القارئ").font(.system(size: 12, weight: .bold)).foregroundColor(muted)
            }
            // Long texts shrink instead of being cut off.
            Text(w?.item.text ?? "«ربنا آتنا في الدنيا حسنة، وفي الآخرة حسنة، وقنا عذاب النار»")
                .font(.system(size: 21))
                .minimumScaleFactor(0.45)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(w?.item.source ?? "").font(.system(size: 12)).foregroundColor(muted).frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "alqaree://wamda?homeWidget"))
        .alqareeBackground()
    }
}

struct AlqareeWidget: Widget {
    let kind = "AlqareeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlqareeProvider()) { WamdaView(entry: $0) }
            .configurationDisplayName("ومضات اليوم")
            .description("حديث أو دعاء أو آية، كل يوم")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - أكمل الاستماع

struct ListeningView: View {
    let entry: AlqareeEntry

    var body: some View {
        let d = WidgetContent.defaults
        let title = d?.string(forKey: "last_title")
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(d?.string(forKey: "last_letter") ?? "ق")
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
                if title != nil {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundColor(card)
                        .frame(width: 36, height: 36).background(accent).clipShape(Circle())
                }
            }
            Spacer()
            Text("أكمل الاستماع").font(.system(size: 11)).foregroundColor(muted)
            Text(title ?? "القارئ").font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
            Text(d?.string(forKey: "last_artist") ?? "اختر تلاوة لتظهر هنا").font(.system(size: 12)).foregroundColor(muted).lineLimit(1)
            if let pos = d?.string(forKey: "last_position"), title != nil {
                Text("وقفت عند \(pos)").font(.system(size: 11)).foregroundColor(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: title != nil ? "alqaree://resume?homeWidget" : "alqaree://home?homeWidget"))
        .alqareeBackground()
    }
}

struct AlqareeListeningWidget: Widget {
    let kind = "AlqareeListeningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlqareeProvider()) { ListeningView(entry: $0) }
            .configurationDisplayName("أكمل الاستماع")
            .description("آخر سورة استمعت لها، وتكمل من حيث وقفت")
            .supportedFamilies([.systemSmall])
    }
}

// MARK: - الأذكار

@available(iOS 17.0, *)
struct CountDhikrIntent: AppIntent {
    static var title: LocalizedStringResource = "عدّ الذكر"

    func perform() async throws -> some IntentResult {
        WidgetContent.countOne()
        return .result()
    }
}

struct AdhkarView: View {
    let entry: AlqareeEntry

    var body: some View {
        let evening = WidgetContent.isEvening(entry.date)
        let list = WidgetContent.adhkar(evening: evening)
        let counts = WidgetContent.counts()
        let done = list.filter { (counts[$0.id] ?? 0) >= $0.count }.count
        let current = list.first { (counts[$0.id] ?? 0) < $0.count }
        let title = evening ? "أذكار المساء" : "أذكار الصباح"

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(accent)
                Spacer()
                Text("\(done) / \(list.count)").font(.system(size: 12)).foregroundColor(muted)
            }
            if let c = current {
                Text(c.text)
                    .font(.system(size: 19)).minimumScaleFactor(0.45)
                    .foregroundColor(.white).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Text("باقي \(c.count - (counts[c.id] ?? 0))").font(.system(size: 13, weight: .bold)).foregroundColor(soft)
                    Spacer()
                    if #available(iOSApplicationExtension 17.0, *) {
                        Button(intent: CountDhikrIntent()) {
                            Text("عُدّ +١").font(.system(size: 15, weight: .bold)).foregroundColor(card)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(accent).clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("أتممت \(title) ✓\nتقبّل الله منك")
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "alqaree://adhkar?homeWidget"))
        .alqareeBackground()
    }
}

struct AlqareeAdhkarWidget: Widget {
    let kind = "AlqareeAdhkarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlqareeProvider()) { AdhkarView(entry: $0) }
            .configurationDisplayName("أذكار الصباح والمساء")
            .description("وين وصلت في الأذكار، وعُدّ من الشاشة الرئيسية")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct AlqareeWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlqareeWidget()
        AlqareeListeningWidget()
        AlqareeAdhkarWidget()
    }
}
