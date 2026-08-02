//
//  MensaOverviewWidget.swift
//  MensaWidgetExtension
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Timeline entry for the general canteen overview widget.
struct MensaOverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMenuSnapshot?
    let lineSummaries: [LineSummary]
}

/// Short summary attached to one food line.
struct LineSummary: Identifiable, Hashable {
    var id: String { lineName }
    let lineName: String
    let summary: String
}

/// Provides overview widget snapshots from the shared app-group cache.
struct MensaOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> MensaOverviewEntry {
        MensaOverviewEntry(date: Date(), snapshot: .preview, lineSummaries: LineSummary.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MensaOverviewEntry) -> Void) {
        completion(MensaOverviewEntry(date: Date(), snapshot: WidgetMenuSnapshotStore.load() ?? .preview, lineSummaries: LineSummary.preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MensaOverviewEntry>) -> Void) {
        Task {
            let snapshot = WidgetMenuSnapshotStore.load()
            let today = snapshot?.today
            let summaries = await today?.openLines.prefix(4).asyncMap { line in
                LineSummary(lineName: line.name, summary: await WidgetMenuSummaryService.summary(for: line))
            } ?? []
            let entry = MensaOverviewEntry(date: Date(), snapshot: snapshot, lineSummaries: summaries)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30))))
        }
    }
}

/// General canteen overview widget.
struct MensaOverviewWidget: Widget {
    let kind = "MensaOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MensaOverviewProvider()) { entry in
            MensaOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Mensa Overview")
        .description("Shows today's open lines and a short main-dish summary.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct MensaOverviewWidgetView: View {
    let entry: MensaOverviewEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetContainer {
            if let snapshot = entry.snapshot, let today = snapshot.today {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "Today", subtitle: snapshot.canteenName)

                    if entry.lineSummaries.isEmpty {
                        Text("No menu data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entry.lineSummaries.prefix(maxLines)) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.lineName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(item.summary)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                    Text(today.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                EmptyWidgetView(title: "Mensa", message: "Open the app to load today's menu.")
            }
        }
    }

    private var maxLines: Int {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 3
        default:
            return 5
        }
    }
}
