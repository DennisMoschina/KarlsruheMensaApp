//
//  MensaLineWidget.swift
//  MensaWidgetExtension
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

/// App Intent used to select a canteen line for the line-specific widget.
struct LineSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Food Line"
    static var description = IntentDescription("Choose the Mensa line shown by this widget.")

    @Parameter(title: "Line", optionsProvider: LineOptionsProvider())
    var lineName: String?
}

/// Provides currently cached line names to WidgetKit configuration.
struct LineOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        WidgetMenuSnapshotStore.load()?.today?.openLines.map(\.name) ?? []
    }
}

extension LineSelectionIntent {
    /// Available line names for the configuration picker.
    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$lineName)")
    }
}

/// Timeline entry for a widget focused on one selected food line.
struct MensaLineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMenuSnapshot?
    let selectedLine: WidgetFoodLine?
    let summary: String
}

/// Provides line-specific widget snapshots.
struct MensaLineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MensaLineEntry {
        MensaLineEntry(date: Date(), snapshot: .preview, selectedLine: .preview, summary: "Pasta with vegetables")
    }

    func snapshot(for configuration: LineSelectionIntent, in context: Context) async -> MensaLineEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: LineSelectionIntent, in context: Context) async -> Timeline<MensaLineEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30)))
    }

    private func entry(for configuration: LineSelectionIntent) async -> MensaLineEntry {
        let snapshot = WidgetMenuSnapshotStore.load()
        let lines = snapshot?.today?.openLines ?? []
        let selectedLine = lines.first { $0.name == configuration.lineName } ?? lines.first
        let summary: String
        if let selectedLine {
            summary = await WidgetMenuSummaryService.summary(for: selectedLine)
        } else {
            summary = "No menu data"
        }
        return MensaLineEntry(date: Date(), snapshot: snapshot, selectedLine: selectedLine, summary: summary)
    }
}

/// Configurable widget for one selected canteen food line.
struct MensaLineWidget: Widget {
    let kind = "MensaLineWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LineSelectionIntent.self, provider: MensaLineProvider()) { entry in
            MensaLineWidgetView(entry: entry)
        }
        .configurationDisplayName("Mensa Line")
        .description("Shows the current dishes for one selected food line.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct MensaLineWidgetView: View {
    let entry: MensaLineEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetContainer {
            if let snapshot = entry.snapshot, let line = entry.selectedLine {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: line.name, subtitle: snapshot.canteenName)

                    Text(entry.summary)
                        .font(.headline.weight(.semibold))
                        .lineLimit(family == .systemSmall ? 2 : 3)

                    if family != .systemSmall {
                        ForEach(line.foods.prefix(maxFoodCount)) { food in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(food.foodClass.widgetSymbol)
                                    .font(.caption)
                                Text(food.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if let price = food.price {
                                    Text(price, format: .currency(code: "EUR"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            } else {
                EmptyWidgetView(title: "Mensa Line", message: "Open the app to load today's menu.")
            }
        }
    }

    private var maxFoodCount: Int {
        family == .systemMedium ? 3 : 6
    }
}
