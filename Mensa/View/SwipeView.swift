//
//  SwipeView.swift
//  Mensa
//
//  Created by Philipp on 07.04.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI

/// Native page-based day navigation for the selected menu range.
///
/// This replaces the previous manual drag offset implementation with SwiftUI's
/// page container, keeping direct taps in `WeekDaysView` and horizontal swipes
/// synchronized through the shared day selection binding.
struct SwipeView: View {

    @Environment(ViewModel.self) private var viewModel
    @Environment(\.menuService) private var menuService
    @Environment(\.canteenDataSyncer) private var dataSyncer

    @Binding var daySelection: Int
    private let dayRange = 0..<Constants.DAYS_PER_WEEK
    @State private var selectedFood: Food?

    @ViewBuilder
    private var pagerContent: some View {
        TabView(selection: self.$daySelection) {
            ForEach(self.dayRange, id: \.self) { day in
                ZStack {
                    FoodView(
                        day: day,
                        onFoodSelected: { food in
                            self.selectedFood = food
                        }
                    )
                    .tag(day)
                }
            }
        }
    }
        
    var body: some View {
        ZStack {
            pagerContent
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.92), value: self.daySelection)
                .onChange(of: self.daySelection) { _, newSelection in
                    self.daySelection = max(self.dayRange.lowerBound, min(newSelection, self.dayRange.upperBound - 1))
                }
                .ignoresSafeArea(edges: .bottom)
                .refreshable {
                    viewModel.loading = true
                    menuService.load(viewModel: viewModel, dataSyncer: dataSyncer)
                }

            Color.clear
                .frame(width: 0, height: 0)
                .sheet(item: $selectedFood) { food in
                    DetailedFoodView(food: food)
#if os(iOS)
                        .presentationContentInteraction(.resizes)
#endif
                }
        }
    }
}

struct SwipeView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel()
        let repository = Repository()
        let menuService = CanteenMenuService(repository: repository)

        SwipeView(daySelection: .constant(0))
            .environment(viewModel)
            .environment(\.repository, repository)
            .environment(\.menuService, menuService)
    }
}
