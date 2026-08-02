//
//  CanteenMenuService.swift
//  Mensa
//
//  Created by Codex on 07.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Sends canteen data updates to another app component or companion device.
protocol CanteenDataSyncing {
    /// Sends the latest canteen menu and selected price group.
    func sendCanteenData(canteen: Canteen, priceGroup: Int)

    /// Sends the selected price group without requiring a full menu refresh.
    func sendPriceGroup(_ priceGroup: Int)
}

/// Publishes freshly available canteen data to side channels such as widgets or watch sync.
protocol CanteenMenuPublishing {
    /// Publishes a canteen payload that has just been loaded or restored from cache.
    func publish(canteen: Canteen, settings: ViewModel, dataSyncer: CanteenDataSyncing?)
}

/// Coordinates cache hydration, network fetching, and snapshot publication for menu data.
final class CanteenMenuService {
    private let totalDaysToFetch = 10
    private let repository: Repository
    private let store: CanteenMenuStoring
    private let publisher: CanteenMenuPublishing

    /// Creates a menu service from explicit data source, cache, and publisher dependencies.
    init(
        repository: Repository = Repository(),
        store: CanteenMenuStoring = SwiftDataCanteenMenuStore(),
        publisher: CanteenMenuPublishing = DefaultCanteenMenuPublisher()
    ) {
        self.repository = repository
        self.store = store
        self.publisher = publisher
    }

    /// Loads stored menu data immediately and refreshes it from the active source in the background.
    func load(refetch: Bool = false, viewModel: ViewModel, dataSyncer: CanteenDataSyncing? = nil) {
        let requestedDates = getNextWorkingDays(date: Date(), count: totalDaysToFetch)
        store.deletePastEntries(before: Date())

        if !refetch, viewModel.canteen == nil {
            viewModel.canteen = store.loadUpcomingCanteen(
                for: viewModel.canteenSelection,
                requestedDates: requestedDates
            )
        }

        if viewModel.canteen != nil {
            viewModel.loading = false
        }

        let hasVisibleMenu = viewModel.canteen != nil
        if refetch || !hasVisibleMenu {
            viewModel.loading = true
        }

        let canteenToUpdate = refetch ? nil : viewModel.canteen
        repository.fetchMenu(
            canteenSelection: viewModel.canteenSelection,
            updating: canteenToUpdate,
            resetSourceCache: refetch || !hasVisibleMenu
        ) { canteen in
            viewModel.canteen = canteen
            viewModel.loading = false
            self.store.save(canteen)
            self.publisher.publish(canteen: canteen, settings: viewModel, dataSyncer: dataSyncer)
        }
    }
}

/// Default side-effect publisher for menu snapshots.
struct DefaultCanteenMenuPublisher: CanteenMenuPublishing {
    func publish(canteen: Canteen, settings: ViewModel, dataSyncer: CanteenDataSyncing?) {
#if os(iOS)
        WidgetMenuSnapshotStore.save(canteen: canteen, settings: settings)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
        dataSyncer?.sendCanteenData(canteen: canteen, priceGroup: settings.priceGroupSelection)
#endif
    }
}
