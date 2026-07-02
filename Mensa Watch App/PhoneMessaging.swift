//
//  PhoneMessaging.swift
//  Watch Mensa Extension
//
//  Created by Philipp on 27.10.22.
//  Copyright © 2022 Philipp. All rights reserved.
//

import Foundation
import Observation
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
        
        self.canteenSelection = UserDefaults.standard.integer(forKey: Constants.KEY_CHOSEN_CANTEEN)
        self.priceGroup = UserDefaults.standard.integer(forKey: Constants.KEY_CHOSEN_PRICE_GROUP)
    }
    
    func requestCanteenDataFromPhone() {
        guard self.session.activationState == .activated else { return }
        if self.session.isReachable {
            self.session.sendMessage(["requestCanteenData": true], replyHandler: nil)
        } else {
            self.session.transferUserInfo(["requestCanteenData": true])
        }
    }
}

extension PhoneMessaging: WCSessionDelegate {
    /// Handles watch connectivity activation completion.
    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        debugPrint("WCSession activationDidCompleteWith activationState:\(activationState) error:\(String(describing: error))")
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {}
#endif
    
    //when app is running on watch as well as on phone -> immediate ui change on watch, if canteen changes on phone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let newCanteenSelection = message["canteenSelection"] as? Int {
            self.canteenSelection = newCanteenSelection
            UserDefaults.standard.set(newCanteenSelection, forKey: Constants.KEY_CHOSEN_CANTEEN)
            print("updated canteen selection!")
            print("new selection: \(newCanteenSelection)")
        }
        
        if let canteenData = message["canteen"] as? Data {
            do {
                let canteen = try JSONDecoder().decode(Canteen.self, from: canteenData)
                viewModel.canteen = canteen
            } catch {
                print("Failed to decode canteen data: \(error)")
            }
        }
    }
    
    //when watch app is not running
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let newCanteenSelection = userInfo["canteenSelection"] as? Int {
            UserDefaults.standard.set(newCanteenSelection, forKey: Constants.KEY_CHOSEN_CANTEEN)
            self.canteenSelection = newCanteenSelection
        }
        
        if let canteenData = userInfo["canteen"] as? Data {
            do {
                let canteen = try JSONDecoder().decode(Canteen.self, from: canteenData)
                viewModel.canteen = canteen
            } catch {
                print("Failed to decode canteen data: \(error)")
            }
        }
    }
}
