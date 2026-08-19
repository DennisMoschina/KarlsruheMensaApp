//
//  Repository.swift
//  Mensa
//
//  Created by Philipp on 15.11.19.
//  Copyright © 2019 Philipp. All rights reserved.
//

import Foundation
import OSLog

/// Assembles canteen menu payloads from an injectable data source and owns API mutations.
final class Repository {
    private let totalDaysToFetch = 10
    private let dataSource: CanteenMenuDataSource

    /// Creates a repository backed by the default Studierendenwerk HTML source.
    init(dataSource: CanteenMenuDataSource = StudierendenwerkHTMLCanteenMenuDataSource()) {
        self.dataSource = dataSource
    }

    /// Fetches a full canteen payload for the selected canteen.
    func fetchMenu(
        canteenSelection: Canteens,
        updating canteen: Canteen? = nil,
        resetSourceCache: Bool,
        completion: @escaping (Canteen) -> Void
    ) {
        AppLog.menu.info("Fetching menu payload for \(canteenSelection.rawValue, privacy: .public), reset source cache: \(resetSourceCache)")
        if resetSourceCache {
            dataSource.resetTransientCache()
        }

        let now = Date()
        let requestedDates = getNextWorkingDays(date: now, count: totalDaysToFetch)
        let requestedDays = requestedDates.enumerated().map {
            CanteenMenuDayRequest(index: $0.offset, date: $0.element)
        }

        dataSource.loadMenuLines(for: requestedDays, canteenSelection: canteenSelection) { foodMap in
            DispatchQueue.main.async {
                if let canteen {
                    AppLog.menu.debug("Merging \(foodMap.count) fetched menu days into existing canteen payload")
                    canteen.foodOnDayX.merge(foodMap) { _, new in new }
                    canteen.dateOfLastFetching = now
                    canteen.nextOpenDays = requestedDates
                    completion(canteen)
                } else {
                    let canteen = Canteen(
                        name: canteenSelection.rawValue,
                        foodOnDayX: foodMap,
                        dateOfLastFetching: now
                    )
                    canteen.nextOpenDays = requestedDates
                    completion(canteen)
                }
            }
        }
    }

    /// Persists a user rating for one meal.
    func rateMeal(_ food: Food, rating: Int, completion: @escaping (Bool) -> Void) {
        guard let mealID = food.apiMealID else {
            AppLog.meals.warning("Skipping meal rating because the meal has no API id")
            completion(false)
            return
        }

        AppLog.meals.info("Submitting meal rating \(rating) for meal \(mealID, privacy: .private)")
        let mutation = """
        mutation SetRating($mealId: UUID!, $stars: Int) {\n  setRating(mealId: $mealId, stars: $stars)\n}\n
"""

        let variables: [String: Any] = [
            "mealId": mealID,
            "stars": rating
        ]

        let body: [String: Any?] = [
            "operationName": nil,
            "variables": variables,
            "query": mutation
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            AppLog.meals.error("Failed to encode meal rating request for meal \(mealID, privacy: .private)")
            completion(false)
            return
        }

        let request = makeAuthorizedJSONRequest(body: jsonData)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let success = dataObj["setRating"] as? Bool else {
                AppLog.meals.error("Failed to decode meal rating response for meal \(mealID, privacy: .private)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            DispatchQueue.main.async {
                AppLog.meals.info("Meal rating request completed with success: \(success)")
                completion(success)
            }
        }.resume()
    }

    //TODO: implement
    func uploadImage(food: Food, imageData: Data, completion: @escaping (Bool) -> Void) {
        AppLog.meals.warning("Meal image upload requested before upload API is implemented")
        // Placeholder until upload API endpoints are wired in.
        DispatchQueue.main.async {
            completion(false)
        }
    }

    private func makeAuthorizedJSONRequest(body: Data) -> URLRequest {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiAuthorizationHeader(for: body), forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }
}
