//
//  WidgetSharedViews.swift
//  MensaWidgetExtension
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Shared widget background and padding.
struct WidgetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [Color.green.opacity(0.24), Color(uiColor: .systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

/// Compact header used by all widgets.
struct WidgetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.bold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Empty state for widgets before the app has cached menu data.
struct EmptyWidgetView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: title, subtitle: "No cached menu")
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }
}

extension WidgetFoodClass {
    /// Compact symbol used in widget dish rows.
    var widgetSymbol: String {
        switch self {
        case .vegan:
            return "V"
        case .vegetarian:
            return "Veg"
        case .fish:
            return "Fish"
        case .beef:
            return "Beef"
        case .pork:
            return "Pork"
        case .nothing:
            return ""
        }
    }
}

extension WidgetMenuSnapshot {
    /// First cached day, treated as today's menu window by the app fetcher.
    var today: WidgetMenuDay? {
        days.first
    }

    static var preview: WidgetMenuSnapshot {
        WidgetMenuSnapshot(
            canteenName: "Mensa am Adenauerring",
            generatedAt: Date(),
            days: [WidgetMenuDay(index: 0, date: Date(), lines: [.preview, .previewVegetarian])]
        )
    }
}

extension WidgetMenuDay {
    /// Lines with visible menu items after user filters are applied.
    var openLines: [WidgetFoodLine] {
        lines.filter { !$0.foods.isEmpty }
    }
}

extension WidgetFoodLine {
    static var preview: WidgetFoodLine {
        WidgetFoodLine(
            name: "Linie 1",
            foods: [
                WidgetFood(name: "Pasta mit Tomatensauce und Rucola", foodClass: .vegan, price: 3.2, averageRating: 4.2),
                WidgetFood(name: "Lasagne Bolognese", foodClass: .beef, price: 4.1, averageRating: 4.5)
            ],
            closingText: ""
        )
    }

    static var previewVegetarian: WidgetFoodLine {
        WidgetFoodLine(
            name: "Schneller Teller",
            foods: [
                WidgetFood(name: "Gemüsecurry mit Reis", foodClass: .vegetarian, price: 3.7, averageRating: nil)
            ],
            closingText: ""
        )
    }
}

extension LineSummary {
    static var preview: [LineSummary] {
        [
            LineSummary(lineName: "Linie 1", summary: "Pasta mit Tomatensauce"),
            LineSummary(lineName: "Schneller Teller", summary: "Gemüsecurry")
        ]
    }
}

extension Sequence {
    /// Maps sequence elements asynchronously while preserving order.
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values: [T] = []
        for element in self {
            values.append(await transform(element))
        }
        return values
    }
}
