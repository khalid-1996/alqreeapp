import SwiftUI
import WidgetKit

// Data is written by the Flutter app through home_widget into this App Group.
private let appGroup = "group.net.alqareeapp.alqaree"
private let navy = Color(red: 0.0, green: 10 / 255, blue: 58 / 255)
private let card = Color(red: 5 / 255, green: 23 / 255, blue: 85 / 255)
private let accent = Color(red: 59 / 255, green: 167 / 255, blue: 1.0)
private let muted = Color(red: 169 / 255, green: 179 / 255, blue: 214 / 255)

struct AlqareeEntry: TimelineEntry {
    let date: Date
    let label: String
    let text: String
    let source: String
    let lastTitle: String
    let lastArtist: String
    let lastLetter: String

    static let placeholder = AlqareeEntry(
        date: Date(),
        label: "دعاء اليوم",
        text: "«اللهم إني أسألك علمًا نافعًا، ورزقًا طيبًا، وعملًا متقبلًا»",
        source: "رواه ابن ماجه",
        lastTitle: "سورة الكهف",
        lastArtist: "القارئ",
        lastLetter: "ق"
    )

    static func load() -> AlqareeEntry {
        let d = UserDefaults(suiteName: appGroup)
        let p = placeholder
        return AlqareeEntry(
            date: Date(),
            label: d?.string(forKey: "daily_label") ?? p.label,
            text: d?.string(forKey: "daily_text") ?? "افتح التطبيق لتحميل حديث اليوم",
            source: d?.string(forKey: "daily_source") ?? "",
            lastTitle: d?.string(forKey: "last_title") ?? "القارئ",
            lastArtist: d?.string(forKey: "last_artist") ?? "اختر تلاوة لتظهر هنا",
            lastLetter: d?.string(forKey: "last_letter") ?? "ق"
        )
    }
}

struct AlqareeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlqareeEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (AlqareeEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlqareeEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date().addingTimeInterval(10800)
        completion(Timeline(entries: [.load()], policy: .after(next)))
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

struct DailyView: View {
    let entry: AlqareeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.label).font(.system(size: 13, weight: .bold)).foregroundColor(accent)
                Spacer()
                Text("القارئ").font(.system(size: 12, weight: .bold)).foregroundColor(muted)
            }
            // Long texts shrink instead of being cut off.
            Text(entry.text)
                .font(.system(size: 19))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !entry.source.isEmpty {
                Text(entry.source).font(.system(size: 12)).foregroundColor(muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .alqareeBackground()
    }
}

struct ListeningView: View {
    let entry: AlqareeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.lastLetter)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
            Text("أكمل الاستماع").font(.system(size: 11)).foregroundColor(muted)
            Text(entry.lastTitle).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
            Text(entry.lastArtist).font(.system(size: 12)).foregroundColor(muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
        .alqareeBackground()
    }
}

struct AlqareeWidget: Widget {
    let kind = "AlqareeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlqareeProvider()) { entry in
            DailyView(entry: entry)
        }
        .configurationDisplayName("حديث ودعاء اليوم")
        .description("حديث أو دعاء اليوم من تطبيق القارئ")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AlqareeListeningWidget: Widget {
    let kind = "AlqareeListeningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlqareeProvider()) { entry in
            ListeningView(entry: entry)
        }
        .configurationDisplayName("أكمل الاستماع")
        .description("آخر سورة استمعت لها")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AlqareeWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlqareeWidget()
        AlqareeListeningWidget()
    }
}
