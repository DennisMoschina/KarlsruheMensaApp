//
//  Repository.swift
//  Mensa
//
//  Created by Philipp on 15.11.19.
//  Copyright © 2019 Philipp. All rights reserved.
//

import Foundation

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
            completion(false)
            return
        }

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
            completion(false)
            return
        }

        let request = makeAuthorizedJSONRequest(body: jsonData)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let success = dataObj["setRating"] as? Bool else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            DispatchQueue.main.async {
                completion(success)
            }
        }.resume()
    }

    //TODO: implement
    func uploadImage(food: Food, imageData: Data, completion: @escaping (Bool) -> Void) {
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
