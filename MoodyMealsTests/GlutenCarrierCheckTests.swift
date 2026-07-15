import XCTest
@testable import MoodyEngine

/// Recipe-import gluten flagging is deliberately a deterministic word-list
/// match (D-44 canon), not an AI judgment call — these pin the two
/// directions that matter most: obvious carriers flag, whole foods and
/// look-alike false positives never do.
final class GlutenCarrierCheckTests: XCTestCase {

    func test_obviousCarriers_flag() {
        for name in ["flour", "all-purpose flour", "soy sauce", "breadcrumbs",
                     "spaghetti", "beer", "crackers", "hamburger bun"] {
            XCTAssertTrue(GlutenCarrierCheck.isLikelyCarrier(name),
                          "\(name) should flag")
        }
    }

    func test_wholeFoods_neverFlag() {
        for name in ["onion", "garlic", "chicken thighs", "apple", "spinach",
                     "olive oil", "salt", "black pepper", "carrots", "ground beef"] {
            XCTAssertFalse(GlutenCarrierCheck.isLikelyCarrier(name),
                           "\(name) must never flag — whole foods are never marked (D-44 HC-3 spirit)")
        }
    }

    /// The classic false-positive traps: substring matches on unrelated
    /// words. Whole-word tokenization must hold the line here.
    func test_lookAlikeWords_neverFalselyFlag() {
        XCTAssertFalse(GlutenCarrierCheck.isLikelyCarrier("buckwheat"),
                       "buckwheat is naturally GF — must not match \"wheat\"")
        XCTAssertFalse(GlutenCarrierCheck.isLikelyCarrier("a bunch of kale"),
                       "\"bunch\" must not match \"bun\"")
        XCTAssertFalse(GlutenCarrierCheck.isLikelyCarrier("malted milk chocolate"),
                       "\"malted\" tokenizes separately from \"malt\" — acceptable under-match, never a false flag")
    }

    /// Buckwheat FLOUR is still worth a look — the whole-food carve-out is
    /// for bare buckwheat, not every buckwheat-containing product.
    func test_buckwheatFlour_stillFlagsOnFlour() {
        XCTAssertTrue(GlutenCarrierCheck.isLikelyCarrier("buckwheat flour"))
    }

    func test_alreadyMarkedGF_neverFlags() {
        for name in ["gluten free flour", "gluten-free bread", "gf soy sauce",
                     "gluten free pasta"] {
            XCTAssertFalse(GlutenCarrierCheck.isLikelyCarrier(name),
                           "\(name) is already marked GF — nothing to flag")
        }
    }

    func test_match_carriesASuggestion() {
        let match = GlutenCarrierCheck.match(for: "soy sauce")
        XCTAssertEqual(match?.keyword, "soy sauce")
        XCTAssertEqual(match?.suggestion, "tamari or coconut aminos")
    }

    func test_match_wholeFood_isNil() {
        XCTAssertNil(GlutenCarrierCheck.match(for: "carrots"))
    }
}
