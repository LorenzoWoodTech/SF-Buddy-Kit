//
//  SFSymbolService.swift
//  SF Buddy
//

import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Combine
import SFSafeSymbols

// Foundation Models requires iOS 26.0+ / macOS 26.0+
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
public class SFSymbolService: ObservableObject {
    public static let shared = SFSymbolService()
    private static let userDefaultsAPIKey = "ClaudeAPIKey"

    // MARK: - Error Handling

    public enum AIServiceError: Equatable {
        case none
        case claudeAPIKeyMissing
        case claudeAPIKeyInvalid
        case appleIntelligenceUnavailable(reason: String)
        case noProviderAvailable
        
        var title: String {
            switch self {
            case .none: return ""
            case .claudeAPIKeyMissing: return "Claude API Key Missing"
            case .claudeAPIKeyInvalid: return "Claude API Key Invalid"
            case .appleIntelligenceUnavailable: return "Apple Intelligence Unavailable"
            case .noProviderAvailable: return "No AI Provider Configured"
            }
        }
        
        var message: String {
            switch self {
            case .none: return ""
            case .claudeAPIKeyMissing:
                return "Claude API is selected but no API key has been configured. Add your Anthropic API key in Settings to enable AI symbol suggestions."
            case .claudeAPIKeyInvalid:
                return "The Claude API key appears to be invalid or has been rejected. Please check your API key in Settings."
            case .appleIntelligenceUnavailable(let reason):
                return "Apple Intelligence is not available on this device. \(reason). You can switch to Claude API in Settings."
            case .noProviderAvailable:
                return "No AI provider is properly configured. Please configure Apple Intelligence or add a Claude API key in Settings."
            }
        }
        
        var icon: String {
            switch self {
            case .none: return ""
            case .claudeAPIKeyMissing: return "key.slash"
            case .claudeAPIKeyInvalid: return "exclamationmark.triangle"
            case .appleIntelligenceUnavailable: return "apple.logo"
            case .noProviderAvailable: return "gearshape.2"
            }
        }
    }

    @Published public var suggestedSymbols: [SFSymbolSuggestion] = []
    @Published public var isProcessing = false
    @Published public var lastProcessedText = ""
    @Published public var currentRenderingMode: SymbolRenderingMode = .automatic
    @Published public var invalidSymbolNamesFromClaude: [String] = []
    
    @Published public var currentError: AIServiceError = .none
    
    @Published public var useTwoStageExpansion: Bool {
        didSet {
            UserDefaults.standard.set(useTwoStageExpansion, forKey: "SFSymbolService_UseTwoStageExpansion")
            print("[SFSymbolService] Two-stage expansion \(useTwoStageExpansion ? "enabled" : "disabled")")
        }
    }
    
    @Published public var claudeAPIKey: String {
        didSet {
            UserDefaults.standard.set(claudeAPIKey, forKey: SFSymbolService.userDefaultsAPIKey)
            print("[SFSymbolService] API Key updated and saved to UserDefaults.")
            if !claudeAPIKey.isEmpty {
                currentError = .none
            }
        }
    }
    @Published public var apiKeyMissingOrInvalid: Bool = false
    
    public var trackSymbolActionCallback: ((String, SymbolAction, String) -> Void)?

    private let claudeURL = "https://api.anthropic.com/v1/messages"
    
    // Cache the symbol list for validation only
    private static let allSymbolNames: [String] = SFSymbol.allSymbols.map { $0.rawValue }
    private static let symbolSet: Set<String> = Set(allSymbolNames)
    
    // SF Symbols expert system prompt
    private static let sfSymbolsExpertPrompt = """
    You are an expert on Apple's SF Symbols library. SF Symbols uses a semantic naming convention:
    
    **Naming Patterns:**
    - Base concept (e.g., "house", "person", "arrow")
    - Direction/orientation suffixes (.up, .down, .left, .right, .forward, .backward)
    - Shape containers (.circle, .square, .rectangle, .diamond, .shield, .seal)
    - Visual variants (.fill for filled, no suffix for outline)
    - Modifiers (.slash for negation/disabled, .badge for notifications)
    - Numbers (0-50, 00-09 for zero-padded)
    
    **Common Categories:**
    - Communication: phone, envelope, message, bubble, antenna
    - Media: play, pause, music, video, speaker, mic
    - Navigation: arrow, chevron, map, location, compass
    - Objects: house, car, bag, cart, cart, book, doc
    - People: person, figure, hand, eye, heart, brain
    - Nature: leaf, moon, sun, cloud, snowflake, flame
    - Symbols: star, flag, bell, bookmark, tag, pin
    - UI Controls: gear, slider, switch, button, keyboard
    - Math/Science: plus, minus, equal, divide, function
    - Text/Typography: textformat, character, paragraph
    - Commerce: creditcard, cart, dollarsign, tag, bag
    
    **Be creative** but follow naming conventions. Rank by semantic fit.
    """

    private init() {
        self.claudeAPIKey = UserDefaults.standard.string(forKey: SFSymbolService.userDefaultsAPIKey) ?? ""
        self.useTwoStageExpansion = UserDefaults.standard.object(forKey: "SFSymbolService_UseTwoStageExpansion") as? Bool ?? true
        print("[SFSymbolService] Initialized. Loaded API Key: \(self.claudeAPIKey.isEmpty ? "Not Set" : "Set")")
        print("[SFSymbolService] Symbol library: \(Self.allSymbolNames.count) symbols available for validation")
        print("[SFSymbolService] Two-stage expansion: \(self.useTwoStageExpansion ? "enabled" : "disabled")")
        if self.claudeAPIKey.isEmpty {
            self.apiKeyMissingOrInvalid = true
        }
    }
    
    /// Check if Apple Intelligence is available on this device
    public func isAppleIntelligenceAvailable() -> Bool {
        if #available(macOS 26.0, iOS 26.0, *) {
            #if canImport(FoundationModels)
            return SystemLanguageModel.default.availability == .available
            #else
            return false
            #endif
        } else {
            return false
        }
    }
    
    /// Get a user-friendly status message for Apple Intelligence
    public func appleIntelligenceStatusMessage() -> String {
        if #available(macOS 26.0, iOS 26.0, *) {
            #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Available"
            case .unavailable(.deviceNotEligible):
                return "Device not eligible"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence not enabled"
            case .unavailable(.modelNotReady):
                return "Model downloading or not ready"
            case .unavailable:
                return "Unavailable"
            }
            #else
            return "Requires iOS 26+ / macOS 26+"
            #endif
        } else {
            return "Requires iOS 26+ / macOS 26+"
        }
    }
    
    public func processSelectedText() async {
        #if os(macOS)
        print("[SFSymbolService] processSelectedText started.")
        
        let provider = SFSymbolPackageSettings.shared.modelProvider
        if provider == .claude && claudeAPIKey.isEmpty {
            print("[SFSymbolService] Claude API Key is missing. Aborting.")
            apiKeyMissingOrInvalid = true
            currentError = .claudeAPIKeyMissing
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            lastProcessedText = await getSelectedText()
            isProcessing = false
             NotificationCenter.default.post(name: .showSymbolPicker, object: nil)
            return
        }
        
        apiKeyMissingOrInvalid = false
        currentError = .none
        isProcessing = true
        invalidSymbolNamesFromClaude = []
        
        let selectedText = await getSelectedText()
        print("[SFSymbolService] Selected text: '\(selectedText)'")
        guard !selectedText.isEmpty else {
            print("[SFSymbolService] Selected text is empty. Aborting.")
            isProcessing = false
            return
        }
        
        lastProcessedText = selectedText
        
        await getSFSymbolSuggestions(for: selectedText)
        
        isProcessing = false
        print("[SFSymbolService] processSelectedText finished. Suggested symbols count: \(suggestedSymbols.count), Invalid names: \(invalidSymbolNamesFromClaude.count)")
        
        NotificationCenter.default.post(name: .showSymbolPicker, object: nil)
        print("[SFSymbolService] .showSymbolPicker notification posted.")
        #else
        print("[SFSymbolService] processSelectedText not available on iOS")
        #endif
    }
    
    /// Process text for AI symbol suggestions (available on all platforms)
    public func processText(_ text: String) async {
        print("[SFSymbolService] processText started for: '\(text)'")
        
        let provider = SFSymbolPackageSettings.shared.modelProvider
        if provider == .claude && claudeAPIKey.isEmpty {
            print("[SFSymbolService] Claude provider selected but API Key is missing. Aborting.")
            apiKeyMissingOrInvalid = true
            currentError = .claudeAPIKeyMissing
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            lastProcessedText = text
            isProcessing = false
            return
        }
        
        apiKeyMissingOrInvalid = false
        currentError = .none
        isProcessing = true
        lastProcessedText = text
        invalidSymbolNamesFromClaude = []
        
        await getSFSymbolSuggestions(for: text)
        
        isProcessing = false
        print("[SFSymbolService] processText finished. Suggested symbols count: \(suggestedSymbols.count), Invalid names: \(invalidSymbolNamesFromClaude.count)")
    }
    
    public func searchSymbols(for text: String) async {
        await processText(text)
    }
    
    #if os(macOS)
    private func getSelectedText() async -> String {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let selectedText = pasteboard.string(forType: .string) ?? ""
        
        if let previousContents = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(previousContents, forType: .string)
        }
        
        return selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
    
    private func getSFSymbolSuggestions(for text: String) async {
        print("[SFSymbolService] getSFSymbolSuggestions for: '\(text)'")
        
        let provider = SFSymbolPackageSettings.shared.modelProvider
        
        if useTwoStageExpansion {
            await getTwoStageSuggestions(for: text, provider: provider)
        } else {
            await getDirectSuggestions(for: text, provider: provider)
        }
    }
    
    /// Two-stage synonym expansion system
    private func getTwoStageSuggestions(for text: String, provider: ModelProvider) async {
        print("[SFSymbolService] Starting two-stage expansion for: '\(text)'")
        
        // Stage 1: Synonym Expansion
        let expansionResult = await expandSynonyms(for: text, provider: provider)
        
        print("[SFSymbolService] Stage 1 complete: \(expansionResult.synonyms.count) synonyms, \(expansionResult.directRenderableSymbols.count) direct renders")
        
        // Stage 2: Symbol Mapping from all concepts
        let mappingResult = await mapConceptsToSymbols(concepts: expansionResult.allTerms, provider: provider)
        
        print("[SFSymbolService] Stage 2 complete: \(mappingResult.validSymbols.count) symbols mapped")
        
        // Combine results: direct renderable symbols + mapped symbols
        var combinedSuggestions = mappingResult.validSymbols
        
        // Add direct renderable symbols that aren't already in the mapped results
        let mappedNames = Set(mappingResult.validSymbols.map { $0.name })
        for directSymbol in expansionResult.directRenderableSymbols {
            if !mappedNames.contains(directSymbol) {
                combinedSuggestions.append(SFSymbolSuggestion(name: directSymbol))
            }
        }
        
        suggestedSymbols = combinedSuggestions
        invalidSymbolNamesFromClaude = mappingResult.invalidSymbolNames
        
        print("[SFSymbolService] Two-stage expansion complete: \(suggestedSymbols.count) total symbols")
    }
    
    /// Original direct suggestion system (fallback/alternative)
    private func getDirectSuggestions(for text: String, provider: ModelProvider) async {
        print("[SFSymbolService] Using direct suggestion mode")
        
        if provider == .apple {
            if #available(macOS 26.0, iOS 26.0, *) {
                await getAppleIntelligenceSuggestions(for: text)
            } else {
                print("[SFSymbolService] Apple Intelligence requires macOS 26+/iOS 26+, falling back to Claude")
                await getClaudeSuggestions(for: text)
            }
        } else {
            await getClaudeSuggestions(for: text)
        }
    }
    
    /// Stage 1: Expand search term into synonyms and validate direct renders
    private func expandSynonyms(for text: String, provider: ModelProvider) async -> SynonymExpansionResult {
        print("[SFSymbolService] Stage 1: Expanding synonyms for '\(text)'")
        
        let synonyms: [String]
        
        if provider == .apple {
            if #available(macOS 26.0, iOS 26.0, *) {
                synonyms = await getAppleIntelligenceSynonyms(for: text)
            } else {
                synonyms = await getClaudeSynonyms(for: text)
            }
        } else {
            synonyms = await getClaudeSynonyms(for: text)
        }
        
        // Try to render each synonym directly as an SF Symbol
        var directRenderableSymbols: [String] = []
        
        for synonym in synonyms {
            let normalized = synonym
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
            
            if Self.symbolSet.contains(normalized) {
                directRenderableSymbols.append(normalized)
                print("[SFSymbolService] ✓ Direct render: \(normalized)")
            }
        }
        
        return SynonymExpansionResult(
            originalTerm: text,
            synonyms: synonyms,
            directRenderableSymbols: directRenderableSymbols
        )
    }
    
    /// Stage 2: Map concepts to SF Symbol names
    private func mapConceptsToSymbols(concepts: [String], provider: ModelProvider) async -> SymbolMappingResult {
        print("[SFSymbolService] Stage 2: Mapping \(concepts.count) concepts to symbols")
        
        let symbolNames: [String]
        
        if provider == .apple {
            if #available(macOS 26.0, iOS 26.0, *) {
                symbolNames = await getAppleIntelligenceSymbolsForConcepts(concepts: concepts)
            } else {
                symbolNames = await getClaudeSymbolsForConcepts(concepts: concepts)
            }
        } else {
            symbolNames = await getClaudeSymbolsForConcepts(concepts: concepts)
        }
        
        // Validate symbols
        var validSuggestions: [SFSymbolSuggestion] = []
        var invalidNames: [String] = []
        
        let symbolCount = SFSymbolPackageSettings.shared.symbolCount
        
        for name in symbolNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty { continue }
            
            if Self.symbolSet.contains(trimmedName) {
                validSuggestions.append(SFSymbolSuggestion(name: trimmedName))
                print("[SFSymbolService] ✓ Valid: \(trimmedName)")
            } else {
                print("[SFSymbolService] ✗ Invalid: \(trimmedName)")
                invalidNames.append(trimmedName)
            }
            
            if validSuggestions.count >= symbolCount {
                break
            }
        }
        
        return SymbolMappingResult(
            validSymbols: validSuggestions,
            invalidSymbolNames: invalidNames
        )
    }
    
    @available(macOS 26.0, iOS 26.0, *)
    private func getAppleIntelligenceSuggestions(for text: String) async {
        print("[SFSymbolService] Getting Apple Intelligence suggestions for: '\(text)'")
        
        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            let reason: String
            switch availability {
            case .unavailable(.deviceNotEligible):
                reason = "Device not eligible"
            case .unavailable(.appleIntelligenceNotEnabled):
                reason = "Apple Intelligence not enabled in Settings"
            case .unavailable(.modelNotReady):
                reason = "Model downloading or not ready"
            case .unavailable:
                reason = "Service unavailable"
            default:
                reason = "Unknown reason"
            }
            print("[SFSymbolService] Apple Intelligence not available: \(reason)")
            currentError = .appleIntelligenceUnavailable(reason: reason)
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            return
        }
        
        currentError = .none
        
        do {
            let symbolCount = SFSymbolPackageSettings.shared.symbolCount
            
            // Request more suggestions than needed for better post-validation results
            let requestCount = symbolCount * 3
            
            let prompt = """
            \(Self.sfSymbolsExpertPrompt)
            
            User query: "\(text)"
            
            Suggest \(requestCount) SF Symbol names that best match this concept. Be creative but follow SF Symbols naming conventions.
            Rank by semantic relevance (best matches first).
            Return only valid SF Symbol names following the patterns above.
            """
            
            print("[SFSymbolService] Requesting \(requestCount) suggestions from Apple Intelligence")
            
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: SymbolSuggestionsResponse.self)
            
            print("[SFSymbolService] Apple Intelligence returned \(response.content.symbols.count) symbols")
            
            var validSuggestions: [SFSymbolSuggestion] = []
            var invalidNamesAccumulator: [String] = []
            
            for name in response.content.symbols {
                let trimmedName = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedName.isEmpty { continue }
                
                if Self.symbolSet.contains(trimmedName) {
                    validSuggestions.append(SFSymbolSuggestion(name: trimmedName))
                    print("[SFSymbolService] ✓ Valid: \(trimmedName)")
                } else {
                    print("[SFSymbolService] ✗ Invalid (not in library): \(trimmedName)")
                    invalidNamesAccumulator.append(trimmedName)
                }
                
                // Stop once we have enough valid suggestions
                if validSuggestions.count >= symbolCount {
                    break
                }
            }
            
            if validSuggestions.isEmpty {
                print("[SFSymbolService] No valid symbols from Apple Intelligence")
                currentError = .noProviderAvailable
            }
            
            suggestedSymbols = validSuggestions
            invalidSymbolNamesFromClaude = invalidNamesAccumulator
            apiKeyMissingOrInvalid = false
            
        } catch let error as LanguageModelSession.GenerationError {
            print("[SFSymbolService] Generation error: \(error)")
            currentError = .appleIntelligenceUnavailable(reason: "Generation error")
            suggestedSymbols = []
        } catch {
            print("[SFSymbolService] Error: \(error)")
            currentError = .appleIntelligenceUnavailable(reason: error.localizedDescription)
            suggestedSymbols = []
        }
        #else
        currentError = .appleIntelligenceUnavailable(reason: "Requires iOS 26+ / macOS 26+")
        suggestedSymbols = []
        #endif
    }

    private func getClaudeSuggestions(for text: String) async {
        var rawSymbolNames: [String] = []
        do {
            rawSymbolNames = try await callClaudeAPI(for: text)
            print("[SFSymbolService] Claude API success. Raw symbols: \(rawSymbolNames)")
            apiKeyMissingOrInvalid = false
            currentError = .none
        } catch let error as APIError {
            print("[SFSymbolService] Claude API error: \(error)")
            switch error {
            case .requestFailed(let reason):
                if reason.contains("401") || reason.contains("403") || reason.contains("authentication_error") || reason.contains("invalid_request_error") {
                    apiKeyMissingOrInvalid = true
                    currentError = .claudeAPIKeyInvalid
                } else {
                     apiKeyMissingOrInvalid = false
                     currentError = .noProviderAvailable
                }
            case .invalidURL, .decodingFailed, .noSuggestions:
                 apiKeyMissingOrInvalid = false
                 currentError = .noProviderAvailable
            }
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            return
        } catch {
            apiKeyMissingOrInvalid = false
            currentError = .noProviderAvailable
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            return
        }

        var validSuggestions: [SFSymbolSuggestion] = []
        var invalidNamesAccumulator: [String] = []

        for name in rawSymbolNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty { continue }
            
            if Self.symbolSet.contains(trimmedName) {
                validSuggestions.append(SFSymbolSuggestion(name: trimmedName))
                print("[SFSymbolService] ✓ Valid: \(trimmedName)")
            } else {
                print("[SFSymbolService] ✗ Invalid (not in library): \(trimmedName)")
                invalidNamesAccumulator.append(trimmedName)
            }
        }
        
        suggestedSymbols = validSuggestions
        invalidSymbolNamesFromClaude = invalidNamesAccumulator
    }

    private func callClaudeAPI(for text: String) async throws -> [String] {
        guard !claudeAPIKey.isEmpty else {
            throw APIError.requestFailed(reason: "API Key not provided")
        }
        guard let url = URL(string: claudeURL) else {
            throw APIError.invalidURL
        }
        
        let selectedModel = SFSymbolPackageSettings.shared.selectedModel
        let symbolCount = SFSymbolPackageSettings.shared.symbolCount
        
        // Request more suggestions than needed for better post-validation results
        let requestCount = symbolCount * 3
        
        let systemPrompt = Self.sfSymbolsExpertPrompt
        
        let userPrompt = """
        User query: "\(text)"
        
        Suggest \(requestCount) SF Symbol names that best match this concept. Be creative but follow SF Symbols naming conventions.
        Rank by semantic relevance (best matches first).
        Return ONLY symbol names, comma-separated, no explanations.
        
        Examples of well-formed symbols:
        house.fill, person.circle, arrow.up.right, music.note, gear, star.fill, bell.badge
        """
        
        print("[SFSymbolService] Requesting \(requestCount) suggestions from Claude (\(selectedModel.rawValue))")
        
        let requestBody: [String: Any] = [
            "model": selectedModel.rawValue,
            "max_tokens": 400,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let claudeError = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw APIError.requestFailed(reason: "\(claudeError.error.type): \(claudeError.error.message)")
            }
            throw APIError.requestFailed(reason: "HTTP \(statusCode)")
        }
        
        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let firstContent = result.content.first, firstContent.type == "text" else {
            throw APIError.decodingFailed(reason: "No text content")
        }
        
        let symbolNames = firstContent.text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !symbolNames.isEmpty else {
            throw APIError.noSuggestions
        }
        
        print("[SFSymbolService] Claude returned \(symbolNames.count) suggestions")
        return symbolNames
    }
    
    // MARK: - Two-Stage Expansion Helper Methods

    /// Stage 1: Get synonyms using Claude API
    private func getClaudeSynonyms(for text: String) async -> [String] {
        print("[SFSymbolService] Getting Claude synonyms for: '\(text)'")

        guard !claudeAPIKey.isEmpty else {
            print("[SFSymbolService] Claude API Key missing")
            return []
        }

        guard let url = URL(string: claudeURL) else {
            print("[SFSymbolService] Invalid Claude URL")
            return []
        }

        let selectedModel = SFSymbolPackageSettings.shared.selectedModel

        let systemPrompt = """
        You are an expert at finding synonyms, related concepts, and semantic variations.
        Return comprehensive lists of related words and concepts that could represent the same or similar ideas.
        """

        let userPrompt = """
        Return a list of all synonyms and words that represent or depict the following concept:
        "\(text)"

        Include:
        - Direct synonyms
        - Related concepts
        - Visual representations
        - Metaphors and symbolic associations
        - Common variations

        Return ONLY the words, comma-separated, no explanations.
        Aim for 15-25 related terms.
        """

        let requestBody: [String: Any] = [
            "model": selectedModel.rawValue,
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.claudeAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[SFSymbolService] Claude synonym request failed")
                return []
            }

            let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            guard let firstContent = result.content.first, firstContent.type == "text" else {
                print("[SFSymbolService] No text content in Claude response")
                return []
            }

            let synonyms = firstContent.text
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            print("[SFSymbolService] Claude returned \(synonyms.count) synonyms")
            return synonyms

        } catch {
            print("[SFSymbolService] Error getting Claude synonyms: \(error)")
            return []
        }
    }

    /// Stage 1: Get synonyms using Apple Intelligence
    @available(macOS 26.0, iOS 26.0, *)
    private func getAppleIntelligenceSynonyms(for text: String) async -> [String] {
        print("[SFSymbolService] Getting Apple Intelligence synonyms for: '\(text)'")

        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("[SFSymbolService] Apple Intelligence not available, falling back to empty list")
            return []
        }

        do {
            let prompt = """
            Return a list of all synonyms and words that represent or depict the following concept:
            "\(text)"

            Include:
            - Direct synonyms
            - Related concepts
            - Visual representations
            - Metaphors and symbolic associations
            - Common variations

            Aim for 15-25 related terms.
            """

            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: SynonymExpansionResponse.self)

            print("[SFSymbolService] Apple Intelligence returned \(response.content.synonyms.count) synonyms")
            return response.content.synonyms

        } catch {
            print("[SFSymbolService] Error getting Apple Intelligence synonyms: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    /// Stage 2: Map concepts to SF Symbol names using Claude API
    private func getClaudeSymbolsForConcepts(concepts: [String]) async -> [String] {
        print("[SFSymbolService] Getting Claude symbols for \(concepts.count) concepts")

        guard !claudeAPIKey.isEmpty else {
            print("[SFSymbolService] Claude API Key missing")
            return []
        }

        guard let url = URL(string: claudeURL) else {
            print("[SFSymbolService] Invalid Claude URL")
            return []
        }

        let selectedModel = SFSymbolPackageSettings.shared.selectedModel
        let symbolCount = SFSymbolPackageSettings.shared.symbolCount
        let requestCount = symbolCount * 3

        let conceptsList = concepts.joined(separator: ", ")

        let systemPrompt = Self.sfSymbolsExpertPrompt

        let userPrompt = """
        Given these related concepts and terms:
        \(conceptsList)

        Return \(requestCount) SF Symbol names that could visually represent these concepts.
        Follow SF Symbols naming conventions strictly.
        Rank by semantic relevance (best matches first).
        Return ONLY symbol names, comma-separated, no explanations.

        Examples of well-formed symbols:
        house.fill, person.circle, arrow.up.right, music.note, gear, star.fill, bell.badge
        """

        let requestBody: [String: Any] = [
            "model": selectedModel.rawValue,
            "max_tokens": 400,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.claudeAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[SFSymbolService] Claude symbol mapping request failed")
                return []
            }

            let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            guard let firstContent = result.content.first, firstContent.type == "text" else {
                print("[SFSymbolService] No text content in Claude response")
                return []
            }

            let symbolNames = firstContent.text
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            print("[SFSymbolService] Claude returned \(symbolNames.count) symbol names from concepts")
            return symbolNames

        } catch {
            print("[SFSymbolService] Error getting Claude symbols for concepts: \(error)")
            return []
        }
    }

    /// Stage 2: Map concepts to SF Symbol names using Apple Intelligence
    @available(macOS 26.0, iOS 26.0, *)
    private func getAppleIntelligenceSymbolsForConcepts(concepts: [String]) async -> [String] {
        print("[SFSymbolService] Getting Apple Intelligence symbols for \(concepts.count) concepts")

        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("[SFSymbolService] Apple Intelligence not available, falling back to empty list")
            return []
        }

        do {
            let symbolCount = SFSymbolPackageSettings.shared.symbolCount
            let requestCount = symbolCount * 3
            let conceptsList = concepts.joined(separator: ", ")

            let prompt = """
            \(Self.sfSymbolsExpertPrompt)

            Given these related concepts and terms:
            \(conceptsList)

            Return \(requestCount) SF Symbol names that could visually represent these concepts.
            Follow SF Symbols naming conventions strictly.
            Rank by semantic relevance (best matches first).
            """

            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: MultiConceptSymbolResponse.self)

            print("[SFSymbolService] Apple Intelligence returned \(response.content.symbols.count) symbols from concepts")
            return response.content.symbols

        } catch {
            print("[SFSymbolService] Error getting Apple Intelligence symbols for concepts: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: - Helper Methods

    public func replaceTextWithSymbol(_ symbolName: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(symbolName, forType: .string)
        #else
        UIPasteboard.general.string = symbolName
        #endif
    }

    public func trackSymbolAction(symbolName: String, action: SymbolAction, searchTerm: String) {
        trackSymbolActionCallback?(symbolName, action, searchTerm)
    }
}

struct ClaudeResponse: Decodable {
    let content: [ClaudeContentBlock]
    let model: String
    let role: String
    let stop_reason: String
}

struct ClaudeContentBlock: Decodable {
    let type: String
    let text: String
}

struct ClaudeErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let type: String
        let message: String
    }
    let error: ErrorDetail
}

enum APIError: Error {
    case invalidURL
    case requestFailed(reason: String)
    case decodingFailed(reason: String)
    case noSuggestions
}

extension Notification.Name {
    static let showSymbolPicker = Notification.Name("showSymbolPicker")
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable(description: "A list of SF Symbol names ranked by semantic relevance")
struct SymbolSuggestionsResponse {
    @Guide(description: "Array of SF Symbol names (e.g., 'house.fill', 'person.circle') ranked from most to least relevant. Follow SF Symbols naming conventions: base.modifier.variant pattern.")
    var symbols: [String]
}
#endif