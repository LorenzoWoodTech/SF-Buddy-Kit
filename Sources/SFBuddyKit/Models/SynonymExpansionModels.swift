//
//  SynonymExpansionModels.swift
//  SFBuddyKit
//
//  Models for two-stage synonym-based symbol recommendation
//

import Foundation

/// Result of the synonym expansion stage
public struct SynonymExpansionResult {
    public let originalTerm: String
    public let synonyms: [String]
    public let directRenderableSymbols: [String]
    
    public init(originalTerm: String, synonyms: [String], directRenderableSymbols: [String]) {
        self.originalTerm = originalTerm
        self.synonyms = synonyms
        self.directRenderableSymbols = directRenderableSymbols
    }
    
    /// All terms to use for stage 2 (original + synonyms)
    public var allTerms: [String] {
        [originalTerm] + synonyms
    }
}

/// Result of the symbol mapping stage
public struct SymbolMappingResult {
    public let validSymbols: [SFSymbolSuggestion]
    public let invalidSymbolNames: [String]
    
    public init(validSymbols: [SFSymbolSuggestion], invalidSymbolNames: [String]) {
        self.validSymbols = validSymbols
        self.invalidSymbolNames = invalidSymbolNames
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
@Generable(description: "Synonyms and related concepts for a search term")
struct SynonymExpansionResponse {
    @Guide(description: "Array of synonyms, related words, and conceptual variations of the original term. Include direct synonyms, metaphors, and visually-related concepts.")
    var synonyms: [String]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable(description: "SF Symbol names for multiple related concepts")
struct MultiConceptSymbolResponse {
    @Guide(description: "Array of SF Symbol names representing the given concepts. Follow SF Symbols naming conventions (e.g., 'house.fill', 'person.circle'). Rank by relevance.")
    var symbols: [String]
}
#endif