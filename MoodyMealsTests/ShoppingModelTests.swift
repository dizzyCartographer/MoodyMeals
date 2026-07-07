import XCTest
import SwiftData
@testable import MoodyMeals

/// M0-5 acceptance: persistence tests for each shopping/inventory/household
/// model. Fresh-context discipline throughout.
final class ShoppingModelTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_shoppingRunAndItems_roundTrip_cascade() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let cod = Ingredient(name: "fresh cod", perishability: .freshShort)
        let run = ShoppingRun(tier: .weekly,
                              plannedDate: Date(timeIntervalSinceNow: 86_400),
                              status: .confirmed)
        context.insert(cod)
        context.insert(run)

        let neededBy = Date(timeIntervalSinceNow: 3 * 86_400)
        let codItem = ShoppingItem(ingredient: cod, amount: 1.5, unit: "lb",
                                   neededBy: neededBy, source: .meal)
        codItem.isPurchased = true // non-default: the bit the guarantee loop flips
        let paperTowels = ShoppingItem(freeText: "paper towels", source: .manual)
        context.insert(codItem)
        context.insert(paperTowels)
        run.items = [codItem, paperTowels]
        try context.save()

        let fresh = ModelContext(container)
        let fetchedRun = try XCTUnwrap(try fresh.fetch(FetchDescriptor<ShoppingRun>()).first)
        XCTAssertEqual(fetchedRun.tier, .weekly)
        XCTAssertEqual(fetchedRun.status, .confirmed)
        XCTAssertEqual(fetchedRun.items.count, 2)
        let fetchedCod = try XCTUnwrap(fetchedRun.items.first { $0.ingredient != nil })
        XCTAssertEqual(fetchedCod.amount, 1.5)
        XCTAssertEqual(fetchedCod.source, .meal)
        XCTAssertEqual(fetchedCod.neededBy?.timeIntervalSince1970 ?? 0,
                       neededBy.timeIntervalSince1970, accuracy: 1)
        XCTAssertTrue(fetchedCod.isPurchased, "the flipped bit must survive the store")
        let fetchedTowels = try XCTUnwrap(fetchedRun.items.first { $0.ingredient == nil })
        XCTAssertEqual(fetchedTowels.freeText, "paper towels")
        XCTAssertEqual(fetchedTowels.source, .manual)
        XCTAssertFalse(fetchedTowels.isPurchased)

        // Deleting the run cascades its items; the ingredient catalog survives.
        fresh.delete(fetchedRun)
        try fresh.save()
        let fresh2 = ModelContext(container)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<ShoppingItem>()).count, 0)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<Ingredient>()).count, 1)
    }

    @MainActor
    func test_itemSource_stapleCase_persists() throws {
        // D-34 (canon): lifeline items carry their own provenance.
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(ShoppingItem(freeText: "garbanzo beans", source: .staple))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<ShoppingItem>()).first)
        XCTAssertEqual(fetched.source, .staple)
    }

    @MainActor
    func test_purchaseRecord_roundTrip_links() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let cojack = Snack(name: "Cojack sticks")
        let cheese = Ingredient(name: "colby jack cheese", perishability: .refrigeratedLong)
        let run = ShoppingRun(tier: .midweek, plannedDate: .now, status: .done)
        context.insert(cojack)
        context.insert(cheese)
        context.insert(run)
        let when = Date(timeIntervalSinceNow: -86_400)
        context.insert(PurchaseRecord(itemName: "Cojack sticks", purchasedAt: when,
                                      ingredient: cheese, snack: cojack, sourceRun: run))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PurchaseRecord>()).first)
        XCTAssertEqual(fetched.itemName, "Cojack sticks")
        XCTAssertEqual(fetched.snack?.name, "Cojack sticks")
        XCTAssertEqual(fetched.ingredient?.name, "colby jack cheese")
        XCTAssertEqual(fetched.sourceRun?.tier, .midweek)
        XCTAssertEqual(fetched.purchasedAt.timeIntervalSince1970,
                       when.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - F18 (D-37 principle on the M0-5 edges)

    @MainActor
    func test_F18_deletedMemberLeavesStapleHouseholdGeneric() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        context.insert(elsie)
        context.insert(StapleItem(name: "garbanzo beans", minOnHand: "2 cans",
                                  forMember: elsie))
        try context.save()

        context.delete(elsie)
        try context.save()

        let fresh = ModelContext(container)
        let staple = try XCTUnwrap(try fresh.fetch(FetchDescriptor<StapleItem>()).first,
                                   "the staple must SURVIVE member deletion")
        XCTAssertNil(staple.forMember,
                     "a deleted member's staple degrades to household-generic")
    }

    @MainActor
    func test_F18_purchaseHistoryOutlivesRunAndSnack() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let cojack = Snack(name: "Cojack sticks")
        let run = ShoppingRun(tier: .weekly, plannedDate: .now, status: .done)
        context.insert(cojack)
        context.insert(run)
        context.insert(PurchaseRecord(itemName: "Cojack sticks", purchasedAt: .now,
                                      snack: cojack, sourceRun: run))
        try context.save()

        context.delete(run)
        context.delete(cojack)
        try context.save()

        let fresh = ModelContext(container)
        let record = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PurchaseRecord>()).first,
                                   "history must SURVIVE its run and snack")
        XCTAssertEqual(record.itemName, "Cojack sticks",
                       "the name-only record is the durable ledger")
        XCTAssertNil(record.sourceRun)
        XCTAssertNil(record.snack)
    }

    @MainActor
    func test_snack_cadenceFields_roundTrip() throws {
        // SN-2 groundwork: manual cadence sets cadenceIsInferred = false.
        let container = try makeContainer()
        let context = container.mainContext

        let inferred = Snack(name: "Cojack sticks", cadenceDays: 5, cadenceIsInferred: true)
        let manual = Snack(name: "GF crackers", cadenceDays: 10, cadenceIsInferred: false)
        let unknown = Snack(name: "new thing") // SN-5: no phantom cadence
        context.insert(inferred)
        context.insert(manual)
        context.insert(unknown)
        try context.save()

        let fresh = ModelContext(container)
        let snacks = try fresh.fetch(FetchDescriptor<Snack>())
        let fetchedInferred = try XCTUnwrap(snacks.first { $0.name == "Cojack sticks" })
        XCTAssertEqual(fetchedInferred.cadenceDays, 5)
        XCTAssertTrue(fetchedInferred.cadenceIsInferred)
        let fetchedManual = try XCTUnwrap(snacks.first { $0.name == "GF crackers" })
        XCTAssertFalse(fetchedManual.cadenceIsInferred)
        let fetchedUnknown = try XCTUnwrap(snacks.first { $0.name == "new thing" })
        XCTAssertNil(fetchedUnknown.cadenceDays)
    }

    @MainActor
    func test_inventoryItem_roundTrip_includingLeftoverKind() throws {
        // D-33 (canon): leftovers are first-class inventory with a useBy.
        let container = try makeContainer()
        let context = container.mainContext

        let confirmed = Date(timeIntervalSinceNow: -3_600)
        let useBy = Date(timeIntervalSinceNow: Double(TuningDefaults.componentFreshnessDays) * 86_400)
        context.insert(InventoryItem(label: "cooked rice", location: .fridge,
                                     confidence: 0.9, lastConfirmedAt: confirmed,
                                     estimatedQuantity: "about 2 cups",
                                     kind: .leftover, useBy: useBy))
        context.insert(InventoryItem(label: "mystery container", location: .fridge,
                                     confidence: 0.3, lastConfirmedAt: confirmed,
                                     flaggedUnclear: true))
        try context.save()

        let fresh = ModelContext(container)
        let items = try fresh.fetch(FetchDescriptor<InventoryItem>())
        let rice = try XCTUnwrap(items.first { $0.label == "cooked rice" })
        XCTAssertEqual(rice.kind, .leftover)
        XCTAssertEqual(rice.useBy?.timeIntervalSince1970 ?? 0,
                       useBy.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(rice.confidence, 0.9)
        XCTAssertEqual(rice.estimatedQuantity, "about 2 cups")
        let mystery = try XCTUnwrap(items.first { $0.flaggedUnclear })
        XCTAssertEqual(mystery.kind, .normal)
        XCTAssertNil(mystery.useBy)
    }

    @MainActor
    func test_wasteEvent_roundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let spinach = Ingredient(name: "spinach", perishability: .freshShort)
        context.insert(spinach)
        context.insert(WasteEvent(itemName: "spinach", ingredient: spinach,
                                  note: "tossed half the spinach again"))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<WasteEvent>()).first)
        XCTAssertEqual(fetched.itemName, "spinach")
        XCTAssertEqual(fetched.ingredient?.name, "spinach")
        XCTAssertEqual(fetched.note, "tossed half the spinach again")
    }

    @MainActor
    func test_checkIn_roundTrip_skippedIsASignal() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(CheckIn(date: .now, capacity: .low, moodNote: "rough one",
                               modality: .oneTap, wasAnswered: true))
        context.insert(CheckIn(date: .now, capacity: nil,
                               modality: .textStyle, wasAnswered: false)) // skipped
        try context.save()

        let fresh = ModelContext(container)
        let checkIns = try fresh.fetch(FetchDescriptor<CheckIn>())
        let answered = try XCTUnwrap(checkIns.first { $0.wasAnswered })
        XCTAssertEqual(answered.capacity, .low)
        XCTAssertEqual(answered.modality, .oneTap)
        let skipped = try XCTUnwrap(checkIns.first { !$0.wasAnswered })
        XCTAssertNil(skipped.capacity, "nil capacity = skipped, a signal in itself")
    }

    @MainActor
    func test_weeklyReflection_roundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let weekStart = Date(timeIntervalSinceNow: -6 * 86_400)
        context.insert(WeeklyReflection(weekStart: weekStart,
                                        summary: "dense week, lots of swaps",
                                        adjustments: ["lowered dense-day effort cap"]))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<WeeklyReflection>()).first)
        XCTAssertEqual(fetched.summary, "dense week, lots of swaps")
        XCTAssertEqual(fetched.adjustments, ["lowered dense-day effort cap"])
    }

    @MainActor
    func test_stapleItem_roundTrip_elsiesLifeline() throws {
        // SCH-13 groundwork (D-6): the lifeline is data, owned per member.
        let container = try makeContainer()
        let context = container.mainContext

        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let garbanzos = Ingredient(name: "garbanzo beans", perishability: .pantry,
                                   isGlutenFreeVerified: true)
        context.insert(elsie)
        context.insert(garbanzos)
        context.insert(StapleItem(name: "garbanzo beans", minOnHand: "2 cans",
                                  ingredient: garbanzos, forMember: elsie))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<StapleItem>()).first)
        XCTAssertEqual(fetched.name, "garbanzo beans")
        XCTAssertEqual(fetched.minOnHand, "2 cans")
        XCTAssertEqual(fetched.forMember?.name, "Elsie")
        XCTAssertEqual(fetched.ingredient?.name, "garbanzo beans")
    }

    @MainActor
    func test_fridgeSpec_roundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(FridgeSpec(modelNumber: "WRF535SWHZ", widthCM: 90.5,
                                  heightCM: 178, depthCM: 80,
                                  shelfNotes: "leftovers front-and-center at eye level"))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<FridgeSpec>()).first)
        XCTAssertEqual(fetched.modelNumber, "WRF535SWHZ")
        XCTAssertEqual(fetched.widthCM, 90.5)
        XCTAssertEqual(fetched.shelfNotes, "leftovers front-and-center at eye level")
    }
}
