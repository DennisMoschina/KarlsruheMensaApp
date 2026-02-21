//
//  TitleBarView.swift
//  Mensa
//
//  Created by Philipp on 07.04.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI

struct TitleBarView: View {
    @Environment(ViewModel.self) private var settings
    
    var body: some View {
        Text(settings.canteenSelection.rawValue)
            .font(.system(size: 20))
            .bold()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TitleBarView_Previews: PreviewProvider {
    static var previews: some View {
        TitleBarView()
            .environment(ViewModel())
    }
}
