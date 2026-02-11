//
//  SymbolGridButton.swift
//  SFBuddyKit
//
//  Shared symbol grid button with Vegas mode support
//

import SwiftUI

struct SymbolGridButton: View {
    let symbolName: String
    let isSelected: Bool
    let symbolColor: Color
    let vegasMode: Bool
    let gridSize: SymbolGridSize
    let renderingMode: SymbolRenderingMode
    let justCopied: Bool
    let action: () -> Void
    
    @Environment(VegasSettings.self) private var appSettings
    @State private var isHovered = false
    @State private var animationOffset: CGFloat = 0
    @State private var animationRotation: Double = 0
    @State private var animationScale: CGFloat = 1
    @State private var randomColor: Color = .primary
    @State private var vegasTimer: Timer?
    
    init(
        symbolName: String,
        isSelected: Bool = false,
        symbolColor: Color = .primary,
        vegasMode: Bool = false,
        gridSize: SymbolGridSize = .medium,
        renderingMode: SymbolRenderingMode = .hierarchical,
        justCopied: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.isSelected = isSelected
        self.symbolColor = symbolColor
        self.vegasMode = vegasMode
        self.gridSize = gridSize
        self.renderingMode = renderingMode
        self.justCopied = justCopied
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if justCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: gridSize.symbolSize + 6))
                        .foregroundColor(.green)
                    if gridSize.showNames {
                        Text("Copied!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: gridSize.symbolSize))
                        .foregroundColor(isHovered || isSelected ? .white : (vegasMode ? randomColor : symbolColor))
                        .symbolRenderingMode(renderingMode.swiftUIMode)
                        .frame(width: gridSize.symbolSize + 12, height: gridSize.symbolSize + 12)
                        .scaleEffect(vegasMode ? animationScale : 1)
                        .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
                        .offset(x: vegasMode ? animationOffset : 0)
                        .modifier(VegasSymbolEffects(isActive: vegasMode))
                    
                    if gridSize.showNames {
                        Text(symbolName)
                            .font(.caption2)
                            .foregroundColor(isHovered || isSelected ? .white : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(
                minWidth: gridSize.buttonSize.min,
                maxWidth: gridSize.buttonSize.max,
                minHeight: gridSize.buttonSize.height,
                maxHeight: gridSize.buttonSize.height
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered || isSelected ? Color.accentColor : Color.clear)
                    .opacity(vegasMode && !justCopied ? 0.8 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if !justCopied {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .onAppear {
            if vegasMode {
                startVegasAnimations()
            }
        }
        .onChange(of: vegasMode) { _, newValue in
            if newValue {
                startVegasAnimations()
            } else {
                stopVegasAnimations()
            }
        }
        .onChange(of: appSettings.vegasAnimationSpeed) { _, _ in
            if vegasMode { restartVegasAnimations() }
        }
        .onChange(of: appSettings.vegasColorCycleSpeed) { _, _ in
            if vegasMode { restartVegasAnimations() }
        }
        .onChange(of: appSettings.vegasIntensity) { _, _ in
            if vegasMode { restartVegasAnimations() }
        }
        .onChange(of: appSettings.vegasRotationEnabled) { _, _ in
            if vegasMode { restartVegasAnimations() }
        }
    }
    
    // MARK: - Vegas Animation Logic
    private func restartVegasAnimations() {
        stopVegasAnimations()
        startVegasAnimations()
    }
    
    private func startVegasAnimations() {
        vegasTimer?.invalidate()
        vegasTimer = nil
        
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
        randomColor = colors.randomElement() ?? .primary
        
        let baseSpeed = 2.5 / appSettings.vegasAnimationSpeed
        let intensity = appSettings.vegasIntensity
        let colorSpeed = 1.5 / appSettings.vegasColorCycleSpeed
        
        let randomnessFactor = appSettings.vegasRandomnessLevel
        let scaleRange = appSettings.vegasScaleIntensity
        let movementRange = appSettings.vegasMovementIntensity
        
        let minScale = 1.0 - (0.2 * intensity * randomnessFactor)
        let maxScale = 1.0 + (0.3 * intensity * randomnessFactor) + scaleRange
        
        withAnimation(
            .easeInOut(duration: Double.random(in: baseSpeed...baseSpeed*1.5))
            .repeatForever(autoreverses: true)
        ) {
            animationScale = Double.random(in: minScale...maxScale)
        }
        
        if appSettings.vegasRotationEnabled {
            let rotationSpeed = Double.random(in: (4.0/intensity)...(6.0/intensity)) * (1.0 + randomnessFactor)
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                animationRotation = 360
            }
        } else {
            animationRotation = 0
        }
        
        let movementIntensity = movementRange * randomnessFactor
        withAnimation(
            .easeInOut(duration: Double.random(in: baseSpeed...(baseSpeed*2.0)))
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = Double.random(in: (-movementIntensity)...(movementIntensity))
        }
        
        let variableColorSpeed = colorSpeed * (0.5 + randomnessFactor)
        vegasTimer = Timer.scheduledTimer(withTimeInterval: variableColorSpeed, repeats: true) { timer in
            if !vegasMode {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                randomColor = colors.randomElement() ?? .primary
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
}

#Preview {
    HStack(spacing: 20) {
        SymbolGridButton(
            symbolName: "heart.fill",
            symbolColor: .red,
            gridSize: .medium,
            renderingMode: .multicolor
        ) {
            print("Tapped")
        }
        
        SymbolGridButton(
            symbolName: "star.fill",
            isSelected: true,
            symbolColor: .yellow,
            gridSize: .large,
            renderingMode: .hierarchical
        ) {
            print("Tapped")
        }
        
        SymbolGridButton(
            symbolName: "bolt.fill",
            symbolColor: .orange,
            vegasMode: true,
            gridSize: .medium,
            renderingMode: .multicolor
        ) {
            print("Tapped")
        }
    }
    .padding()
    .environment(VegasSettings.shared)
}
