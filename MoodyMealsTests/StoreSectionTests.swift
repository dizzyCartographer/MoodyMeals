import XCTest
@testable import MoodyEngine

/// SHOP-4: store-section inference — perishability picks the temperature
/// zone, whole-word matching splits the fresh zones. Wrong guesses are
/// cosmetic, but the canonical cases must hold.
final class StoreSectionTests: XCTestCase {

    func test_perishabilityDecidesTheTemperatureZone() {
        XCTAssertEqual(StoreSection.infer(name: "rice", perishability: .pantry),
                       .pantry)
        XCTAssertEqual(StoreSection.infer(name: "peas", perishability: .freezer),
                       .frozen)
        XCTAssertEqual(StoreSection.infer(name: "spinach", perishability: .freshShort),
                       .produce)
    }

    func test_wordsSplitTheFreshZones() {
        XCTAssertEqual(StoreSection.infer(name: "ground beef", perishability: .freshShort),
                       .meat)
        XCTAssertEqual(StoreSection.infer(name: "fresh cod", perishability: .freshShort),
                       .meat)
        XCTAssertEqual(StoreSection.infer(name: "milk", perishability: .refrigeratedLong),
                       .dairy)
        XCTAssertEqual(StoreSection.infer(name: "shredded cheese", perishability: .refrigeratedLong),
                       .dairy)
    }

    func test_wholeWordMatching_eggplantIsNotAnEgg() {
        XCTAssertEqual(StoreSection.infer(name: "eggplant", perishability: .freshShort),
                       .produce)
    }

    func test_chilledWithoutAKeyword_livesWithDairy() {
        // The refrigerated case at the store IS the dairy wall for most
        // stores — salsa, tortilla dough, kombucha all live there.
        XCTAssertEqual(StoreSection.infer(name: "salsa", perishability: .refrigeratedLong),
                       .dairy)
    }

    func test_pantryBeatsWords_aFrozenBagBeatsWordsToo() {
        // Temperature zone wins: canned chicken is pantry, frozen shrimp
        // is frozen — the words only split the FRESH zones.
        XCTAssertEqual(StoreSection.infer(name: "canned chicken", perishability: .pantry),
                       .pantry)
        XCTAssertEqual(StoreSection.infer(name: "shrimp", perishability: .freezer),
                       .frozen)
    }
}
