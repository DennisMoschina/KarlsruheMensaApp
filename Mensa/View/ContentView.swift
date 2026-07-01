//
//  ContentView.swift
//  Mensa
//
//  Created by Philipp on 15.11.19.
//  Copyright © 2019 Philipp. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var showSettings: Bool = false
    @State var daySelection = 0
    
    @ObservedObject var viewModel = ViewModel.shared
    @EnvironmentObject private var watchConnectivity: WatchConnectivityHandler
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekDaysView(selection: self.$daySelection)
                    .padding(.bottom)
                    .background(Color(uiColor: .systemGroupedBackground))
                Divider()
                
                ZStack {
                    SwipeView(daySelection: self.$daySelection).blur(radius: self.viewModel.loading ? 3 : 0)
                    
                    if (self.viewModel.loading) {ProgressView().progressViewStyle(CircularProgressViewStyle())}
                }
            }
            .sheet(isPresented: self.$showSettings) {
                SettingsView().accentColor(Constants.COLOR_ACCENT)
            }
            .navigationTitle(Text(self.viewModel.canteenSelection.rawValue))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button("settings", systemImage: Constants.IMAGE_SETTINGS) {
                        self.showSettings.toggle()
                    }
                }
            }
        }
        .onAppear {
            Repository.shared.get()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Repository.shared.get()
        }
        .alert(Constants.NO_INTERNET, isPresented: self.$viewModel.showAlert) {
            Button(Constants.TRY_AGAIN) {
                Repository.shared.get(refetch: true)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(Constants.CONNECT)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
