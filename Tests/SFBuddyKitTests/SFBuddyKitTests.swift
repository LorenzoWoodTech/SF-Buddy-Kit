import Testing
@testable import SFBuddyKit

struct CustomSymbolListingTests {
    private let custom = ["amp", "custom.mixer", "custom.flag.fill", "custom.ear.badge.person.crop"]

    @Test func customCategoryListsTheHostNamesWithoutVariantFiltering() {
        let listing = SymbolPickerView.listing(category: .custom, searchText: "", groupVariants: true, customSymbols: custom)
        #expect(Set(listing.symbols) == Set(custom))
        #expect(listing.matchedCount == custom.count)
    }

    @Test func customCategoryIsNotCapped() {
        let many = (0..<600).map { "custom.icon\($0)" }
        let listing = SymbolPickerView.listing(category: .custom, searchText: "", groupVariants: false, customSymbols: many)
        #expect(listing.symbols.count == 600)
    }

    @Test func searchFiltersCustomNames() {
        let listing = SymbolPickerView.listing(category: .custom, searchText: "flag", groupVariants: false, customSymbols: custom)
        #expect(listing.symbols == ["custom.flag.fill"])
    }

    @Test func otherCategoriesListOnlySFSymbols() {
        let listing = SymbolPickerView.listing(category: .all, searchText: "amp", groupVariants: false, customSymbols: custom)
        #expect(!listing.symbols.isEmpty)
        #expect(!listing.symbols.contains("amp"))
    }

    @Test func customCategoryShowsOnlyWithNames() {
        #expect(!SFSymbolCategory.visibleCases(hasCustomSymbols: false).contains(.custom))
        #expect(SFSymbolCategory.visibleCases(hasCustomSymbols: true).contains(.custom))
    }
}
