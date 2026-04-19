//
//  FoodView.swift
//  Mensa
//
//  Created by Philipp on 06.04.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI
 
struct FoodView: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(WatchConnectivityHandler.self) private var watchConnectivity
    @Environment(\.repository) private var repository
    var day: Int
    var onDetailPresentationChange: ((Bool) -> Void)? = nil
    
    @State private var selectedFood: Food? = nil
    
    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            let foodLines = self.viewModel.getFoodLines(selectedDay: day)
            let openFoodLines = foodLines.filter { $0.closingText == Constants.EMPTY && !$0.foods.isEmpty }
            let closedFoodLines = foodLines.filter { $0.closingText != Constants.EMPTY || $0.foods.isEmpty }
            
            ForEach(openFoodLines) { foodLine in
                let foods = removeUnwantedFood(foods: foodLine.foods, settings: viewModel)

                if (!foods.isEmpty) {
                    Section(header: Text(foodLine.name)) {
                        ForEach(foods, id: \.name) { food in
                            FoodRow(
                                food: food,
                                priceGroup: self.$viewModel.priceGroupSelection,
                                onTap: {
                                    self.selectedFood = food
                                    self.onDetailPresentationChange?(true)
                                }
                            )
                        }
                    }
                }
            }
            
            ForEach(closedFoodLines) { foodLine in
                if foodLine.foods.isEmpty {
                    Section(header: Text(foodLine.name + Constants.DASH + Constants.FOOD_LINE_CLOSED)) {
                        ClosedRow(info: Constants.DASH)
                    }
                }
            }
            
            ForEach(closedFoodLines) { foodLine in
                if foodLine.foods.isEmpty {
                    Section(header: Text(foodLine.name + Constants.DASH + Constants.FOOD_LINE_CLOSED)) {
                        ClosedRow(info: Constants.DASH)
                    }
                } else {
                    Section(header: Text(foodLine.name)) {
                        ClosedRow(info: foodLine.closingText)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loading = true
            repository.get(viewModel: viewModel, dataSyncer: watchConnectivity)
        }
        .sheet(item: $selectedFood) { food in
            DetailedFoodView(food: food)
#if os(iOS)
                .presentationContentInteraction(.resizes)
#endif
        }
        .onChange(of: selectedFood?.id) { _ in
            onDetailPresentationChange?(selectedFood != nil)
        }
    }
}


struct FoodView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ViewModel()
        let repository = Repository()

        FoodView(day: 0)
            .environment(viewModel)
            .environment(WatchConnectivityHandler(viewModel: viewModel, repository: repository))
            .environment(\.repository, repository)
    }
}
