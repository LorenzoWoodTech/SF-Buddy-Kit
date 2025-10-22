//
//  SymbolPickerView.swift
//  SF Buddy
//
//  Symbol picker and related components for the existing symbol search functionality
//

import SwiftUI

public struct SymbolPickerView: View {
    @StateObject private var symbolService = SFSymbolService.shared
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    @State private var selectedColor: Color = .primary
    @State private var showingStylePopover = false
    @State private var showingColorPopover = false
    @State private var showingGridSizePopover = false
    @State private var showingVegasSettingsPopover = false
    @State private var vegasMode = false
    @State private var gridSize: GridSize = .medium

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button {
                        showingGridSizePopover.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: gridSize.gridIconName)
                                .font(.caption)
                            Text("Grid")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingGridSizePopover) {
                        GridSizePopover(selectedGridSize: $gridSize)
                    }
                    
                    Button {
                        showingStylePopover.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.grid.2x2")
                                .font(.caption)
                            Text("Render")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingStylePopover) {
                        RenderingModePopover(
                            selectedRenderingMode: $symbolService.currentRenderingMode
                        )
                    }
                    
                    Button {
                        showingColorPopover.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.primary.opacity(0.3), lineWidth: 0.5)
                                )
                            Text("Colors")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingColorPopover) {
                        ColorPickerPopover(
                            selectedColor: $selectedColor
                        )
                    }
                    
                    Button {
                        withAnimation(.bouncy) {
                            vegasMode.toggle()
                        }
                    } label: {
                        Image(systemName: vegasMode ? "sparkles" : "sparkles")
                            .font(.caption)
                            .foregroundColor(vegasMode ? .yellow : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(vegasMode ? Color.yellow.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Trigger Chaos") {
                            vegasSettings.triggerVegasChaos()
                        }
                        
                        Button("Randomize Settings") {
                            vegasSettings.randomizeVegas()
                        }
                        
                        Divider()
                        
                        Button(vegasMode ? "Disable Vegas Mode" : "Enable Vegas Mode") {
                            withAnimation(.bouncy) {
                                vegasMode.toggle()
                            }
                        }
                    }
                    .popover(isPresented: $showingVegasSettingsPopover) {
                        VegasSettingsPopover()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)

                if !symbolService.suggestedSymbols.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: gridSize.buttonSize.min, maximum: gridSize.buttonSize.max), spacing: 10), count: gridSize.columnCount), spacing: 10) {
                        ForEach(symbolService.suggestedSymbols) { suggestion in
                            SymbolButton(suggestion: suggestion, symbolColor: selectedColor, vegasMode: vegasMode, gridSize: gridSize)
                        }
                    }
                    .padding(.horizontal, 16)
                } else if symbolService.suggestedSymbols.isEmpty && !symbolService.invalidSymbolNamesFromClaude.isEmpty {
                    Text("All suggested symbols appear to be invalid or non-existent.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding()
                } else if symbolService.suggestedSymbols.isEmpty && symbolService.apiKeyMissingOrInvalid && !symbolService.lastProcessedText.isEmpty {
                }

                if !symbolService.invalidSymbolNamesFromClaude.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Model suggested \(symbolService.invalidSymbolNamesFromClaude.count) invalid symbol name(s):")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text(symbolService.invalidSymbolNamesFromClaude.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(3)
                            .padding(.leading, 20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

            }
            .padding(.vertical)
        }
    }
}

// MARK: - Supporting Views and Components
// (Moving all the supporting views from ContentView here)

enum GridSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var columnCount: Int {
        switch self {
        case .small: return 8
        case .medium: return 4
        case .large: return 3
        case .extraLarge: return 1
        }
    }
    
    var gridIconName: String {
        switch self {
        case .small: return "grid"
        case .medium: return "square.grid.2x2"
        case .large: return "rectangle.grid.1x2"
        case .extraLarge: return "square.fill"
        }
    }
    
    var symbolSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 24
        case .large: return 32
        case .extraLarge: return 64
        }
    }
    
    var buttonSize: (min: CGFloat, max: CGFloat, height: CGFloat) {
        switch self {
        case .small: return (40, 50, 50)
        case .medium: return (70, 85, 75)
        case .large: return (90, 110, 90)
        case .extraLarge: return (300, 350, 140)
        }
    }
    
    var showNames: Bool {
        switch self {
        case .small: return false
        default: return true
        }
    }
}

private struct GridSizePopover: View {
    @Binding var selectedGridSize: GridSize
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grid Size")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(GridSize.allCases) { size in
                    Button {
                        selectedGridSize = size
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: size.gridIconName)
                                .font(.caption)
                            Text(size.displayName)
                                .font(.caption)
                            Spacer()
                            if selectedGridSize == size {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(selectedGridSize == size ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct RenderingModePopover: View {
    @Binding var selectedRenderingMode: ServiceRenderingMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Render Mode")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(ServiceRenderingMode.allCases) { mode in
                    Button {
                        selectedRenderingMode = mode
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: mode.iconName)
                                .font(.caption)
                            Text(mode.displayName)
                                .font(.caption)
                            Spacer()
                            if selectedRenderingMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(selectedRenderingMode == mode ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ColorPickerPopover: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    private let systemColors: [(String, Color)] = [
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Cyan", .cyan),
        ("Blue", .blue),
        ("Indigo", .indigo),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Brown", .brown),
        ("Gray", .gray),
        ("Primary", .primary),
        ("Secondary", .secondary),
        ("Accent", .accentColor)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 3), count: 8), spacing: 3) {
                ForEach(systemColors, id: \.0) { colorName, color in
                    Button {
                        selectedColor = color
                        dismiss()
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedColor == color ? .primary : Color.clear, lineWidth: 1.5)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(colorName)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
    }
}

struct SymbolButton: View {
    let suggestion: SFSymbolSuggestion
    let symbolColor: Color
    let vegasMode: Bool
    let gridSize: GridSize
    @StateObject private var symbolService = SFSymbolService.shared
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    @State private var isHovered = false
    @State private var justCopied = false
    @State private var animationOffset: CGFloat = 0
    @State private var animationRotation: Double = 0
    @State private var animationScale: CGFloat = 1
    @State private var randomColor: Color = .primary
    @State private var vegasTimer: Timer?

    var body: some View {
        let symbolContent = VStack(spacing: 4) {
            if justCopied {
                copySuccessIndicator
            } else {
                symbolImageView
                if gridSize.showNames {
                    symbolNameText
                }
            }
        }
        
        return symbolContent
            .frame(minWidth: gridSize.buttonSize.min, maxWidth: gridSize.buttonSize.max, minHeight: gridSize.buttonSize.height, maxHeight: gridSize.buttonSize.height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered && !justCopied ? Color.accentColor : Color.clear)
                    .opacity(vegasMode ? 0.1 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .onHover { hovering in
                if !justCopied {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
            }
            .onTapGesture {
                if !justCopied {
                    symbolService.replaceTextWithSymbol(suggestion.name)
                    withAnimation {
                        justCopied = true
                    }

                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        await MainActor.run {
                            withAnimation {
                                justCopied = false
                            }
                        }
                    }
                }
            }
            .draggable(suggestion.name) {
                VStack(spacing: 2) {
                    Image(systemName: suggestion.name)
                        .font(.system(size: 16))
                        .foregroundColor(vegasMode ? randomColor : symbolColor)
                    Text(suggestion.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial)
                }
            }
            .onAppear {
                if vegasMode {
                    startVegasAnimations()
                }
            }
            .onChange(of: vegasMode) { oldValue, newValue in
                if newValue {
                    startVegasAnimations()
                } else {
                    stopVegasAnimations()
                }
            }
            .onChange(of: vegasSettings.vegasAnimationSpeed) { _, _ in if vegasMode { restartVegasAnimations() } }
            .onChange(of: vegasSettings.vegasColorCycleSpeed) { _, _ in if vegasMode { restartVegasAnimations() } }
            .onChange(of: vegasSettings.vegasIntensity) { _, _ in if vegasMode { restartVegasAnimations() } }
            .onChange(of: vegasSettings.vegasRotationEnabled) { _, _ in if vegasMode { restartVegasAnimations() } }
    }
    
    private var copySuccessIndicator: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: gridSize.symbolSize + 6))
                .foregroundColor(.green)
            Text("Copied!")
                .font(.caption)
                .foregroundColor(.green)
        }
    }
    
    private var symbolImageView: some View {
        Image(systemName: suggestion.name)
            .font(.system(size: gridSize.symbolSize))
            .foregroundColor(isHovered ? .white : (vegasMode ? randomColor : symbolColor))
            .symbolRenderingMode(symbolRenderingMode)
            .frame(width: gridSize.symbolSize + 12, height: gridSize.symbolSize + 12)
            .scaleEffect(vegasMode ? animationScale : 1)
            .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
            .offset(x: vegasMode ? animationOffset : 0)
    }
    
    private var symbolNameText: some View {
        Text(suggestion.name)
            .font(.caption2)
            .foregroundColor(isHovered ? .white : .secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func restartVegasAnimations() {
        stopVegasAnimations()
        startVegasAnimations()
    }

    private func startVegasAnimations() {
        vegasTimer?.invalidate()
        vegasTimer = nil

        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
        randomColor = colors.randomElement() ?? .primary
        
        let baseSpeed = 2.5 / vegasSettings.vegasAnimationSpeed
        let intensity = vegasSettings.vegasIntensity
        let colorSpeed = 1.5 / vegasSettings.vegasColorCycleSpeed
        
        let randomnessFactor = vegasSettings.vegasRandomnessLevel
        let scaleRange = vegasSettings.vegasScaleIntensity
        let movementRange = vegasSettings.vegasMovementIntensity
        
        let minScale = 1.0 - (0.2 * intensity * randomnessFactor)
        let maxScale = 1.0 + (0.3 * intensity * randomnessFactor) + scaleRange
        
        withAnimation(.easeInOut(duration: Double.random(in: baseSpeed...baseSpeed*1.5)).repeatForever(autoreverses: true)) {
            animationScale = Double.random(in: minScale...maxScale)
        }
        
        if vegasSettings.vegasRotationEnabled {
            let rotationSpeed = Double.random(in: (4.0/intensity)...(6.0/intensity)) * (1.0 + randomnessFactor)
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                animationRotation = 360
            }
        } else {
            animationRotation = 0
        }
        
        let movementIntensity = movementRange * randomnessFactor
        withAnimation(.easeInOut(duration: Double.random(in: baseSpeed...(baseSpeed*2.0))).repeatForever(autoreverses: true)) {
            animationOffset = Double.random(in: (-movementIntensity)...(movementIntensity))
        }
        
        let variableColorSpeed = colorSpeed * (0.5 + randomnessFactor)
        vegasTimer = Timer.scheduledTimer(withTimeInterval: variableColorSpeed, repeats: true) { timer in
            if !vegasMode {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    randomColor = colors.randomElement() ?? .primary
                }
            }
        }
    }
    
    private func stopVegasAnimations() {
        vegasTimer?.invalidate()
        vegasTimer = nil

        withAnimation(.easeOut(duration: 0.5)) {
            animationScale = 1
            animationRotation = 0
            animationOffset = 0
            randomColor = symbolColor
        }
    }

    private var symbolRenderingMode: SymbolRenderingMode {
        switch symbolService.currentRenderingMode {
        case .monochrome:
            return .monochrome
        case .hierarchical:
            return .hierarchical
        case .palette:
            return .palette
        case .multicolor:
            return .multicolor
        }
    }
}

// MARK: - Complete Vegas Settings Popover (EXACTLY from SymbolPickerView)
struct VegasSettingsPopover: View {
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        @Bindable var vegasSettings = vegasSettings
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Vegas Mode Settings")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Animation Speed:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasAnimationSpeed, in: 0.5...3.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", vegasSettings.vegasAnimationSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Color Cycling:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasColorCycleSpeed, in: 0.2...5.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", vegasSettings.vegasColorCycleSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Intensity:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasIntensity, in: 0.3...2.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1fx", vegasSettings.vegasIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Randomness:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasRandomnessLevel, in: 0.0...1.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1f", vegasSettings.vegasRandomnessLevel))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Scale Chaos:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasScaleIntensity, in: 0.1...1.0, step: 0.1)
                        .frame(width: 80)
                    Text(String(format: "%.1f", vegasSettings.vegasScaleIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Movement:")
                        .font(.caption2)
                    Spacer()
                    Slider(value: $vegasSettings.vegasMovementIntensity, in: 1.0...15.0, step: 1.0)
                        .frame(width: 80)
                    Text(String(format: "%.0f", vegasSettings.vegasMovementIntensity))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 25)
                }
                
                HStack {
                    Text("Rotation:")
                        .font(.caption2)
                    Spacer()
                    Toggle("", isOn: $vegasSettings.vegasRotationEnabled)
                        .controlSize(.mini)
                }
            }
            
            HStack {
                Button("Randomize") {
                    vegasSettings.randomizeVegas()
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
    SymbolPickerView()
        .environmentObject(SFSymbolService.shared)
        .environment(SFSymbolVegasSettings.shared)
}