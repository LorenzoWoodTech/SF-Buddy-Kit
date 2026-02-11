//
//  IconCard.swift
//  SFBuddyKit
//
//  SF Symbol card with hover-to-reveal name functionality
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct IconCard: View {
    let symbolName: String
    let isSelected: Bool
    let symbolColor: Color
    let vegasMode: Bool
    let gridScale: Double
    let renderingMode: SymbolRenderingMode
    let showTitle: Bool
    let hasFillVariant: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void
    
    @Environment(VegasSettings.self) private var appSettings
    @State private var isHovered = false
    @State private var isPressed = false
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
        gridScale: Double = 0.5,
        renderingMode: SymbolRenderingMode = .hierarchical,
        showTitle: Bool = false,
        hasFillVariant: Bool = false,
        onHover: @escaping (Bool) -> Void = { _ in },
        action: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.isSelected = isSelected
        self.symbolColor = symbolColor
        self.vegasMode = vegasMode
        self.gridScale = gridScale
        self.renderingMode = renderingMode
        self.showTitle = showTitle
        self.hasFillVariant = hasFillVariant
        self.onHover = onHover
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    cardContent(availableSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .aspectRatio(1.0, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(symbolColor.opacity(isSelected ? 0.12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(alignment: .topTrailing) {
                    if hasFillVariant {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .opacity(isHovered ? 0 : 0.6)
                            .animation(.easeInOut(duration: 0.2), value: isHovered)
                    }
                }
                
                // Optional title below card (outside the card background)
                if showTitle {
                    Text(symbolName)
                        .font(.callout)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .animation(.spring(duration: 0.25), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onHover { hovering in
            withAnimation(.spring(duration: 0.25)) {
                isHovered = hovering
            }
            onHover(hovering)
            #if os(macOS)
            if hovering && !isHovered {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
            #endif
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
    
    // MARK: - Card Content
    @ViewBuilder
    private func cardContent(availableSize: CGSize) -> some View {
        let padding = cardPadding
        let contentSize = min(availableSize.width, availableSize.height) - (padding * 2)
        
        // Display fill variant when hovering if available
        let displaySymbol = (isHovered && hasFillVariant) ? symbolName + ".fill" : symbolName
        
        Image(systemName: displaySymbol)
            .font(.system(size: contentSize * 0.65))
            .foregroundColor(isSelected ? .accentColor : (vegasMode ? randomColor : symbolColor))
            .symbolRenderingMode(renderingMode.swiftUIMode)
            .scaleEffect(vegasMode ? animationScale : 1)
            .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
            .offset(x: vegasMode ? animationOffset : 0)
            .modifier(VegasSymbolEffects(isActive: vegasMode))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
    }
    
    // MARK: - Computed Properties
    private var cardPadding: CGFloat {
        // Scale padding from 8-16 based on gridScale
        8 + (gridScale * 8)
    }
    
    private var strokeColor: Color {
        if isSelected {
            return symbolColor
        } else if isHovered {
            return symbolColor.opacity(0.35)
        } else {
            return Color.secondary.opacity(0.1)
        }
    }
    
    private var strokeWidth: CGFloat {
        isSelected ? 2 : 0.5
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
    VStack(spacing: 20) {
        // Preview with flexible grid
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 12
        ) {
            IconCard(
                symbolName: "heart.fill",
                symbolColor: .red,
                gridScale: 0.5,
                renderingMode: .automatic
            ) {
                print("Tapped heart")
            }
            
            IconCard(
                symbolName: "star.fill",
                isSelected: true,
                symbolColor: .yellow,
                gridScale: 0.5,
                renderingMode: .hierarchical
            ) {
                print("Tapped star")
            }
            
            IconCard(
                symbolName: "bolt.fill",
                symbolColor: .orange,
                vegasMode: false,
                gridScale: 0.5,
                renderingMode: .automatic
            ) {
                print("Tapped bolt")
            }
            
            IconCard(
                symbolName: "flame.fill",
                symbolColor: .red,
                gridScale: 0.5,
                renderingMode: .automatic
            ) {
                print("Tapped flame")
            }
        }
        .padding()
    }
    .frame(width: 400)
    .environment(VegasSettings.shared)
}