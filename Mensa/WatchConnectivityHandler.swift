//
//  ConnectivityRequestHandler.swift
//  Mensa
//
//  Created by Philipp on 27.10.22.
//  Copyright © 2022 Philipp. All rights reserved.
//

import Foundation
import Observation
import OSLog
import WatchConnectivity

/// Handles outgoing updates from the iOS app to the companion watch app.
@Observable
final class WatchConnectivityHandler: NSObject, CanteenDataSyncing {
    
    @ObservationIgnored
    var session = WCSession.default

    @ObservationIgnored
    private let viewModel: ViewModel

    @ObservationIgnored
    private let menuService: CanteenMenuService
    
    /// Creates a watch connectivity bridge that can serve canteen data requests.
    init(viewModel: ViewModel, menuService: CanteenMenuService) {
        self.viewModel = viewModel
        self.menuService = menuService
        super.init()
        self.session.delegate = self
        if session.activationState != .activated {
            AppLog.connectivity.info("Activating watch connectivity session")
            self.session.activate()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRepositoryCanteenUpdate(_:)),
            name: .repositoryDidUpdateCanteenData,
            object: nil
        )
    }
    
    /// Sends full canteen data immediately or queues it for later delivery.
    func sendCanteenData(canteen: Canteen, priceGroup: Int) {
        if self.session.isReachable {
            if let encodedData = try? JSONEncoder().encode(canteen) {
                AppLog.connectivity.info("Sending canteen payload to watch with \(encodedData.count) bytes")
                self.session.sendMessage(["canteen" : encodedData, "priceGroup" : priceGroup], replyHandler: nil)
            } else {
                AppLog.connectivity.error("Failed to encode canteen payload for watch")
            }
        }
        else {
            AppLog.connectivity.info("Watch app not reachable; transferring canteen payload as user info")
            if let encodedData = try? JSONEncoder().encode(canteen) {
                self.session.transferUserInfo(["canteen" : encodedData, "priceGroup" : priceGroup])
            } else {
                AppLog.connectivity.error("Failed to encode canteen payload for queued watch transfer")
            }
        }
    }
    
    /// Sends a price-group-only update.
    func sendPriceGroup(_ priceGroup: Int) {
        if self.session.isReachable {
            AppLog.connectivity.info("Sending price group \(priceGroup) to watch")
            self.session.sendMessage(["priceGroup" : priceGroup], replyHandler: nil)
        }
        else {
            AppLog.connectivity.info("Watch app not reachable; transferring price group \(priceGroup) as user info")
            self.session.transferUserInfo(["priceGroup" : priceGroup])
        }
    }
    
    private func refreshAndSendCanteenDataToWatch() {
        AppLog.connectivity.info("Refreshing canteen data after watch request")
        menuService.load(viewModel: viewModel, dataSyncer: self)
    }
}

extension WatchConnectivityHandler: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            AppLog.connectivity.error("Watch session activation failed: \(error.localizedDescription, privacy: .public)")
        } else {
            AppLog.connectivity.info("Watch session activated with state \(activationState.rawValue), paired: \(session.isPaired), watch app installed: \(session.isWatchAppInstalled)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        AppLog.connectivity.info("Watch session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        AppLog.connectivity.info("Watch session deactivated; reactivating")
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        AppLog.connectivity.info("Watch state changed, paired: \(session.isPaired), watch app installed: \(session.isWatchAppInstalled)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let requestCanteenData = message["requestCanteenData"] as? Bool, requestCanteenData {
            AppLog.connectivity.info("Received immediate canteen data request from watch")
            DispatchQueue.main.async {
                self.refreshAndSendCanteenDataToWatch()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let requestCanteenData = userInfo["requestCanteenData"] as? Bool, requestCanteenData {
            AppLog.connectivity.info("Received queued canteen data request from watch")
            DispatchQueue.main.async {
                self.refreshAndSendCanteenDataToWatch()
            }
        }
    }
}
