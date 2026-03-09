//
//  AIConfigurationView.swift
//  SFBuddyKit
//
//  Inline AI configuration for symbol picker
//

import SwiftUI

struct AIConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var symbolService = SFSymbolService.shared
    @State private var packageSettings = SFSymbolPackageSettings.shared
    @State private var isTestingAPIKey = false
    @State private var apiKeyStatus: APIKeyStatus = .untested
    @State private var apiKeyError: String?
    
    enum APIKeyStatus {
        case untested
        case valid
        case invalid
        case testing
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // AI Provider Selection
                Section {
                    Picker("AI Provider", selection: $packageSettings.modelProvider) {
                        ForEach(ModelProvider.allCases) { provider in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.body)
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: packageSettings.modelProvider) { _, _ in
                        apiKeyStatus = .untested
                        apiKeyError = nil
                    }
                    
                    if packageSettings.modelProvider == .apple {
                        HStack {
                            Text("Status")
                            Spacer()
                            HStack(spacing: 4) {
                                if symbolService.isAppleIntelligenceAvailable() {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                Text(symbolService.appleIntelligenceStatusMessage())
                                    .foregroundStyle(symbolService.isAppleIntelligenceAvailable() ? .green : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    if packageSettings.modelProvider == .apple {
                        if symbolService.isAppleIntelligenceAvailable() {
                            Text("Using Apple's on-device intelligence. No API key needed. Private and secure.")
                        } else {
                            Text("Apple Intelligence is not available. \(symbolService.appleIntelligenceStatusMessage()). Switch to Claude API if needed.")
                        }
                    } else {
                        Text("Using Claude API. Requires Anthropic API key.")
                    }
                }
                
                // API Settings (only show for Claude)
                if packageSettings.modelProvider == .claude {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SecureField("Anthropic API Key", text: $symbolService.claudeAPIKey)
                                    .textContentType(.password)
                                    .onChange(of: symbolService.claudeAPIKey) { _, _ in
                                        apiKeyStatus = .untested
                                        apiKeyError = nil
                                    }
                                
                                Button {
                                    testAPIKey()
                                } label: {
                                    if isTestingAPIKey {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Test")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(symbolService.claudeAPIKey.isEmpty || isTestingAPIKey)
                            }
                            
                            // Status indicator
                            switch apiKeyStatus {
                            case .untested:
                                if !symbolService.claudeAPIKey.isEmpty {
                                    Label("API key not tested", systemImage: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            case .testing:
                                Label("Testing API key...", systemImage: "ellipsis.circle")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            case .valid:
                                Label("API key is valid", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            case .invalid:
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("API key is invalid", systemImage: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    if let error = apiKeyError {
                                        Text(error)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Picker("AI Model", selection: $packageSettings.selectedModel) {
                            ForEach(ClaudeModel.allCases) { model in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.body)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        
                        Link("Get API Key from Anthropic", 
                             destination: URL(string: "https://console.anthropic.com/account/keys")!)
                            .font(.caption)
                    } header: {
                        Text("Claude API Settings")
                    } footer: {
                        Text("Create an API key at console.anthropic.com. Click 'Test' to verify your key.")
                    }
                }
                
                // Symbol Count
                Section {
                    Stepper("Symbol Count: \(packageSettings.symbolCount)", 
                           value: $packageSettings.symbolCount, 
                           in: 4...20, 
                           step: 4)
                } header: {
                    Text("Results")
                } footer: {
                    Text("Number of symbol suggestions to generate")
                }
                
                // Two-Stage Expansion
                Section {
                    Toggle(isOn: $symbolService.useTwoStageExpansion) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Two-Stage Expansion")
                            Text("First generates synonyms, then maps all concepts to symbols")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Search Method")
                } footer: {
                    if symbolService.useTwoStageExpansion {
                        Text("Two-stage expansion provides more comprehensive results by first expanding your search term into related concepts, then finding symbols for all of them. This takes longer but finds more relevant symbols.")
                    } else {
                        Text("Direct search is faster but may miss related symbols. The AI directly suggests symbols for your search term without expanding it first.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("AI Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Clear error if configuration looks good
                        if packageSettings.modelProvider == .claude && !symbolService.claudeAPIKey.isEmpty && apiKeyStatus == .valid {
                            symbolService.currentError = .none
                        } else if packageSettings.modelProvider == .apple && symbolService.isAppleIntelligenceAvailable() {
                            symbolService.currentError = .none
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func testAPIKey() {
        guard !symbolService.claudeAPIKey.isEmpty else { return }
        
        apiKeyStatus = .testing
        isTestingAPIKey = true
        apiKeyError = nil
        
        Task {
            do {
                // Make a minimal test request to Claude
                let result = try await testClaudeAPIKey()
                
                await MainActor.run {
                    if result {
                        apiKeyStatus = .valid
                        symbolService.currentError = .none
                    } else {
                        apiKeyStatus = .invalid
                        apiKeyError = "Invalid response from API"
                    }
                    isTestingAPIKey = false
                }
            } catch {
                await MainActor.run {
                    apiKeyStatus = .invalid
                    
                    // Parse error message
                    if let apiError = error as? TestAPIError {
                        switch apiError {
                        case .authenticationError:
                            apiKeyError = "Authentication failed. Check your API key."
                        case .networkError(let message):
                            apiKeyError = message
                        case .unknownError(let message):
                            apiKeyError = message
                        }
                    } else {
                        apiKeyError = error.localizedDescription
                    }
                    
                    isTestingAPIKey = false
                }
            }
        }
    }
    
    private func testClaudeAPIKey() async throws -> Bool {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw TestAPIError.networkError("Invalid URL")
        }
        
        // Minimal test request
        let requestBody: [String: Any] = [
            "model": packageSettings.selectedModel.rawValue,
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": "test"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(symbolService.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestAPIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw TestAPIError.authenticationError
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TestAPIError.unknownError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
    }
}

enum TestAPIError: Error {
    case authenticationError
    case networkError(String)
    case unknownError(String)
}

#Preview {
    AIConfigurationView()
}