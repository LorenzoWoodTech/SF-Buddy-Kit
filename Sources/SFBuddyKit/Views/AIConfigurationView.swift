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
                    
                    if packageSettings.modelProvider == .apple {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(symbolService.appleIntelligenceStatusMessage())
                                .foregroundStyle(symbolService.isAppleIntelligenceAvailable() ? .green : .secondary)
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
                        SecureField("Anthropic API Key", text: $symbolService.claudeAPIKey)
                            .textContentType(.password)
                        
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
                        Text("Create an API key at console.anthropic.com")
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
            }
            .navigationTitle("AI Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Clear error if configuration looks good
                        if packageSettings.modelProvider == .claude && !symbolService.claudeAPIKey.isEmpty {
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
}

#Preview {
    AIConfigurationView()
}