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
    
    @Environment(ViewModel.self) private var viewModel
    @Environment(WatchConnectivityHandler.self) private var watchConnectivity
    @Environment(\.repository) private var repository
    
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
            repository.get(viewModel: viewModel, dataSyncer: watchConnectivity)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository.get(viewModel: viewModel, dataSyncer: watchConnectivity)
        }
        //show alert when no internet connection available TODO: not working ATM
//        .alert(isPresented: self.$viewModel.showAlert) {
//            Alert(title: Text(Constants.NO_INTERNET), message: Text(Constants.CONNECT), dismissButton: Alert.Button.default(
//                Text(Constants.TRY_AGAIN), action:  {
//                    repository.get(viewModel: viewModel, dataSyncer: watchConnectivity) {
//                        self.viewModel.loading = false
//                        self.viewModel.showAlert = false
//                    }
//                }))
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(ViewModel())
            .environment(WatchConnectivityHandler())
    }
}
