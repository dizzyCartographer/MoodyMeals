import XCTest
@testable import MoodyEngine

/// M3-1/M3-2 (parse-only slice): MoodyBrain.decode(_:) is the pure half of
/// the recipe-paste parser — no network, so these run offline like every
/// other engine test. The live HTTP path (parseRecipe(from:)) is exercised
/// manually per the project's existing convention for real API/EventKit
/// integrations (see CalendarStore.swift's own "exercised manually" note).
final class MoodyBrainTests: XCTestCase {

    private func toolUseResponse(input: [String: Any]) -> Data {
        let json: [String: Any] = [
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "content": [
                [
                    "type": "tool_use",
                    "id": "toolu_test",
                    "name": "record_recipe",
                    "input": input,
                ],
            ],
            "stop_reason": "tool_use",
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func test_decode_validToolUseResponse_parsesAllFields() throws {
        let data = toolUseResponse(input: [
            "title": "White chicken chili",
            "items": [
                ["name": "chicken thighs", "amount": 1.5, "unit": "lb"],
                ["name": "white beans"],
            ],
            "steps": ["Simmer everything for 30 minutes."],
        ])

        let parsed = try MoodyBrain.decode(data)

        XCTAssertEqual(parsed.title, "White chicken chili")
        XCTAssertEqual(parsed.items, [
            ParsedRecipeItem(name: "chicken thighs", amount: 1.5, unit: "lb"),
            ParsedRecipeItem(name: "white beans", amount: nil, unit: nil),
        ])
        XCTAssertEqual(parsed.steps, ["Simmer everything for 30 minutes."])
    }

    /// SL-2 spirit: an item with no stated amount stays amount-less — the
    /// parser never invents a quantity the text didn't give.
    func test_decode_itemWithoutAmount_staysNil() throws {
        let data = toolUseResponse(input: [
            "title": "Ramen night",
            "items": [["name": "ramen noodles"]],
            "steps": [String](),
        ])

        let parsed = try MoodyBrain.decode(data)

        XCTAssertNil(parsed.items.first?.amount)
        XCTAssertNil(parsed.items.first?.unit)
    }

    func test_decode_blankItemName_isDropped() throws {
        let data = toolUseResponse(input: [
            "title": "Soup",
            "items": [["name": "  "], ["name": "carrots"]],
            "steps": [String](),
        ])

        let parsed = try MoodyBrain.decode(data)

        XCTAssertEqual(parsed.items.map(\.name), ["carrots"])
    }

    func test_decode_noToolUseBlock_throwsMalformedResponse() {
        let data = try! JSONSerialization.data(withJSONObject: [
            "id": "msg_test", "type": "message", "role": "assistant",
            "content": [["type": "text", "text": "I couldn't parse that."]],
            "stop_reason": "end_turn",
        ])

        XCTAssertThrowsError(try MoodyBrain.decode(data)) { error in
            XCTAssertEqual(error as? MoodyBrainError, .malformedResponse)
        }
    }

    func test_decode_blankTitle_throwsMalformedResponse() {
        let data = toolUseResponse(input: ["title": "", "items": [], "steps": []])

        XCTAssertThrowsError(try MoodyBrain.decode(data)) { error in
            XCTAssertEqual(error as? MoodyBrainError, .malformedResponse)
        }
    }
}
