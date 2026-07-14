import Foundation

// ── M3-1 (thin slice) + M3-2 parse-only — brain-dump → recipe ────────────
// A minimal Claude client: paste recipe text in, get {title, items, steps}
// back. Deliberately does NOT run the D-44 GF-band assessment (HC-7) — that
// half of M3-2 is a separate, larger, PROMPT-REVIEW-gated pass. Recipes
// created from a parse land at the same GFBand.notCheckedYet default as any
// manually-typed recipe, so "never silently safe" still holds.
//
// NL-7 (payload minimization): this call sends only the pasted text — no
// household/health-profile fields ever enter the request.
// NL-8 (offline/failure): throws; callers degrade to manual entry, no crash.

enum MoodyBrainError: Error, Equatable {
    case notConfigured        // no ANTHROPIC_API_KEY in the environment
    case requestFailed(Int)   // non-2xx HTTP status
    case malformedResponse    // 2xx but the tool_use input didn't parse
}

struct ParsedRecipeItem: Equatable {
    var name: String
    var amount: Double?
    var unit: String?
}

struct ParsedRecipe: Equatable {
    var title: String
    var items: [ParsedRecipeItem]
    var steps: [String]
}

enum MoodyBrain {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-opus-4-8"

    static func parseRecipe(from text: String) async throws -> ParsedRecipe {
        // Keys come from the environment only — never committed (CLAUDE.md).
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              !apiKey.isEmpty else {
            throw MoodyBrainError.notConfigured
        }

        let tool: [String: Any] = [
            "name": "record_recipe",
            "description": "Record a recipe parsed from pasted, messy text.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "The recipe's name."],
                    "items": [
                        "type": "array",
                        "description": "Every ingredient line, in the order given.",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "amount": ["type": "number",
                                          "description": "Numeric quantity — omit if the text gives none."],
                                "unit": ["type": "string",
                                        "description": "e.g. lb, cup, clove — omit if none given."],
                            ],
                            "required": ["name"],
                        ],
                    ],
                    "steps": [
                        "type": "array", "items": ["type": "string"],
                        "description": "One instruction per step; [] if the text has none.",
                    ],
                ],
                "required": ["title", "items", "steps"],
            ],
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "output_config": ["effort": "low"],
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "record_recipe"],
            "messages": [
                ["role": "user", "content":
                    "Parse this into a recipe. Only record an amount or unit when the text " +
                    "states one explicitly — never infer or estimate a quantity.\n\n\(text)"],
            ],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MoodyBrainError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try decode(data)
    }

    /// Pure decode of a Messages API response into the forced `record_recipe`
    /// tool call's input — split out from the network call so it's testable
    /// without hitting the API.
    static func decode(_ data: Data) throws -> ParsedRecipe {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolUse = content.first(where: { $0["type"] as? String == "tool_use" }),
              let input = toolUse["input"] as? [String: Any],
              let title = input["title"] as? String, !title.isEmpty
        else { throw MoodyBrainError.malformedResponse }

        let items = (input["items"] as? [[String: Any]] ?? []).compactMap { raw -> ParsedRecipeItem? in
            guard let name = raw["name"] as? String,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ParsedRecipeItem(name: name, amount: raw["amount"] as? Double,
                                    unit: raw["unit"] as? String)
        }
        let steps = (input["steps"] as? [String]) ?? []
        return ParsedRecipe(title: title, items: items, steps: steps)
    }
}
