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
    @Environment(\.menuService) private var menuService
    @Environment(\.canteenDataSyncer) private var dataSyncer
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekDaysView(selection: self.$daySelection)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                    .background(Color(uiColor: .systemGroupedBackground))
                Divider()
                
                ZStack {
                    SwipeView(daySelection: self.$daySelection)
                        .ignoresSafeArea(edges: .bottom)
                    
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
            menuService.load(viewModel: viewModel, dataSyncer: dataSyncer)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                menuService.load(viewModel: viewModel, dataSyncer: dataSyncer)
            }
        }
        //show alert when no internet connection available TODO: not working ATM
//        .alert(isPresented: self.$viewModel.showAlert) {
//            Alert(title: Text(Constants.NO_INTERNET), message: Text(Constants.CONNECT), dismissButton: Alert.Button.default(
//                Text(Constants.TRY_AGAIN), action:  {
//                    menuService.load(viewModel: viewModel, dataSyncer: dataSyncer) {
//                        self.viewModel.loading = false
//                        self.viewModel.showAlert = false
//                    }
//                }))
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel()
        let repository = Repository()
        let menuService = CanteenMenuService(repository: repository)

        ContentView()
            .environment(viewModel)
            .environment(\.repository, repository)
            .environment(\.menuService, menuService)
    }
}
