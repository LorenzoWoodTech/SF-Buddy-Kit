//
//  SettingsView.swift
//  SFBuddyKit
//
//  Comprehensive settings view for the SF Symbol package
//

import SwiftUI

public struct SettingsView: View {
    @StateObject private var symbolService = SFSymbolService.shared
    @Environment(SFSymbolPackageSettings.self) private var packageSettings
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    
    public init() {}
    
    public var body: some View {
        @Bindable var packageSettings = packageSettings
        @Bindable var vegasSettings = vegasSettings
        
        VStack(spacing: 20) {
            Text("SF Buddy Settings")
                .font(.title2)
                .padding()
            
            Form {
                Section("Claude API") {
                    SecureField("API Key", text: $symbolService.claudeAPIKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Model", selection: $packageSettings.selectedModel) {
                        ForEach(ClaudeModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    
                    Stepper("Symbol Count: \(packageSettings.symbolCount)", value: $packageSettings.symbolCount, in: 4...24)
                }
                
                Section("Vegas Mode") {
                    HStack {
                        Text("Animation Speed")
                        Slider(value: $vegasSettings.vegasAnimationSpeed, in: 0.5...3.0)
                        Text("\(vegasSettings.vegasAnimationSpeed, specifier: "%.1f")x")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Color Cycling")
                        Slider(value: $vegasSettings.vegasColorCycleSpeed, in: 0.2...5.0)
                        Text("\(vegasSettings.vegasColorCycleSpeed, specifier: "%.1f")x")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Intensity")
                        Slider(value: $vegasSettings.vegasIntensity, in: 0.3...2.0)
                        Text("\(vegasSettings.vegasIntensity, specifier: "%.1f")x")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Randomness")
                        Slider(value: $vegasSettings.vegasRandomnessLevel, in: 0.0...1.0)
                        Text("\(vegasSettings.vegasRandomnessLevel, specifier: "%.1f")")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Scale Chaos")
                        Slider(value: $vegasSettings.vegasScaleIntensity, in: 0.1...1.0)
                        Text("\(vegasSettings.vegasScaleIntensity, specifier: "%.1f")")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Movement")
                        Slider(value: $vegasSettings.vegasMovementIntensity, in: 1.0...15.0)
                        Text("\(Int(vegasSettings.vegasMovementIntensity))")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    
                    Toggle("Enable Rotation", isOn: $vegasSettings.vegasRotationEnabled)
                    
                    HStack {
                        Button("Randomize All") {
                            vegasSettings.randomizeVegas()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Trigger Chaos") {
                            vegasSettings.triggerVegasChaos()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Package", value: "SFBuddyKit")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(SFSymbolPackageSettings.shared)
        .environment(SFSymbolVegasSettings.shared)
}
