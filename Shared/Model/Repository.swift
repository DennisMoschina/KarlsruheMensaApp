//
//  Repository.swift
//  Mensa
//
//  Created by Philipp on 15.11.19.
//  Copyright © 2019 Philipp. All rights reserved.
//

import Foundation
import SwiftSoup

/// Sends canteen data updates to another app component or companion device.
protocol CanteenDataSyncing {
    /// Sends the latest canteen menu and selected price group.
    func sendCanteenDataToWatch(canteen: Canteen, priceGroup: Int)
}

/// Fetches and parses canteen menu data from the Studierendenwerk website.
final class Repository {
    
    //TODO: what is around a new year? when the weeks start from 1 again?
    
    private let totalDaysToFetch = 10
    
    init() {}
    
    /// Loads menu data into the provided app state, reusing cached data when possible.
    func get(refetch: Bool = false, viewModel: ViewModel, dataSyncer: CanteenDataSyncing? = nil) {
        func fetch() {
            viewModel.loading = true
            self.fetchCanteenData(for: viewModel.canteenSelection) { canteen in
                viewModel.canteen = canteen
                viewModel.loading = false
#if os(iOS)
                if let canteenData = viewModel.canteen {
                    let priceGroup = viewModel.priceGroupSelection
                    dataSyncer?.sendCanteenDataToWatch(canteen: canteenData, priceGroup: priceGroup)
                }
#endif
            }
        }

        //if canteen is changed in settings
        if refetch {
            fetchAll()
            return
        }
        
        if let canteenData = viewModel.canteen {
            normalizeCachedCanteen(canteenData)
            
            if canteenData.foodOnDayX.count < 7 {
                fetch()
            }
            else {
#if os(iOS)
                let priceGroup = viewModel.priceGroupSelection
                dataSyncer?.sendCanteenDataToWatch(canteen: canteenData, priceGroup: priceGroup)
#endif
                viewModel.loading = false
            }
        } else {
            fetchAll()
        }
    }
    
    private func fetchCanteenData(for canteenSelection: Canteens, completion: @escaping (Canteen) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekNumber = calendar.component(.weekOfYear, from: today)
        
        var remainingWorkingDays = 0
        
        switch calendar.component(.weekday, from: today) {
        case 1:
            remainingWorkingDays = 0
        case 2:
            remainingWorkingDays = 5
        case 3:
            remainingWorkingDays = 4
        case 4:
            remainingWorkingDays = 3
        case 5:
            remainingWorkingDays = 2
        case 6:
            remainingWorkingDays = 1
        case 7:
            remainingWorkingDays = 0
        default:
            remainingWorkingDays = 0
        }
        
        let daysInUpcomingWeeks = totalDaysToFetch - remainingWorkingDays
        
        let canteen = Canteen(name: canteenSelection.rawValue, foodOnDayX: [:], dateOfLastFetching: Date())
        let dispatchGroup = DispatchGroup()
        
        //this week
        if (remainingWorkingDays > 0) {
            dispatchGroup.enter()
            parseCanteenDataFromWebsite(weekNumber: currentWeekNumber, canteenSelection: canteenSelection, daysToFetch: remainingWorkingDays, startIndex: 0) { foods in
                canteen.foodOnDayX.merge(foods) { (_, new) in new }
                dispatchGroup.leave()
            }
        }
        
        // next week
        dispatchGroup.enter()
        parseCanteenDataFromWebsite(weekNumber: currentWeekNumber + 1, canteenSelection: canteenSelection, daysToFetch: 5, startIndex: remainingWorkingDays) { foods in
            canteen.foodOnDayX.merge(foods) { (_, new) in new }
            dispatchGroup.leave()
        }
        
        // the week after next week, if today isn't Monday
        let daysToFetch = daysInUpcomingWeeks - 5
        let startIndex = remainingWorkingDays + 5
        if (daysToFetch > 0) {
            dispatchGroup.enter()
            parseCanteenDataFromWebsite(weekNumber: currentWeekNumber + 2, canteenSelection: canteenSelection, daysToFetch: daysToFetch, startIndex: startIndex) { foods in
                canteen.foodOnDayX.merge(foods) { (_, new) in new }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async {
                completion(canteen)
            }
        }
    }
    
    private func parseCanteenDataFromWebsite(weekNumber: Int, canteenSelection: Canteens, daysToFetch: Int, startIndex: Int, completion: @escaping ([Int: [FoodLine]]) -> Void) {
        var foodOnDayX: [Int: [FoodLine]] = [:]
        let url = getURL(weekNumber: weekNumber, canteen: canteenSelection)
        
        let task = URLSession.shared.dataTask(with: url) { (data, _, _) in
            var parsedFoodMap: [Int: [FoodLine]] = [:]
            
            guard let data, let html = String(data: data, encoding: .utf8) else {
                print("Unable to convert data to HTML string")
                completion([:])
                return
            }
            
            do {
                let doc: Document = try SwiftSoup.parse(html)
                let dayIDByDate = try self.dayDivIDByDate(doc: doc)
                let dayDateFormatter = DateFormatter()
                dayDateFormatter.dateFormat = "yyyy-MM-dd"
                
                for dayOffset in 0..<daysToFetch {
                    let targetDayIndex = startIndex + dayOffset
                    guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                        continue
                    }
                    
                    let targetDateString = dayDateFormatter.string(from: targetDate)
                    let dayID = dayIDByDate[targetDateString] ?? (dayOffset + 1)
                    guard let canteenDayDiv = try doc.select("#canteen_day_\(dayID)").first() else {
                        continue
                    }
                    
                    let foodLines = try self.parseFoodLines(in: canteenDayDiv)
                    if !foodLines.isEmpty {
                        parsedFoodMap[targetDayIndex] = foodLines
                    }
                }
            } catch Exception.Error(_, let message) {
                print(message)
            } catch {
                print("error")
            }
            
            self.enrichFoodMapWithMealDetails(
                parsedFoodMap,
                startDate: startDate,
                startIndex: startIndex,
                calendar: calendar,
                completion: completion
            )
        }
        
        task.resume()
    }
    
    private func parseFoodLines(in canteenDayDiv: Element) throws -> [FoodLine] {
        var foodLines: [FoodLine] = []
        let rows = try canteenDayDiv.select("tr.mensatype_rows")
        
        for row in rows {
            foodLines.append(try parseFoodLine(from: row))
        }
        
        return foodLines
    }
    
    private func parseFoodLine(from row: Element) throws -> FoodLine {
        let foodlineName = try row.select("td.mensatype div").first()?.ownText() ?? ""
        let foods = try row.select("td.menu-title")
        
        guard !foods.isEmpty else {
            return FoodLine(name: foodlineName, closingText: "-")
        }
        
        if foods.count == 1,
           let onlyFood = foods.first(),
           isExactClosedMealName(try parseFoodName(from: onlyFood)) {
            return FoodLine(name: foodlineName, closingText: "-")
        }
        
        var parsedFoods: [Food] = []
        for food in foods {
            parsedFoods.append(try parseFood(from: food))
        }
        
        return FoodLine(name: foodlineName, foods: parsedFoods)
    }
    
    private func parseFood(from food: Element) throws -> Food {
        let foodName = try parseFoodName(from: food)
        let allergens = try food.select("sup").text()
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        let iconTitle = try food.previousElementSibling()?.select("img").attr("title")
        
        return Food(
            name: foodName,
            bio: true,
            allergens: [allergens],
            prices: try parsePrices(from: food),
            foodClass: getFoodClassFromImage(iconTitle: iconTitle),
            nutritionalInfo: try parseNutritionalInfo(from: food)
        )
    }
    
    private func parseFoodName(from food: Element) throws -> String {
        let foodNameElement = try food.select("span b").first()
        var foodName = try foodNameElement?.text() ?? ""
        
        if let additionalSpanElement = try food.select("span span").first() {
            foodName += " \(try additionalSpanElement.text())"
        }
        
        return foodName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parsePrices(from food: Element) throws -> [Float] {
        var prices = [String]()
        let priceSpans = try food.nextElementSibling()?.select("span.bgp")
        
        for priceSpan in priceSpans ?? Elements() {
            prices.append(try priceSpan.text())
        }
        
        return convertPricesToFloatArray(from: prices)
    }
    
    private func parseNutritionalInfo(from food: Element) throws -> NutritionalInfo? {
        guard let umweltScoreDiv = try food.nextElementSibling()?.select("div.enviroment_score").first() else {
            return nil
        }
        
        let rating = try umweltScoreDiv.attr("data-rating")
        let environmentScore = Int(rating) ?? 0
        let nutritionRow = try food.parent()?.nextElementSibling()
        let energy = try nutritionRow?.select(".energie > div:nth-child(2)").text() ?? ""
        let proteins = try nutritionRow?.select(".proteine > div:nth-child(2)").text() ?? ""
        let carbohydrates = try nutritionRow?.select(".kohlenhydrate > div:nth-child(2)").text() ?? ""
        let sugar = try nutritionRow?.select(".zucker > div:nth-child(2)").text() ?? ""
        let fat = try nutritionRow?.select(".fett > div:nth-child(2)").text() ?? ""
        let saturatedFat = try nutritionRow?.select(".gesaettigt > div:nth-child(2)").text() ?? ""
        let salt = try nutritionRow?.select(".salz > div:nth-child(2)").text() ?? ""
        let co2Value = try nutritionRow?.select(".co2_bewertung_wolke > .value").text() ?? ""
        let co2Score = try Int(nutritionRow?.select(".co2_bewertung_wolke > .enviroment_score").attr("data-rating") ?? "") ?? 0
        let waterValue = try nutritionRow?.select(".wasser_bewertung > .value").text() ?? ""
        let waterScore = try Int(nutritionRow?.select(".wasser_bewertung > .enviroment_score").attr("data-rating") ?? "") ?? 0
        let animalWelfareScore = try Int(nutritionRow?.select(".tierwohl > .enviroment_score").attr("data-rating") ?? "") ?? 0
        let rainforestScore = try Int(nutritionRow?.select(".regenwald > .enviroment_score").attr("data-rating") ?? "") ?? 0
        
        return NutritionalInfo(
            energy: energy,
            proteins: proteins,
            carbohydrates: carbohydrates,
            sugar: sugar,
            fat: fat,
            saturatedFat: saturatedFat,
            salt: salt,
            co2Value: co2Value,
            co2Score: co2Score,
            waterValue: waterValue,
            waterScore: waterScore,
            animalWelfareScore: animalWelfareScore,
            rainforestScore: rainforestScore,
            environmentScore: environmentScore
        )
    }
    
    private func enrichFoodMapWithMealDetails(
        _ foodOnDayX: [Int: [FoodLine]],
        startDate: Date,
        startIndex: Int,
        calendar: Calendar,
        completion: @escaping ([Int: [FoodLine]]) -> Void
    ) {
        let dayIndicesToEnrich = foodOnDayX.keys.sorted().filter {
            foodOnDayX[$0]?.contains(where: { !$0.foods.isEmpty }) == true
        }
        
        guard !dayIndicesToEnrich.isEmpty else {
            completion(foodOnDayX)
            return
        }
        
        let imageGroup = DispatchGroup()
        let imageAssignmentQueue = DispatchQueue(label: "Repository.parseCanteenDataFromWebsite.imageAssignment")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var enrichedFoodMap = foodOnDayX
        
        for dayIndex in dayIndicesToEnrich {
            guard let dateForDay = calendar.date(byAdding: .day, value: dayIndex - startIndex, to: startDate) else {
                continue
            }
            let dateString = dateFormatter.string(from: dateForDay)
            
            imageGroup.enter()
            fetchMealDetailsForDay(date: dateString) { mealDetailsByLine in
                imageAssignmentQueue.async {
                    if var updatedFoodLines = enrichedFoodMap[dayIndex] {
                        self.applyMealDetails(mealDetailsByLine, to: &updatedFoodLines)
                        enrichedFoodMap[dayIndex] = updatedFoodLines
                    }
                    imageGroup.leave()
                }
            }
        }
        
        imageGroup.notify(queue: .main) {
            completion(enrichedFoodMap)
        }
    }
    
    private func fetchMealDetailsForDay(date: String, completion: @escaping ([String: [MealDetails]]) -> Void) {
        let query = """
        query GetMealPlanForDay($date: NaiveDate!) {\n  getCanteens {\n    id\n    name\n    lines {\n      id\n      name\n      meals(date: $date) {\n        id\n        name\n        ratings {\n          averageRating\n          ratingsCount\n          personalRating\n          __typename\n        }\n        images {\n          id\n          url\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  __typename\n}\n
"""
        
        let variables: [String: Any] = ["date": date]
        let body: [String: Any?] = [
            "operationName": nil,
            "variables": variables,
            "query": query
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion([:])
            return
        }
        
        let request = makeAuthorizedJSONRequest(body: jsonData)
        
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let canteens = dataObj["getCanteens"] as? [[String: Any]] else {
                completion([:])
                return
            }
            
            guard let selectedCanteen = self.selectedCanteen(from: canteens) else {
                completion([:])
                return
            }
            
            completion(self.mealDetailsByLine(from: selectedCanteen))
        }
        
        task.resume()
    }
    
    private func selectedCanteen(from canteens: [[String: Any]]) -> [String: Any]? {
        let selectedCanteenName = normalizedMealName(ViewModel.shared.canteenSelection.rawValue)
        return canteens.first(where: {
            guard let canteenName = $0["name"] as? String else { return false }
            return normalizedMealName(canteenName) == selectedCanteenName
        })
    }
    
    private func mealDetailsByLine(from canteen: [String: Any]) -> [String: [MealDetails]] {
        var result: [String: [MealDetails]] = [:]
        
        for line in (canteen["lines"] as? [[String: Any]]) ?? [] {
            guard let lineName = line["name"] as? String else { continue }
            let normalizedLineName = normalizedMealName(lineName)
            let meals = ((line["meals"] as? [[String: Any]]) ?? []).compactMap { meal -> MealDetails? in
                guard let apiName = meal["name"] as? String else {
                    return nil
                }
                
                let apiMealID = meal["id"] as? String
                let ratings = meal["ratings"] as? [String: Any]
                let averageRating = ratings?["averageRating"] as? Double
                let ratingsCount = ratings?["ratingsCount"] as? Int ?? 0
                let personalRating = ratings?["personalRating"] as? Int
                let imageEntries = ((meal["images"] as? [[String: Any]]) ?? []).compactMap { imageDict -> FoodImageEntry? in
                    guard let id = imageDict["id"] as? String,
                          let urlString = imageDict["url"] as? String,
                          let url = URL(string: urlString) else {
                        return nil
                    }
                    return FoodImageEntry(id: id, url: url, rank: nil, personalDownvote: nil, personalUpvote: nil, downvotes: nil, upvotes: nil)
                }
                
                return MealDetails(
                    apiMealID: apiMealID,
                    name: apiName,
                    imageEntries: imageEntries,
                    averageRating: averageRating,
                    ratingsCount: ratingsCount,
                    personalRating: personalRating
                )
            }
            result[normalizedLineName] = meals
        }
        
        return result
    }
    
    private func applyMealDetails(_ mealDetailsByLine: [String: [MealDetails]], to foodLines: inout [FoodLine]) {
        for lineIndex in foodLines.indices {
            guard !foodLines[lineIndex].foods.isEmpty else { continue }
            
            let normalizedLineName = normalizedMealName(foodLines[lineIndex].name)
            let apiMeals: [MealDetails]
            if let exactMatch = mealDetailsByLine[normalizedLineName] {
                apiMeals = exactMatch
            } else if let prefixMatch = mealDetailsByLine.first(where: {
                $0.key.hasPrefix(normalizedLineName + " ") || normalizedLineName.hasPrefix($0.key + " ")
            }) {
                apiMeals = prefixMatch.value
            } else {
                apiMeals = []
            }
            var matchedAPIMealIndices = Set<Int>()
            var matchedDetails = Array<MealDetails?>(repeating: nil, count: foodLines[lineIndex].foods.count)
            
            for foodIndex in foodLines[lineIndex].foods.indices {
                let normalizedFoodName = normalizedMealName(foodLines[lineIndex].foods[foodIndex].name)
                if let exactMatch = apiMeals.enumerated().first(where: {
                    !matchedAPIMealIndices.contains($0.offset) &&
                    normalizedMealName($0.element.name) == normalizedFoodName
                }) {
                    matchedDetails[foodIndex] = exactMatch.element
                    matchedAPIMealIndices.insert(exactMatch.offset)
                }
            }
            
            for foodIndex in foodLines[lineIndex].foods.indices where matchedDetails[foodIndex] == nil {
                guard !apiMeals.isEmpty else { break }
                
                let fallbackIndex: Int?
                if foodIndex < apiMeals.count, !matchedAPIMealIndices.contains(foodIndex) {
                    fallbackIndex = foodIndex
                } else {
                    fallbackIndex = apiMeals.indices.first(where: { !matchedAPIMealIndices.contains($0) })
                }
                
                guard let fallbackIndex else { continue }
                matchedDetails[foodIndex] = apiMeals[fallbackIndex]
                matchedAPIMealIndices.insert(fallbackIndex)
            }
            
            for foodIndex in foodLines[lineIndex].foods.indices {
                let food = foodLines[lineIndex].foods[foodIndex]
                let details = matchedDetails[foodIndex]
                let normalizedName = normalizedMealName(food.name)
                let imageEntries = details?.imageEntries ?? []
                let resolvedImageURL = imageEntries.first?.url ?? cachedImageURL(for: normalizedName)
                
                if let resolvedImageURL {
                    cacheImageURL(resolvedImageURL, for: normalizedName)
                    prefetchImageDataIfNeeded(from: resolvedImageURL)
                }
                
                food.apiMealID = details?.apiMealID
                food.imageEntries = imageEntries
                food.imageURL = resolvedImageURL
                food.averageRating = details?.averageRating
                food.ratingsCount = details?.ratingsCount ?? 0
                food.personalRating = details?.personalRating
            }
        }
    }
    
    func rateMeal(_ food: Food, rating: Int, completion: @escaping (Bool) -> Void) {
        guard let mealID = food.apiMealID else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        let query = "mutation SetRating($mealId: UUID!, $rating: Int!) { setRating(mealId: $mealId, rating: $rating) }"
        let body: [String: Any] = [
            "operationName": "SetRating",
            "variables": [
                "mealId": mealID,
                "rating": rating
            ],
            "query": query
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            DispatchQueue.main.async {
                completion(false)
            }
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
    
    // The website endpoint is week-scoped (`?kw=<weekNumber>`) and this parser expects
    // a contiguous slice within that week. Requested app days can be sparse and can span
    // multiple weeks, so we split them into minimal contiguous per-week chunks here.
    private func buildFetchChunks(for requestedDays: [RequestedDay]) -> [FetchChunk] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: requestedDays) {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)
            return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
        }
        
        var chunks: [FetchChunk] = []
        for group in grouped.values {
            let sortedGroup = group.sorted { $0.date < $1.date }
            var rangeStart = 0
            
            while rangeStart < sortedGroup.count {
                var rangeEnd = rangeStart
                while rangeEnd + 1 < sortedGroup.count {
                    let current = sortedGroup[rangeEnd]
                    let next = sortedGroup[rangeEnd + 1]
                    let currentWeekday = calendar.component(.weekday, from: current.date)
                    let nextWeekday = calendar.component(.weekday, from: next.date)
                    if nextWeekday == currentWeekday + 1 && next.index == current.index + 1 {
                        rangeEnd += 1
                    } else {
                        break
                    }
                }
                
                let first = sortedGroup[rangeStart]
                let daysToFetch = rangeEnd - rangeStart + 1
                
                chunks.append(
                    FetchChunk(
                        weekDate: first.date,
                        startDate: first.date,
                        startIndex: first.index,
                        daysToFetch: daysToFetch
                    )
                )
                
                rangeStart = rangeEnd + 1
            }
        }
        
        return chunks.sorted { $0.startIndex < $1.startIndex }
    }
    
    private func makeAuthorizedJSONRequest(body: Data) -> URLRequest {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiAuthorizationHeader(for: body), forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }
    
    private func sendCurrentCanteenToWatchIfAvailable() {
        guard let canteenData = ViewModel.shared.canteen else { return }
        let priceGroup = ViewModel.shared.priceGroupSelection
        NotificationCenter.default.post(
            name: .repositoryDidUpdateCanteenData,
            object: self,
            userInfo: [
                "canteen": canteenData,
                "priceGroup": priceGroup
            ]
        )
    }
    
    // Cached food is stored by relative working-day indices (`0` = first upcoming day at
    // fetch time), not by absolute dates. After a day rollover those indices drift, so we
    // shift the cached window forward before deciding whether we can still display it.
    private func normalizeCachedCanteen(_ canteen: Canteen) {
        let elapsed = workingDaysElapsed(since: canteen.dateOfLastFetching, until: Date())
        if elapsed > 0 {
            canteen.foodOnDayX.dropAndReduceIndexSmallerThan(elapsed)
        }
        canteen.dateOfLastFetching = Date()
        canteen.nextOpenDays = getNextWorkingDays(date: Date(), count: totalDaysToFetch)
    }
    
    private func workingDaysElapsed(since startDate: Date, until endDate: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard end > start else { return 0 }
        
        var count = 0
        var current = start
        while current < end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            if !calendar.isDateInWeekend(next) {
                count += 1
            }
            current = next
        }
        
        return count
    }
    
    private func dayDivIDByDate(doc: Document) throws -> [String: Int] {
        var result: [String: Int] = [:]
        let navLinks = try doc.select("ul.canteen-day-nav a[id^=canteen_day_nav_]")
        for navLink in navLinks {
            let idAttr = try navLink.id()
            let dayIDString = idAttr.replacingOccurrences(of: "canteen_day_nav_", with: "")
            guard let dayID = Int(dayIDString) else { continue }
            let dateAttr = try navLink.attr("rel").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !dateAttr.isEmpty else { continue }
            result[dateAttr] = dayID
        }
        return result
    }
    
    private func normalizedMealName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private func isExactClosedMealName(_ name: String) -> Bool {
        normalizedMealName(name) == "geschlossen"
    }
    
    private func clearImageCache() {
        imageCacheQueue.sync {
            imageCache.removeAll()
        }
    }
    
    private func cachedImageURL(for normalizedMealName: String) -> URL? {
        imageCacheQueue.sync {
            imageCache[normalizedMealName]
        }
    }
    
    private func cacheImageURL(_ url: URL, for normalizedMealName: String) {
        imageCacheQueue.sync {
            imageCache[normalizedMealName] = url
        }
    }
}
