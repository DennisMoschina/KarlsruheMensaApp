//
//  MensaWidgetsBundle.swift
//  MensaWidgetExtension
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import WidgetKit
import SwiftUI

/// Registers all Mensa widgets exposed by the extension.
@main
struct MensaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MensaOverviewWidget()
        MensaLineWidget()
    }
}
