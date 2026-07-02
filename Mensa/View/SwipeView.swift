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

    @Binding var daySelection: Int
    
    let days = 0..<7
        
    var body: some View {
        TabView(selection: $daySelection) {
            ForEach(days, id: \.self) { day in
                FoodView(day: day)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

struct SwipeView_Previews: PreviewProvider {
    static var previews: some View {
        SwipeView(daySelection: .constant(0))
    }
}
