//
//  AppLogger.swift
//  Mensa
//
//  Created by Codex on 02.08.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation
import OSLog

/// Centralized unified logging categories used by the app, widgets, and watch extension.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "edu.teco.ilteen.Mensa"

    /// Menu loading, cache hydration, and menu publication events.
    static let menu = Logger(subsystem: subsystem, category: "menu")

    /// Studierendenwerk HTML/API transport and parsing events.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// SwiftData and app-group persistence events.
    static let storage = Logger(subsystem: subsystem, category: "storage")

    /// Phone/watch connectivity events.
    static let connectivity = Logger(subsystem: subsystem, category: "connectivity")

    /// Widget timeline and snapshot events.
    static let widgets = Logger(subsystem: subsystem, category: "widgets")

    /// Meal rating and image upload events.
    static let meals = Logger(subsystem: subsystem, category: "meals")
    
    /// UI events.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
