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
    
    @State private var viewModel = ViewModel()
    @State private var connectivityRequestHandler = WatchConnectivityHandler()
    private let repository = Repository()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(connectivityRequestHandler)
                .environment(\.repository, repository)
        }
    }
}
