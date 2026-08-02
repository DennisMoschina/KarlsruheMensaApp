//
//  CanteenMenuDataSource.swift
//  Mensa
//
//  Created by Codex on 07.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation

/// One absolute menu day requested from a canteen menu source.
struct CanteenMenuDayRequest {
    let index: Int
    let date: Date
}

/// Source of canteen menu lines independent of the transport or document format.
protocol CanteenMenuDataSource {
    /// Loads menu lines for the requested days grouped by app day index.
    func loadMenuLines(
        for requestedDays: [CanteenMenuDayRequest],
        canteenSelection: Canteens,
        completion: @escaping ([Int: [FoodLine]]) -> Void
    )

    /// Clears any source-local transient cache before a full reload.
    func resetTransientCache()
}

extension CanteenMenuDataSource {
    func resetTransientCache() {}
}
