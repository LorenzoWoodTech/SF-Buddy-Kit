//
//  IconCard.swift
//  SFBuddyKit
//
//  SF Symbol card with tap-to-switch variant functionality
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
    @State private var currentVariantIndex: Int = 0
    @State private var animationOffset: CGFloat = 0
    @State private var animationRotation: Double = 0
    @State private var animationScale: CGFloat = 1
    @State private var randomColor: Color = .primary
    @State private var vegasTimer: Timer?
    @State private var showCopyFeedback = false
    @State private var isDraggingOnIndicator = false
    @State private var pressStartedOnIndicator = false
    
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
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack {
                    // Main card content
                    cardContent(availableSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Only trigger action if we didn't start on an indicator
                            if !pressStartedOnIndicator {
                                handleMainAction()
                            }
                        }
                    
                    // Variant indicators (always visible, but skip base variant)
                    if hasVariants {
                        variantIndicators(in: geometry.size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Copy feedback overlay
                    if showCopyFeedback {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.green.opacity(0.2))
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: geometry.size.width * 0.4))
                                    .foregroundStyle(.green)
                                    .symbolEffect(.bounce, value: showCopyFeedback)
                            )
                            .transition(.scale.combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                #if os(macOS)
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isHovered = true
                        onHover(true)
                    case .ended:
                        isHovered = false
                        onHover(false)
                    }
                }
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
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(duration: 0.25), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            // Optional title below card
            if showTitle {
                Text(currentVariant.symbolName)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .onChange(of: currentVariantIndex) { _, _ in
            onVariantChange(currentVariant.symbolName)
        }
    }
    
    // MARK: - Variant Indicators
    @ViewBuilder
    private func variantIndicators(in size: CGSize) -> some View {
        ZStack {
            ForEach(Array(availableVariants.enumerated()), id: \.element.id) { index, variant in
                // Skip base variant - it doesn't need an indicator
                if variant.variantType != .base, let badgeIcon = variant.badgeIcon {
                    let alignment = cornerAlignment(for: index, variant: variant)
                    let hitTestSize: CGFloat = 44 // Increased from 32
                    
                    Image(systemName: badgeIcon)
                        .font(.system(size: indicatorSize))
                        .foregroundStyle(index == currentVariantIndex ? .primary : .secondary)
                        .scaleEffect(index == currentVariantIndex ? 1.3 : 1.0)
                        .animation(.spring(duration: 0.2), value: currentVariantIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                        .padding(10)
                        .contentShape(Rectangle().size(width: hitTestSize, height: hitTestSize))
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2)) {
                                // If tapping the active variant, deselect it (return to base)
                                if index == currentVariantIndex {
                                    currentVariantIndex = 0
                                } else {
                                    currentVariantIndex = index
                                }
                            }
                            pressStartedOnIndicator = true
                            
                            #if os(macOS)
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            #endif
                            
                            // Reset flag after a short delay
                            Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                pressStartedOnIndicator = false
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingOnIndicator {
                                        isDraggingOnIndicator = true
                                        pressStartedOnIndicator = true
                                    }
                                    
                                    // Check if we're over a different indicator
                                    if let newIndex = findIndicatorAt(location: value.location, in: size) {
                                        if newIndex != currentVariantIndex {
                                            withAnimation(.spring(duration: 0.15)) {
                                                currentVariantIndex = newIndex
                                            }
                                            
                                            #if os(macOS)
                                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                            #endif
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    isDraggingOnIndicator = false
                                    Task {
                                        try? await Task.sleep(for: .milliseconds(100))
                                        pressStartedOnIndicator = false
                                    }
                                }
                        )
                }
            }
        }
    }
    
    private var indicatorSize: CGFloat {
        return 11 + (gridScale * 5) // Slightly larger
    }
    
    private func cornerAlignment(for index: Int, variant: SymbolVariant) -> Alignment {
        // Organize by variant type:
        // - Base: not shown (no indicator)
        // - Fill: bottom-left
        // - Badges: right side (top-right, bottom-right, then wrap)
        
        switch variant.variantType {
        case .base:
            return .topLeading // Won't be shown anyway
        case .fill:
            return .bottomLeading
        case .badge:
            // Count how many badge variants come before this one
            let badgeIndex = availableVariants.prefix(index).filter { $0.variantType == .badge }.count
            switch badgeIndex {
            case 0: return .topTrailing
            case 1: return .bottomTrailing
            case 2: return .topLeading // Wrap to left side if more than 2 badges
            default: return .bottomLeading // Continue wrapping
            }
        }
    }
    
    private func findIndicatorAt(location: CGPoint, in size: CGSize) -> Int? {
        let indicatorHitSize: CGFloat = 44
        let padding: CGFloat = 10
        
        for (index, variant) in availableVariants.enumerated() {
            // Skip base variant
            guard variant.variantType != .base else { continue }
            
            let alignment = cornerAlignment(for: index, variant: variant)
            
            var indicatorRect: CGRect
            switch alignment {
            case .topLeading:
                indicatorRect = CGRect(x: 0, y: 0, width: indicatorHitSize + padding, height: indicatorHitSize + padding)
            case .topTrailing:
                indicatorRect = CGRect(x: size.width - indicatorHitSize - padding, y: 0, width: indicatorHitSize + padding, height: indicatorHitSize + padding)
            case .bottomTrailing:
                indicatorRect = CGRect(x: size.width - indicatorHitSize - padding, y: size.height - indicatorHitSize - padding, width: indicatorHitSize + padding, height: indicatorHitSize + padding)
            case .bottomLeading:
                indicatorRect = CGRect(x: 0, y: size.height - indicatorHitSize - padding, width: indicatorHitSize + padding, height: indicatorHitSize + padding)
            default:
                continue
            }
            
            if indicatorRect.contains(location) {
                return index
            }
        }
        
        return nil
    }
    
    // MARK: - Main Action
    private func handleMainAction() {
        action()
        
        // Show copy feedback
        withAnimation(.spring(duration: 0.3)) {
            showCopyFeedback = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run {
                withAnimation(.spring(duration: 0.3)) {
                    showCopyFeedback = false
                }
            }
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
                    .badge("bell", badgeType: .badge),
                    .badge("bell", badgeType: .trianglebadgeExclamationmark)
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