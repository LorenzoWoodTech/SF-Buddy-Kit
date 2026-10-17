import Testing
@testable import SFBuddyKit

struct CustomSymbolListingTests {
    private let custom = ["amp", "custom.mixer", "custom.flag.fill", "custom.ear.badge.person.crop"]

    @Test func customCategoryListsOnlyTheHostNamesWithoutVariantFiltering() {
        let listing = SymbolPickerView.listing(category: .custom, searchText: "", groupVariants: true, customSymbols: custom)
        #expect(Set(listing.custom) == Set(custom))
        #expect(listing.symbols.isEmpty)
        #expect(listing.matchedCount == custom.count)
    }

    @Test func customNamesAreNotCapped() {
        let many = (0..<600).map { "custom.icon\($0)" }
        let listing = SymbolPickerView.listing(category: .custom, searchText: "", groupVariants: false, customSymbols: many)
        #expect(listing.custom.count == 600)
    }

    @Test func searchFiltersCustomNames() {
        let listing = SymbolPickerView.listing(category: .custom, searchText: "flag", groupVariants: false, customSymbols: custom)
        #expect(listing.custom == ["custom.flag.fill"])
    }

    /// All is the one grid a compact sheet shows, so the host's icons lead it beside the SF Symbols.
    @Test func allListsCustomNamesBesideSFSymbols() {
        let listing = SymbolPickerView.listing(category: .all, searchText: "amp", groupVariants: false, customSymbols: custom)
        #expect(listing.custom == ["amp"])
        #expect(!listing.symbols.isEmpty)
        #expect(listing.matchedCount >= listing.custom.count + listing.symbols.count)
    }

    @Test func otherCategoriesListNoCustomNames() {
        let listing = SymbolPickerView.listing(category: .media, searchText: "", groupVariants: false, customSymbols: ["custom.music.mic"])
        #expect(listing.custom.isEmpty)
        #expect(!listing.symbols.isEmpty)
    }

    @Test func noCustomNamesLeavesTheSFListingAsItWas() {
        let listing = SymbolPickerView.listing(category: .all, searchText: "", groupVariants: false, customSymbols: [])
        #expect(listing.custom.isEmpty)
        #expect(listing.symbols.count == 400)
    }

    @Test func customCategoryShowsOnlyWithNames() {
        #expect(!SFSymbolCategory.visibleCases(hasCustomSymbols: false).contains(.custom))
        #expect(SFSymbolCategory.visibleCases(hasCustomSymbols: true).contains(.custom))
    }
}
