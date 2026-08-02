//
//  WidgetMenuSnapshot.swift
//  Mensa
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation

/// Compact, immutable menu data written by the app and consumed by WidgetKit.
struct WidgetMenuSnapshot: Codable {
    var canteenName: String
    var generatedAt: Date
    var days: [WidgetMenuDay]
}

/// One open canteen day in the widget snapshot.
struct WidgetMenuDay: Codable, Identifiable {
    var id: Int { index }
    var index: Int
    var date: Date
    var lines: [WidgetFoodLine]
}

/// Display-ready food line data for widgets.
struct WidgetFoodLine: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var foods: [WidgetFood]
    var closingText: String

    var isClosed: Bool {
        foods.isEmpty
    }
}

/// Display-ready meal data for widgets.
struct WidgetFood: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var foodClass: WidgetFoodClass
    var price: Float?
    var averageRating: Double?
}

/// Compact dietary classification for widget display.
enum WidgetFoodClass: String, Codable, Hashable {
    case vegetarian
    case vegan
    case beef
    case pork
    case fish
    case nothing
}

/// Persists and loads WidgetKit menu snapshots through an app group when available.
enum WidgetMenuSnapshotStore {
    static let appGroupIdentifier = "group.edu.teco.ilteen.Mensa"

    private static let snapshotKey = "widgetMenuSnapshot"

#if !WIDGET_EXTENSION
    /// Stores a compact snapshot for the app's current canteen and user filters.
    static func save(canteen: Canteen, settings: ViewModel) {
        let snapshot = WidgetMenuSnapshot(
            canteenName: canteen.name,
            generatedAt: Date(),
            days: canteen.foodOnDayX.keys.sorted().compactMap { index in
                guard let date = canteen.nextOpenDays[safe: index] else { return nil }
                let lines = (canteen.foodOnDayX[index] ?? []).map { line in
                    WidgetFoodLine(
                        name: line.name,
                        foods: removeUnwantedFood(foods: line.foods, settings: settings).map { food in
                            WidgetFood(
                                name: food.name,
                                foodClass: WidgetFoodClass(foodClass: food.foodClass),
                                price: food.prices[safe: settings.priceGroupSelection],
                                averageRating: food.averageRating
                            )
                        },
                        closingText: line.closingText
                    )
                }
                return WidgetMenuDay(index: index, date: date, lines: lines)
            }
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
#endif

    /// Loads the most recent widget snapshot written by the main app.
    static func load() -> WidgetMenuSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetMenuSnapshot.self, from: data)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

#if !WIDGET_EXTENSION
extension WidgetFoodClass {
    /// Converts the app's full food classification into a compact widget value.
    init(foodClass: FoodClass) {
        switch foodClass {
        case .vegetarian:
            self = .vegetarian
        case .vegan:
            self = .vegan
        case .beef, .beefLocal:
            self = .beef
        case .pork, .porkLocal:
            self = .pork
        case .fish:
            self = .fish
        case .nothing:
            self = .nothing
        }
    }
}
#endif

extension Collection {
    /// Returns the element at an index only when it is valid for the collection.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
