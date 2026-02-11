//
//  VegasEffects.swift
//  SFBuddyKit
//
//  Shared Vegas Mode effects and settings popover
//

import SwiftUI

// MARK: - Vegas Symbol Effects Modifier
struct VegasSymbolEffects: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content
                .symbolEffect(.bounce, isActive: isActive)
                .symbolEffect(.pulse, isActive: isActive)
        } else {
            content
        }
    }
}

// MARK: - Vegas Settings Popover
struct VegasSettingsPopover: View {
    @Environment(VegasSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        @Bindable var appSettings = appSettings
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Vegas Mode Settings")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Animation Speed:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasAnimationSpeed, in: 0.5...3.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", appSettings.vegasAnimationSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Color Cycling:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasColorCycleSpeed, in: 0.2...5.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", appSettings.vegasColorCycleSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Intensity:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasIntensity, in: 0.3...2.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", appSettings.vegasIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Randomness:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasRandomnessLevel, in: 0.0...1.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1f", appSettings.vegasRandomnessLevel))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Scale Chaos:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasScaleIntensity, in: 0.1...1.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1f", appSettings.vegasScaleIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Movement:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $appSettings.vegasMovementIntensity, in: 1.0...15.0, step: 1.0)
                        .frame(width: 80)
                    Text(String(format: "%.0f", appSettings.vegasMovementIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Rotation:")
                        .font(.caption2)
                    Spacer()
                    Toggle("", isOn: $appSettings.vegasRotationEnabled)
                        .controlSize(.mini)
                }
            }
            
            HStack {
                Button("Randomize") {
                    VegasSettings.shared.randomizeVegas()
                }
                .font(.caption)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.caption)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(width: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VegasSettingsPopover()
        .environment(VegasSettings.shared)
}