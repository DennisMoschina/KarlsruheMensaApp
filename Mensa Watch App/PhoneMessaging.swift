//
//  PhoneMessaging.swift
//  Watch Mensa Extension
//
//  Created by Philipp on 27.10.22.
//  Copyright © 2022 Philipp. All rights reserved.
//

import Foundation
import Observation
import OSLog
import WatchConnectivity

/// Receives canteen and settings updates from the paired iPhone.
@Observable
final class PhoneMessaging: NSObject {
    
    @ObservationIgnored
    private var session = WCSession.default

    @ObservationIgnored
    private let viewModel: ViewModel
    
    var canteenSelection: Int = 0
    var priceGroup: Int = 0
    
    /// Creates a phone messaging bridge that writes received menus into app state.
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        self.session.delegate = self
        self.session.activate()
        AppLog.connectivity.info("Activated phone messaging session on watch")
        
        self.canteenSelection = UserDefaults.standard.integer(forKey: Constants.KEY_CHOSEN_CANTEEN)
        self.priceGroup = UserDefaults.standard.integer(forKey: Constants.KEY_CHOSEN_PRICE_GROUP)
    }

    /// Requests the latest canteen payload from the paired iPhone.
    func requestCanteenDataFromPhone() {
        guard self.session.activationState == .activated else {
            AppLog.connectivity.warning("Skipped canteen data request because watch session is not activated")
            return
        }
        if self.session.isReachable {
            AppLog.connectivity.info("Requesting canteen data from reachable phone")
            self.session.sendMessage(["requestCanteenData": true], replyHandler: nil)
        } else {
            AppLog.connectivity.info("Phone not reachable; queuing canteen data request")
            self.session.transferUserInfo(["requestCanteenData": true])
        }
    }
}

extension PhoneMessaging: WCSessionDelegate {
    /// Handles watch connectivity activation completion.
    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            AppLog.connectivity.error("Phone messaging activation failed: \(error.localizedDescription, privacy: .public)")
        } else {
            AppLog.connectivity.info("Phone messaging activated with state \(activationState.rawValue)")
        }
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {}
#endif
    
    //when app is running on watch as well as on phone -> immediate ui change on watch, if canteen changes on phone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let newCanteenSelection = message["canteenSelection"] as? Int {
                self.canteenSelection = newCanteenSelection
                UserDefaults.standard.set(newCanteenSelection, forKey: Constants.KEY_CHOSEN_CANTEEN)
                AppLog.connectivity.info("Received canteen selection \(newCanteenSelection) from phone message")
            }
            
            if let canteenData = message["canteen"] as? Data {
                do {
                    let canteen = try JSONDecoder().decode(Canteen.self, from: canteenData)
                    self.viewModel.canteen = canteen
                    AppLog.connectivity.info("Received canteen payload from phone message with \(canteenData.count) bytes")
                } catch {
                    AppLog.connectivity.error("Failed to decode canteen data from phone message: \(error.localizedDescription, privacy: .public)")
                }
            }
            
            if let newPriceGroup = message["priceGroup"] as? Int {
                self.priceGroup = newPriceGroup
                UserDefaults.standard.set(newPriceGroup, forKey: Constants.KEY_CHOSEN_PRICE_GROUP)
                AppLog.connectivity.info("Received price group \(newPriceGroup) from phone message")
            }
        }
    }
    
    //when watch app is not running
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            if let newCanteenSelection = userInfo["canteenSelection"] as? Int {
                UserDefaults.standard.set(newCanteenSelection, forKey: Constants.KEY_CHOSEN_CANTEEN)
                self.canteenSelection = newCanteenSelection
                AppLog.connectivity.info("Received queued canteen selection \(newCanteenSelection)")
            }
            
            if let canteenData = userInfo["canteen"] as? Data {
                do {
                    let canteen = try JSONDecoder().decode(Canteen.self, from: canteenData)
                    self.viewModel.canteen = canteen
                    AppLog.connectivity.info("Received queued canteen payload with \(canteenData.count) bytes")
                } catch {
                    AppLog.connectivity.error("Failed to decode queued canteen data: \(error.localizedDescription, privacy: .public)")
                }
            }
            
            if let newPriceGroup = userInfo["priceGroup"] as? Int {
                self.priceGroup = newPriceGroup
                UserDefaults.standard.set(newPriceGroup, forKey: Constants.KEY_CHOSEN_PRICE_GROUP)
                AppLog.connectivity.info("Received queued price group \(newPriceGroup)")
            }
        }
    }
}
