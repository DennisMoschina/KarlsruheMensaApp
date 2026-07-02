//
//  FoodRow.swift
//  Mensa
//
//  Created by Philipp on 13.05.23.
//  Copyright © 2023 Philipp. All rights reserved.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct FoodRow: View {
    let food: Food
    @Binding var priceGroup: Int
    @State private var isShowingNutritionalInfo = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
#if !os(watchOS)
            if !isClosedFood {
                CachedMealCardImageView(url: food.imageURL)
            }
            
            if (food.foodClass != FoodClass.nothing || food.allergens.isEmpty) {            
                HStack {
                    if (food.foodClass != FoodClass.nothing) {
                        Text(NSLocalizedString(String(describing: food.foodClass), comment: Constants.EMPTY))
                            .font(.system(size: 10))
                            .italic()
                    }
                    
                    if (!food.allergens.isEmpty) {
                        Text(allergensString(allergens: food.allergens))
                            .font(.system(size: 10))
                            .foregroundColor(Color.gray)
                    }
                    
#if os(iOS)
                    if food.nutritionalInfo != nil {
                        Button(action: {
                            isShowingNutritionalInfo.toggle()
                        }) {
                            if isShowingNutritionalInfo {
                                Image(systemName: "chevron.up")
                                    .foregroundColor(Constants.COLOR_ACCENT)
                            }
                            else {
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Constants.COLOR_ACCENT)
                            }
                            
                            Text(NSLocalizedString(String(describing: food.foodClass), comment: Constants.EMPTY))
                                .font(.system(size: 10))
                                .italic()
                                .lineLimit(1)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 8)

                        if !food.prices.isEmpty && food.prices.indices.contains(self.priceGroup) && food.prices[self.priceGroup] != 0.0 {
                            Text(food.prices[self.priceGroup].Euro)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            
#if os(iOS)
            if isShowingNutritionalInfo {
                    NutritionalInfoView(food: food)
                        .padding(.top, 5)
            }
#endif
        }
#if os(iOS)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isClosedFood {
                onTap?()
            }
        }
#endif
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}


struct ClosedRow: View {
    let info: String
    var body: some View {
        Text(info).font(.system(size: 12)).foregroundColor(Color.gray).frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    FoodRow(food: Food(name: "Spaghetti", bio: false, allergens: ["a", "b"], prices: [3.6, 3.8], foodClass: .beef, nutritionalInfo: nil), priceGroup: .constant(0))
}
