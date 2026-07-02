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
    @Bindable var food: Food
    @Binding var priceGroup: Int
    var onTap: (() -> Void)? = nil

    private var isClosedFood: Bool {
        food.name.localizedCaseInsensitiveContains("geschlossen")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
#if !os(watchOS)
            if !isClosedFood {
                CachedMealCardImageView(url: food.imageURL)
            }
#endif

            VStack(alignment: .leading, spacing: 6) {
                Text(food.name)
                    .fixedSize(horizontal: false, vertical: true)

                if !isClosedFood {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            if food.ratingsCount > 0, let averageRating = food.averageRating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                    Text(String(format: "%.1f", averageRating))
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
