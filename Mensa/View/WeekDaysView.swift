//
//  WeekDays.swift
//  Mensa
//
//  Created by Philipp on 03.04.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI

struct WeekDaysView: View {
    private let maxPhoneLikeWidth: CGFloat = 390
    
    @Binding var selection: Int
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date()
    @State private var workingDays = [Date]()
    @State private var workingDayAbbreviations = [String]()
    @State private var workingDayDigits = [String]()

    private var displayDayCount: Int {
        min(
            Constants.DAYS_PER_WEEK,
            workingDays.count,
            workingDayAbbreviations.count,
            workingDayDigits.count
        )
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                if displayDayCount > 0 {
                    ForEach(0..<displayDayCount, id: \.self) { number in
                        VStack(spacing: 10) {
                            Text(self.workingDayAbbreviations[number])
                                .font(.system(size: 12))
                                .padding(.bottom, 3)
                            
                            if number == self.selection {
                                Text(self.workingDayDigits[number])
                                    .font(.system(size: 18))
                                    .foregroundColor(.white).bold()
                                    .background(Image(systemName: Constants.IMAGE_CIRCLE_FILL)
                                        .font(.system(size: 35))
                                        .foregroundColor(Constants.COLOR_ACCENT))
                                    .onTapGesture {
                                        self.selection = number
                                    }
                            } else if number == 0 {
                                Text(self.workingDayDigits[number])
                                    .font(.system(size: 18))
                                    .foregroundColor(Constants.COLOR_ACCENT)
                                    .onTapGesture {
                                        self.selection = number
                                    }
                            } else {
                                Text(self.workingDayDigits[number])
                                    .font(.system(size: 18))
                                    .onTapGesture {
                                        self.selection = number
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Text(getSelectedDateString(date: self.currentDate, offset: self.selection, onlyDay: false))
                .font(.system(size: 17))
        }
        .frame(maxWidth: maxPhoneLikeWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            updateWorkingDays()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                updateWorkingDays()
            }
        }
        .onChange(of: self.selection) { _, newSelection in
            self.selection = max(0, min(newSelection, Constants.DAYS_PER_WEEK - 1))
        }
    }
    
    private func updateWorkingDays() {
        self.currentDate = Date()
        self.workingDays = getNextWorkingDays(date: self.currentDate, count: Constants.DAYS_PER_WEEK)
        self.workingDayAbbreviations = Date.abbreviations(of: self.workingDays)
        self.workingDayDigits = Date.digits(of: self.workingDays).map { String($0) }
        self.selection = min(self.selection, max(0, displayDayCount - 1))
    }
}

#Preview {
    @Previewable @State var weekDaySelection: Int = 0

    WeekDaysView(selection: $weekDaySelection)
}
