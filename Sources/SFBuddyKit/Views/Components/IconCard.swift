//
//  IconCard.swift
//  SFBuddyKit
//
//  SF Symbol card with hover-to-reveal variant functionality
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
    let availableVariants: [SymbolVariant]
    let onHover: (Bool) -> Void
    let onVariantChange: (String) -> Void
    let action: () -> Void
    
    @Environment(VegasSettings.self) private var appSettings
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var currentVariantIndex: Int = 0
    @State private var animationOffset: CGFloat = 0
    @State private var animationRotation: Double = 0
    @State private var animationScale: CGFloat = 1
    @State private var randomColor: Color = .primary
    @State private var vegasTimer: Timer?
    
    private var hasVariants: Bool {
        !availableVariants.isEmpty
    }
    
    private var currentVariant: SymbolVariant {
        if hasVariants && currentVariantIndex < availableVariants.count {
            return availableVariants[currentVariantIndex]
        }
        return .base(symbolName)
    }
    
    init(
        symbolName: String,
        isSelected: Bool = false,
        symbolColor: Color = .primary,
        vegasMode: Bool = false,
        gridScale: Double = 0.5,
        renderingMode: SymbolRenderingMode = .hierarchical,
        showTitle: Bool = false,
        availableVariants: [SymbolVariant] = [],
        onHover: @escaping (Bool) -> Void = { _ in },
        onVariantChange: @escaping (String) -> Void = { _ in },
        action: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.isSelected = isSelected
        self.symbolColor = symbolColor
        self.vegasMode = vegasMode
        self.gridScale = gridScale
        self.renderingMode = renderingMode
        self.showTitle = showTitle
        self.availableVariants = availableVariants
        self.onHover = onHover
        self.onVariantChange = onVariantChange
        self.action = action
    }
    
    var body: some View {
        Button {
            // Action uses the currently previewed variant
            action()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack {
                        cardContent(availableSize: geometry.size)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Badge strip overlay at top
                        if hasVariants {
                            badgeStrip
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                    #if os(macOS)
                    .onContinuousHover { phase in
                        handleHover(phase: phase, in: geometry.size)
                    }
                    #else
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleTouch(location: value.location, in: geometry.size)
                            }
                    )
                    #endif
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
                
                // Optional title below card
                if showTitle {
                    Text(currentVariant.symbolName)
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
        .onChange(of: currentVariantIndex) { _, _ in
            onVariantChange(currentVariant.symbolName)
        }
    }
    
    // MARK: - Badge Strip
    @ViewBuilder
    private var badgeStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(availableVariants.enumerated()), id: \.element.id) { index, variant in
                if let badgeIcon = variant.badgeIcon {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 8))
                        .foregroundStyle(index == currentVariantIndex ? .primary : .tertiary)
                        .scaleEffect(index == currentVariantIndex ? 1.2 : 1.0)
                        .animation(.spring(duration: 0.2), value: currentVariantIndex)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(6)
        .opacity(isHovered ? 1 : 0.6)
    }
    
    // MARK: - Hover/Touch Handling
    #if os(macOS)
    private func handleHover(phase: HoverPhase, in size: CGSize) {
        switch phase {
        case .active(let location):
            isHovered = true
            onHover(true)
            updateVariantFromLocation(location, in: size)
            
        case .ended:
            isHovered = false
            onHover(false)
            // Reset to base variant when hover ends
            currentVariantIndex = 0
        }
    }
    #else
    private func handleTouch(location: CGPoint, in size: CGSize) {
        isHovered = true
        updateVariantFromLocation(location, in: size)
    }
    #endif
    
    private func updateVariantFromLocation(_ location: CGPoint, in size: CGSize) {
        guard hasVariants else { return }
        
        let segmentWidth = size.width / CGFloat(availableVariants.count)
        let newIndex = min(Int(location.x / segmentWidth), availableVariants.count - 1)
        
        if newIndex != currentVariantIndex && newIndex >= 0 {
            currentVariantIndex = newIndex
            
            #if os(macOS)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            #endif
        }
    }
    
    // MARK: - Card Content
    @ViewBuilder
    private func cardContent(availableSize: CGSize) -> some View {
        let padding = cardPadding
        let contentSize = min(availableSize.width, availableSize.height) - (padding * 2)
        
        Image(systemName: currentVariant.symbolName)
            .font(.system(size: contentSize * 0.65))
            .foregroundColor(isSelected ? .accentColor : (vegasMode ? randomColor : symbolColor))
            .symbolRenderingMode(renderingMode.swiftUIMode)
            .scaleEffect(vegasMode ? animationScale : 1)
            .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
            .offset(x: vegasMode ? animationOffset : 0)
            .modifier(VegasSymbolEffects(isActive: vegasMode))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
            .id(currentVariant.id)
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
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 12
        ) {
            IconCard(
                symbolName: "app",
                symbolColor: .blue,
                gridScale: 0.5,
                renderingMode: .hierarchical,
                availableVariants: [
                    .base("app"),
                    .fill("app"),
                    .badge("app", badgeType: .badgePlus),
                    .badge("app", badgeType: .badgeCheckmark)
                ]
            ) {
                print("Tapped app")
            }
            
            IconCard(
                symbolName: "folder",
                symbolColor: .cyan,
                gridScale: 0.5,
                renderingMode: .hierarchical,
                availableVariants: [
                    .base("folder"),
                    .fill("folder"),
                    .badge("folder", badgeType: .badge),
                    .badge("folder", badgeType: .badgePlus)
                ]
            ) {
                print("Tapped folder")
            }
            
            IconCard(
                symbolName: "bell",
                symbolColor: .orange,
                gridScale: 0.5,
                renderingMode: .hierarchical,
                availableVariants: [
                    .base("bell"),
                    .fill("bell"),
                    .badge("bell", badgeType: .badge)
                ]
            ) {
                print("Tapped bell")
            }
            
            IconCard(
                symbolName: "heart",
                symbolColor: .red,
                gridScale: 0.5,
                renderingMode: .hierarchical,
                availableVariants: [
                    .base("heart"),
                    .fill("heart")
                ]
            ) {
                print("Tapped heart")
            }
        }
        .padding()
    }
    .frame(width: 500)
    .environment(VegasSettings.shared)
}