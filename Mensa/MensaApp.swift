//
//  MensaApp.swift
//  Mensa
//
//  Created by Philipp on 27.10.22.
//  Copyright © 2022 Philipp. All rights reserved.
//

import Foundation
import SwiftUI

@main
struct MensaApp: App {
    
    @State private var viewModel: ViewModel
    private let repository: Repository
    private let menuService: CanteenMenuService
    private let dataSyncer: CanteenDataSyncing?

    init() {
        let viewModel = ViewModel()
        let repository = Repository()
        let menuService = CanteenMenuService(repository: repository)
        self.repository = repository
        self.menuService = menuService
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.dataSyncer = WatchConnectivityHandler(viewModel: viewModel, menuService: menuService)
        #else
        self.dataSyncer = nil
        #endif
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(\.repository, repository)
                .environment(\.menuService, menuService)
                .environment(\.canteenDataSyncer, dataSyncer)
        }
    }
}
