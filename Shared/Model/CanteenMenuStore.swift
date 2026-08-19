//
//  CanteenMenuStore.swift
//  Mensa
//
//  Created by Codex on 07.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation
import OSLog
import SwiftData

/// Persistent storage for upcoming canteen menu days.
protocol CanteenMenuStoring {
    /// Deletes menu days before the provided reference date.
    func deletePastEntries(before referenceDate: Date)

    /// Loads stored menu days for the provided upcoming dates.
    func loadUpcomingCanteen(for canteenSelection: Canteens, requestedDates: [Date]) -> Canteen?

    /// Stores the available days of a canteen payload.
    func save(_ canteen: Canteen)
}

/// SwiftData model for one stored canteen menu day.
@Model
final class StoredCanteenMenuDay {
    @Attribute(.unique) var id: String
    var canteenName: String
    var date: Date
    var foodLinesData: Data
    var updatedAt: Date

    /// Creates one persisted menu-day row.
    init(id: String, canteenName: String, date: Date, foodLinesData: Data, updatedAt: Date) {
        self.id = id
        self.canteenName = canteenName
        self.date = date
        self.foodLinesData = foodLinesData
        self.updatedAt = updatedAt
    }
}

/// SwiftData-backed store for upcoming canteen menu days.
final class SwiftDataCanteenMenuStore: CanteenMenuStoring {
    private let context: ModelContext
    private let calendar: Calendar

    /// Creates a persistent SwiftData-backed menu store.
    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.context = ModelContext(Self.makeContainer())
    }

    func deletePastEntries(before referenceDate: Date) {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let descriptor = FetchDescriptor<StoredCanteenMenuDay>(
            predicate: #Predicate { storedDay in
                storedDay.date < startOfToday
            }
        )

        do {
            for storedDay in try context.fetch(descriptor) {
                context.delete(storedDay)
            }
            try context.save()
        } catch {
            AppLog.storage.error("Failed to delete past canteen menu days: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadUpcomingCanteen(for canteenSelection: Canteens, requestedDates: [Date]) -> Canteen? {
        guard let firstDate = requestedDates.first, let lastDate = requestedDates.last else {
            return nil
        }

        let canteenName = canteenSelection.rawValue
        let firstDay = calendar.startOfDay(for: firstDate)
        guard let lastDayExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate)) else {
            return nil
        }

        let descriptor = FetchDescriptor<StoredCanteenMenuDay>(
            predicate: #Predicate { storedDay in
                storedDay.canteenName == canteenName &&
                storedDay.date >= firstDay &&
                storedDay.date < lastDayExclusive
            },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            let storedDays = try context.fetch(descriptor)
            let storedDaysByDate = Dictionary(uniqueKeysWithValues: storedDays.map {
                (calendar.startOfDay(for: $0.date), $0)
            })
            let decoder = JSONDecoder()
            var foodOnDayX: [Int: [FoodLine]] = [:]

            for (index, date) in requestedDates.enumerated() {
                let day = calendar.startOfDay(for: date)
                guard let storedDay = storedDaysByDate[day],
                      let foodLines = try? decoder.decode([FoodLine].self, from: storedDay.foodLinesData) else {
                    continue
                }
                foodOnDayX[index] = foodLines
            }

            guard !foodOnDayX.isEmpty else {
                return nil
            }

            AppLog.storage.info("Loaded \(foodOnDayX.count) cached menu days for \(canteenName, privacy: .public)")
            let canteen = Canteen(
                name: canteenName,
                foodOnDayX: foodOnDayX,
                dateOfLastFetching: Date()
            )
            canteen.nextOpenDays = requestedDates
            return canteen
        } catch {
            AppLog.storage.error("Failed to load stored canteen menu days: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(_ canteen: Canteen) {
        let encoder = JSONEncoder()
        var savedDayCount = 0

        for (index, foodLines) in canteen.foodOnDayX {
            guard canteen.nextOpenDays.indices.contains(index),
                  let foodLinesData = try? encoder.encode(foodLines) else {
                continue
            }

            let date = calendar.startOfDay(for: canteen.nextOpenDays[index])
            let id = storageID(canteenName: canteen.name, date: date)
            let descriptor = FetchDescriptor<StoredCanteenMenuDay>(
                predicate: #Predicate { storedDay in
                    storedDay.id == id
                }
            )

            do {
                if let storedDay = try context.fetch(descriptor).first {
                    storedDay.foodLinesData = foodLinesData
                    storedDay.updatedAt = Date()
                } else {
                    context.insert(
                        StoredCanteenMenuDay(
                            id: id,
                            canteenName: canteen.name,
                            date: date,
                            foodLinesData: foodLinesData,
                            updatedAt: Date()
                        )
                    )
                }
                savedDayCount += 1
            } catch {
                AppLog.storage.error("Failed to upsert stored canteen menu day: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try context.save()
            AppLog.storage.info("Saved \(savedDayCount) cached menu days for \(canteen.name, privacy: .public)")
        } catch {
            AppLog.storage.error("Failed to save stored canteen menu days: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func storageID(canteenName: String, date: Date) -> String {
        "\(canteenName)|\(Int(date.timeIntervalSince1970))"
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: StoredCanteenMenuDay.self)
        } catch {
            AppLog.storage.fault("Failed to create persistent SwiftData menu store: \(error.localizedDescription, privacy: .public)")
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: StoredCanteenMenuDay.self, configurations: configuration)
        }
    }
}
