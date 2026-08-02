//
//  Watch_MensaApp.swift
//  Watch Mensa Watch App
//
//  Created by Philipp on 27.10.22.
//  Copyright © 2022 Philipp. All rights reserved.
//

import SwiftUI

@main
struct MensaWatchApp: App {
    
    @State private var viewModel: ViewModel
    @State private var phoneMessaging: PhoneMessaging

    init() {
        let viewModel = ViewModel()
        self._viewModel = State(initialValue: viewModel)
        self._phoneMessaging = State(initialValue: PhoneMessaging(viewModel: viewModel))
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environment(viewModel)
                    .environment(phoneMessaging)
            }
        }
    }
}
