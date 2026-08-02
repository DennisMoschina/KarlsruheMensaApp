//
//  WidgetMenuSummaryService.swift
//  MensaWidgetExtension
//
//  Created by Codex on 03.07.26.
//  Copyright © 2026 Philipp. All rights reserved.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Creates short widget summaries for menu lines.
enum WidgetMenuSummaryService {
    /// Returns a concise "main dish" style summary for a menu line.
    static func summary(for line: WidgetFoodLine) async -> String {
        guard !line.foods.isEmpty else {
            return line.closingText.isEmpty ? "Closed" : line.closingText
        }

#if canImport(FoundationModels)
        if #available(iOSApplicationExtension 26.0, *) {
            if let generated = await AppleIntelligenceSummaryGenerator().summary(for: line) {
                return generated
            }
        }
#endif

        return RuleBasedMenuSummarizer.summary(for: line)
    }
}

#if canImport(FoundationModels)
@available(iOSApplicationExtension 26.0, *)
private struct AppleIntelligenceSummaryGenerator {
    /// Uses Apple's on-device language model to extract the main dish when available.
    func summary(for line: WidgetFoodLine) async -> String? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let dishNames = line.foods.map(\.name).joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
        You summarize German university canteen menu lines for a small iOS widget.
        Return only the primary main dish or a compact common theme.
        Use the same language as the menu names.
        Keep the answer under 55 characters.
        """)

        do {
            let response = try await session.respond(to: """
            Line: \(line.name)
            Dishes:
            \(dishNames)
            """)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(70))
        } catch {
            return nil
        }
    }
}
#endif

private enum RuleBasedMenuSummarizer {
    private static let separators = [
        " mit ",
        " an ",
        " auf ",
        " dazu ",
        " und ",
        " / "
    ]

    /// Picks a readable main-dish phrase without requiring Apple Intelligence.
    static func summary(for line: WidgetFoodLine) -> String {
        guard let firstDish = line.foods.first?.name else {
            return line.name
        }

        let compact = firstDish
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercased = compact.lowercased()
        if let separator = separators.first(where: { lowercased.contains($0) }),
           let range = lowercased.range(of: separator) {
            let mainDish = compact[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !mainDish.isEmpty {
                return String(mainDish.prefix(70))
            }
        }

        return String(compact.prefix(70))
    }
}
