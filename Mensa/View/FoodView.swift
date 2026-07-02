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
    var onFoodSelected: ((Food) -> Void)? = nil
    
    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            let foodLines = self.viewModel.getFoodLines(selectedDay: day)
            let openFoodLines = foodLines.filter { $0.closingText == Constants.EMPTY && !$0.foods.isEmpty }
            let closedFoodLines = foodLines.filter { $0.closingText != Constants.EMPTY || $0.foods.isEmpty }
            
            ForEach(openFoodLines) { foodLine in
                let foods = removeExcludedFood(food: foodLine.foods)

                if (!foods.isEmpty) {
                    Section(header: Text(foodLine.name)) {
                        ForEach(foods, id: \.name) { food in
                            FoodRow(
                                food: food,
                                priceGroup: self.$viewModel.priceGroupSelection,
                                onTap: {
                                    self.onFoodSelected?(food)
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
                } else {
                    let foods = removeUnwantedFood(foods: foodLine.foods, settings: viewModel)

                    if (!foods.isEmpty) {
                        Section(header: Text(foodLine.name)) {
                            ForEach(foods, id: \.name) { food in
                                FoodRow(food: food, priceGroup: $viewModel.priceGroupSelection)
                            }
                            .padding(.bottom, 5)
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.loading = true
            repository.get(viewModel: viewModel, dataSyncer: watchConnectivity)
        }
    }
}


struct FoodView_Previews: PreviewProvider {
    static var previews: some View {
        FoodView(day: 0)
            .environment(ViewModel())
            .environment(WatchConnectivityHandler())
    }
}
