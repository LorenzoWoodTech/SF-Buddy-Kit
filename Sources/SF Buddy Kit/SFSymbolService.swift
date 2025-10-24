//
//  SFSymbolService.swift
//  SFBuddyKit
//

import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Combine

public enum ServiceRenderingMode: String, CaseIterable, Identifiable {
    case monochrome, hierarchical, palette, multicolor
    
    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .hierarchical: return "Hierarchical"
        case .palette: return "Palette"
        case .multicolor: return "Multicolor"
        }
    }
    
    public var iconName: String {
        switch self {
        case .monochrome:
            return "circle"
        case .hierarchical:
            return "circle.lefthalf.striped.horizontal"
        case .palette:
            return "paintpalette"
        case .multicolor:
            return "circle.hexagongrid"
        }
    }
}

@MainActor
public class SFSymbolService: ObservableObject {
    public static let shared = SFSymbolService()
    private static let userDefaultsAPIKey = "ClaudeAPIKey"

    @Published public var suggestedSymbols: [SFSymbolSuggestion] = []
    @Published public var isProcessing = false
    @Published public var lastProcessedText = ""
    @Published public var currentRenderingMode: ServiceRenderingMode = .multicolor
    @Published public var invalidSymbolNamesFromClaude: [String] = []
    
    @Published public var claudeAPIKey: String {
        didSet {
            UserDefaults.standard.set(claudeAPIKey, forKey: SFSymbolService.userDefaultsAPIKey)
            print("[SFSymbolService] API Key updated and saved to UserDefaults.")
        }
    }
    @Published public var apiKeyMissingOrInvalid: Bool = false

    private let claudeURL = "https://api.anthropic.com/v1/messages"
    
    // Callback for tracking symbol actions - to be set by the app
    public var trackSymbolActionCallback: ((String, SymbolAction, String) -> Void)?
    
    #if os(macOS)
    private static let nonExistentSymbolPlaceholderTiff: Data? = {
        let nonExistentSymbolName = "com.apple.NonExistentInternalSymbolSFBuddy"
        let image = NSImage(systemSymbolName: nonExistentSymbolName, accessibilityDescription: nil)
        if image == nil {
            print("[SFSymbolService] CRITICAL: NSImage(systemSymbolName: \"\(nonExistentSymbolName)\") returned nil. Symbol validation will not work.")
        }
        return image?.tiffRepresentation
    }()
    #endif

    public init() {
        self.claudeAPIKey = UserDefaults.standard.string(forKey: SFSymbolService.userDefaultsAPIKey) ?? ""
        print("[SFSymbolService] Initialized. Loaded API Key: \(self.claudeAPIKey.isEmpty ? "Not Set" : "Set")")
        if self.claudeAPIKey.isEmpty {
            self.apiKeyMissingOrInvalid = true
        }

        #if os(macOS)
        if SFSymbolService.nonExistentSymbolPlaceholderTiff == nil {
            print("[SFSymbolService] WARNING: Could not generate non-existent symbol placeholder TIFF. Validation may be affected.")
        }
        #endif
    }
    
    public func trackSymbolAction(symbolName: String, action: SymbolAction, searchTerm: String) {
        trackSymbolActionCallback?(symbolName, action, searchTerm)
    }
    
    public func processSelectedText() async {
        #if os(macOS)
        print("[SFSymbolService] processSelectedText started.")
        guard !claudeAPIKey.isEmpty else {
            print("[SFSymbolService] API Key is missing. Aborting.")
            apiKeyMissingOrInvalid = true
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            lastProcessedText = await getSelectedText()
            isProcessing = false
             NotificationCenter.default.post(name: .showSymbolPicker, object: nil)
            return
        }
        apiKeyMissingOrInvalid = false
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
        guard !claudeAPIKey.isEmpty else {
            print("[SFSymbolService] API Key is missing. Aborting.")
            apiKeyMissingOrInvalid = true
            suggestedSymbols = []
            invalidSymbolNamesFromClaude = []
            lastProcessedText = text
            isProcessing = false
            return
        }
        apiKeyMissingOrInvalid = false
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
        var rawSymbolNames: [String] = []
        do {
            rawSymbolNames = try await callClaudeAPI(for: text)
            print("[SFSymbolService] Claude API success. Raw symbols: \(rawSymbolNames)")
            apiKeyMissingOrInvalid = false
        } catch let error as APIError {
            print("[SFSymbolService] Claude API error: \(error). Falling back to mock suggestions (or empty).")
            switch error {
            case .requestFailed(let reason):
                if reason.contains("401") || reason.contains("403") || reason.contains("authentication_error") || reason.contains("invalid_request_error") {
                    apiKeyMissingOrInvalid = true
                    print("[SFSymbolService] API Key/Config seems invalid or unauthorized. Reason: \(reason)")
                } else {
                     apiKeyMissingOrInvalid = false
                }
            case .invalidURL, .decodingFailed, .noSuggestions:
                 apiKeyMissingOrInvalid = false
            }
            rawSymbolNames = getMockSuggestions(for: text).map { $0.name }
            print("[SFSymbolService] Mock suggestions raw names count: \(rawSymbolNames.count)")
        } catch {
            print("[SFSymbolService] Unexpected error during Claude API call: \(error). Falling back to mock suggestions.")
            apiKeyMissingOrInvalid = false
            rawSymbolNames = getMockSuggestions(for: text).map { $0.name }
            print("[SFSymbolService] Mock suggestions raw names count: \(rawSymbolNames.count)")
        }


        var validSuggestions: [SFSymbolSuggestion] = []
        var invalidNamesAccumulator: [String] = []

        for name in rawSymbolNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                continue
            }
            if isActuallyValidSFSymbol(trimmedName) {
                validSuggestions.append(SFSymbolSuggestion(name: trimmedName))
            } else {
                print("[SFSymbolService] Invalid or non-existent symbol suggested: \(trimmedName)")
                invalidNamesAccumulator.append(trimmedName)
            }
        }
        
        suggestedSymbols = validSuggestions
        invalidSymbolNamesFromClaude = invalidNamesAccumulator
    }
    
    private func isActuallyValidSFSymbol(_ name: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        #if os(macOS)
        guard let imageFromName = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return false
        }

        guard let placeholderTiff = SFSymbolService.nonExistentSymbolPlaceholderTiff else {
            print("[SFSymbolService] WARNING: nonExistentSymbolPlaceholderTiff is nil. Cannot validate symbol '\(name)'. Assuming valid.")
            return true
        }

        return imageFromName.tiffRepresentation != placeholderTiff
        #else
        // On iOS, use UIImage for validation
        return UIImage(systemName: name) != nil
        #endif
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
        
        let settings = SFSymbolPackageSettings.shared
        let selectedModel = settings.selectedModel
        let symbolCount = settings.symbolCount
        
        let prompt = """
        Given this text: "\(text)"
        
        Suggest \(symbolCount) relevant SF Symbols that would best represent this concept, action, or meaning.
        Return ONLY the symbol names (like "house.fill", "person.circle", "magnifyingglass") separated by commas, no explanations or additional text.
        Focus on symbols that actually exist in Apple's SF Symbols library. Order them with the most relevant first to the least relevant. 
        If the text is about UI elements, suggest symbols commonly used in app interfaces.
        Be creative but accurate - only suggest real SF Symbol names.
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
        
        print("[SFSymbolService] Claude request being sent with model: \(selectedModel.displayName) (key omitted for log)")
        
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
        
        print("[SFSymbolService] Claude response raw data: \(String(data: data, encoding: .utf8) ?? "Undecodable")")
        
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
    
    private func getMockSuggestions(for text: String) -> [SFSymbolSuggestion] {
        print("[SFSymbolService] Using mock suggestions for '\(text)'.")
        var mocks = [
            SFSymbolSuggestion(name: "house.fill"),
            SFSymbolSuggestion(name: "gearshape.fill"),
            SFSymbolSuggestion(name: "person.circle.fill"),
            SFSymbolSuggestion(name: "trash.fill"),
            SFSymbolSuggestion(name: "doc.text.fill"),
            SFSymbolSuggestion(name: "mic.fill"),
            SFSymbolSuggestion(name: "video.fill"),
            SFSymbolSuggestion(name: "bookmark.fill")
        ]
        if text.lowercased().contains("invalid") {
            mocks.append(SFSymbolSuggestion(name: "non.existent.symbol.test.1"))
            mocks.append(SFSymbolSuggestion(name: "another.fake.one"))
        }
        return mocks
    }
    
    public func replaceTextWithSymbol(_ symbolName: String) {
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

public struct ClaudeResponse: Decodable {
    public let content: [ClaudeContentBlock]
    public let model: String
    public let role: String
    public let stop_reason: String
}

public struct ClaudeContentBlock: Decodable {
    public let type: String
    public let text: String
}

public struct ClaudeErrorResponse: Decodable {
    public struct ErrorDetail: Decodable {
        public let type: String
        public let message: String
    }
    public let error: ErrorDetail
}

public enum APIError: Error {
    case invalidURL
    case requestFailed(reason: String)
    case decodingFailed(reason: String)
    case noSuggestions
}

public extension Notification.Name {
    static let showSymbolPicker = Notification.Name("showSymbolPicker")
}

public struct SFSymbolSuggestion: Identifiable {
    public let id = UUID()
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}
