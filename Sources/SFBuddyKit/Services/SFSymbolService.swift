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
class SFSymbolService: ObservableObject {
    static let shared = SFSymbolService()
    private static let userDefaultsAPIKey = "ClaudeAPIKey"
    
    // MARK: - Model Provider Configuration
    
    public enum ModelProvider: String, CaseIterable, Identifiable {
        case apple = "apple"
        case claude = "claude"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .apple: return "Apple Intelligence"
            case .claude: return "Claude API"
            }
        }
        
        public var description: String {
            switch self {
            case .apple: return "On-device, private, requires iOS 26+"
            case .claude: return "Cloud-based, requires API key"
            }
        }
    }
    
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

    @Published var suggestedSymbols: [SFSymbolSuggestion] = []
    @Published var isProcessing = false
    @Published var lastProcessedText = ""
    @Published var currentRenderingMode: SymbolRenderingMode = .automatic
    @Published var invalidSymbolNamesFromClaude: [String] = []
    
    @Published var currentError: AIServiceError = .none
    
    @Published var claudeAPIKey: String {
        didSet {
            UserDefaults.standard.set(claudeAPIKey, forKey: SFSymbolService.userDefaultsAPIKey)
            print("[SFSymbolService] API Key updated and saved to UserDefaults.")
            if !claudeAPIKey.isEmpty {
                currentError = .none
            }
        }
    }
    @Published var apiKeyMissingOrInvalid: Bool = false

    private let claudeURL = "https://api.anthropic.com/v1/messages"
    
    // Cache the symbol list for performance
    private static let allSymbolNames: [String] = SFSymbol.allSymbols.map { $0.rawValue }
    private static let symbolSet: Set<String> = Set(allSymbolNames)

    private init() {
        self.claudeAPIKey = UserDefaults.standard.string(forKey: SFSymbolService.userDefaultsAPIKey) ?? ""
        print("[SFSymbolService] Initialized. Loaded API Key: \(self.claudeAPIKey.isEmpty ? "Not Set" : "Set")")
        print("[SFSymbolService] Symbol library loaded: \(Self.allSymbolNames.count) symbols available")
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
    
    func processSelectedText() async {
        #if os(macOS)
        print("[SFSymbolService] processSelectedText started.")
        
        // Better error handling
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
    func processText(_ text: String) async {
        print("[SFSymbolService] processText started for: '\(text)'")
        
        // Better error handling
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
    
    func searchSymbols(for text: String) async {
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
        
        // Check which provider to use
        let provider = SFSymbolPackageSettings.shared.modelProvider
        
        if provider == .apple {
            // Use Foundation Models
            if #available(macOS 26.0, iOS 26.0, *) {
                await getAppleIntelligenceSuggestions(for: text)
            } else {
                print("[SFSymbolService] Apple Intelligence requires macOS 26+/iOS 26+, falling back to Claude")
                await getClaudeSuggestions(for: text)
            }
        } else {
            // Use Claude API (existing implementation)
            await getClaudeSuggestions(for: text)
        }
    }
    
    @available(macOS 26.0, iOS 26.0, *)
    private func getAppleIntelligenceSuggestions(for text: String) async {
        print("[SFSymbolService] Getting Apple Intelligence suggestions for: '\(text)'")
        
        #if canImport(FoundationModels)
        // Check model availability with better error tracking
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
            
            // Don't fall back to Claude automatically - let user configure
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            return
        }
        
        // Clear error on success
        currentError = .none
        
        do {
            let symbolCount = SFSymbolPackageSettings.shared.symbolCount
            
            // Get a relevant subset of symbols based on text matching (for better context)
            let relevantSymbols = getRelevantSymbolSubset(for: text, maxCount: 500)
            let symbolsContext = relevantSymbols.joined(separator: ", ")
            
            let instructions = """
            You are an expert at Apple's SF Symbols. You have access to the complete list of valid SF Symbol names.
            When given text, select the MOST relevant symbols from the provided list.
            
            CRITICAL: You MUST ONLY choose symbols from the provided list. Do NOT invent or guess symbol names.
            """
            
            let prompt = """
            Text: "\(text)"
            
            Available SF Symbols (choose from these ONLY):
            \(symbolsContext)
            
            Select exactly \(symbolCount) symbols from the list above that best represent "\(text)".
            Order them from most to least relevant.
            Return ONLY the exact symbol names from the list.
            """
            
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: SymbolSuggestionsResponse.self)
            
            print("[SFSymbolService] Apple Intelligence returned \(response.content.symbols.count) symbols: \(response.content.symbols)")
            
            // Validate symbols (should all be valid now)
            var validSuggestions: [SFSymbolSuggestion] = []
            var invalidNamesAccumulator: [String] = []
            
            for name in response.content.symbols {
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
            
            // Don't fall back if we got nothing - show error
            if validSuggestions.isEmpty {
                print("[SFSymbolService] No valid symbols from Apple Intelligence")
                currentError = .noProviderAvailable
            }
            
            suggestedSymbols = validSuggestions
            invalidSymbolNamesFromClaude = invalidNamesAccumulator
            apiKeyMissingOrInvalid = false
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                print("[SFSymbolService] Guardrail violation with Apple Intelligence")
            } else {
                print("[SFSymbolService] Apple Intelligence generation error: \(error)")
            }
            currentError = .appleIntelligenceUnavailable(reason: "Generation error")
            suggestedSymbols = []
        } catch {
            print("[SFSymbolService] Apple Intelligence error: \(error)")
            currentError = .appleIntelligenceUnavailable(reason: error.localizedDescription)
            suggestedSymbols = []
        }
        #else
        // Foundation Models not available
        print("[SFSymbolService] FoundationModels not available on this platform")
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
                    print("[SFSymbolService] API Key/Config seems invalid or unauthorized. Reason: \(reason)")
                } else {
                     apiKeyMissingOrInvalid = false
                     currentError = .noProviderAvailable
                }
            case .invalidURL, .decodingFailed, .noSuggestions:
                 apiKeyMissingOrInvalid = false
                 currentError = .noProviderAvailable
            }
            // Don't use mock data - show error instead
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            return
        } catch {
            print("[SFSymbolService] Unexpected error during Claude API call: \(error)")
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
            } else {
                print("[SFSymbolService] Invalid or non-existent symbol suggested: \(trimmedName)")
                invalidNamesAccumulator.append(trimmedName)
            }
        }
        
        suggestedSymbols = validSuggestions
        invalidSymbolNamesFromClaude = invalidNamesAccumulator
    }
    
    /// Get a relevant subset of symbols for better AI context
    private func getRelevantSymbolSubset(for text: String, maxCount: Int) -> [String] {
        let searchTerm = text.lowercased()
        let words = searchTerm.split(separator: " ").map(String.init)
        
        var scored: [(symbol: String, score: Int)] = []
        
        for symbol in Self.allSymbolNames {
            let symbolLower = symbol.lowercased()
            var score = 0
            
            // Direct substring match
            if symbolLower.contains(searchTerm) {
                score += 100
            }
            
            // Word matches
            for word in words {
                if symbolLower.contains(word) {
                    score += 50
                }
                // Base symbol match (before first dot)
                if let baseSymbol = symbol.split(separator: ".").first,
                   String(baseSymbol).lowercased().contains(word) {
                    score += 30
                }
            }
            
            // Prefix bonus
            if symbolLower.hasPrefix(searchTerm) {
                score += 200
            }
            
            if score > 0 {
                scored.append((symbol, score))
            }
        }
        
        // Sort by score and take top results
        scored.sort { $0.score > $1.score }
        var results = scored.prefix(maxCount).map { $0.symbol }
        
        // If we don't have enough matches, add some popular/common symbols
        if results.count < 100 {
            let commonSymbols = Self.allSymbolNames.filter { symbol in
                ["house", "heart", "star", "gear", "person", "plus", "minus", "checkmark", "xmark",
                 "magnifyingglass", "trash", "folder", "bell", "envelope", "phone", "message",
                 "camera", "photo", "video", "music", "play", "pause", "doc", "pencil"].contains {
                    symbol.hasPrefix($0)
                }
            }
            let additional = commonSymbols.prefix(100 - results.count)
            results.append(contentsOf: additional)
        }
        
        // Ensure we have at least some results
        if results.isEmpty {
            results = Array(Self.allSymbolNames.prefix(maxCount))
        }
        
        return results
    }

    private func callClaudeAPI(for text: String) async throws -> [String] {
        print("[SFSymbolService] Calling Claude API...")
        guard !claudeAPIKey.isEmpty else {
            print("[SFSymbolService] API Key is missing internally.")
            throw APIError.requestFailed(reason: "API Key not provided")
        }
        guard let url = URL(string: claudeURL) else {
            print("[SFSymbolService] Invalid Claude API URL.")
            throw APIError.invalidURL
        }
        
        let selectedModel = SFSymbolPackageSettings.shared.selectedModel
        let symbolCount = SFSymbolPackageSettings.shared.symbolCount
        
        // Get a relevant subset of symbols
        let relevantSymbols = getRelevantSymbolSubset(for: text, maxCount: 800)
        let symbolsList = relevantSymbols.joined(separator: ", ")
        
        let prompt = """
        Given this text: "\(text)"
        
        Choose \(symbolCount) relevant SF Symbols from this list:
        \(symbolsList)
        
        IMPORTANT: You MUST choose ONLY from the symbols listed above. Do not invent or guess symbol names.
        
        Return ONLY the symbol names separated by commas, no explanations.
        Order them from most to least relevant to "\(text)".
        """
        
        let requestBody: [String: Any] = [
            "model": selectedModel.rawValue,
            "max_tokens": 200,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[SFSymbolService] Claude request with \(relevantSymbols.count) relevant symbols in context")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            var responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            if let claudeError = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                responseBody = "Claude Error: \(claudeError.error.type) - \(claudeError.error.message)"
                if claudeError.error.type == "authentication_error" || claudeError.error.type == "invalid_request_error" {
                     print("[SFSymbolService] Claude API Error (\(claudeError.error.type)): \(claudeError.error.message)")
                     throw APIError.requestFailed(reason: "\(claudeError.error.type): \(claudeError.error.message)")
                }
            }
            print("[SFSymbolService] Claude API HTTP Error: \(statusCode). Body: \(responseBody)")
            throw APIError.requestFailed(reason: "HTTP Error: \(statusCode). Body: \(responseBody)")
        }
        
        print("[SFSymbolService] Claude response received")
        
        do {
            let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            if let firstContent = result.content.first, firstContent.type == "text" {
                let symbolNamesString = firstContent.text
                print("[SFSymbolService] Claude API response text: \(symbolNamesString)")
                let symbolNames = symbolNamesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if symbolNames.isEmpty {
                     print("[SFSymbolService] Claude API returned no symbol names.")
                     throw APIError.noSuggestions
                }
                return symbolNames
            } else {
                print("[SFSymbolService] Claude API: No text content found in response or unexpected format.")
                throw APIError.decodingFailed(reason: "No text content found")
            }
        } catch {
            print("[SFSymbolService] Claude API decoding error: \(error)")
            if error is APIError { throw error }
            else { throw APIError.decodingFailed(reason: error.localizedDescription) }
        }
    }
    
    func replaceTextWithSymbol(_ symbolName: String) {
        #if os(macOS)
        print("[SFSymbolService] Copying to pasteboard: \(symbolName)")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(symbolName, forType: .string)
        print("[SFSymbolService] \(symbolName) copied to pasteboard.")
        #else
        print("[SFSymbolService] Copying to pasteboard: \(symbolName)")
        UIPasteboard.general.string = symbolName
        print("[SFSymbolService] \(symbolName) copied to pasteboard.")
        #endif
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

struct SFSymbolSuggestion: Identifiable {
    let id = UUID()
    let name: String
}

// Define the response structure for Apple Intelligence
#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable(description: "A list of SF Symbol names")
struct SymbolSuggestionsResponse {
    @Guide(description: "Array of SF Symbol names (e.g., 'house.fill', 'person.circle')")
    var symbols: [String]
}
#endif