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
    @State private var isOptionKeyPressed = false
    
    private var hasVariants: Bool {
        !availableVariants.isEmpty
    }
    
    private var fillVariantIndex: Int? {
        availableVariants.firstIndex { $0.variantType == .fill }
    }
    
    private var displayVariant: SymbolVariant {
        // If Option key is held and we have a fill variant, show it
        if isOptionKeyPressed, let fillIndex = fillVariantIndex {
            return availableVariants[fillIndex]
        }
        
        // Otherwise show current variant
        if hasVariants && currentVariantIndex < availableVariants.count {
            return availableVariants[currentVariantIndex]
        }
        return .base(symbolName)
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
                Text(displayVariant.symbolName)
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
            #if os(macOS)
            startMonitoringKeyboard()
            #endif
        }
        .onDisappear {
            #if os(macOS)
            stopMonitoringKeyboard()
            #endif
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
        .onChange(of: isOptionKeyPressed) { _, _ in
            // Update display when Option key state changes
            onVariantChange(displayVariant.symbolName)
        }
    }
    
    // MARK: - Keyboard Monitoring
    #if os(macOS)
    private func startMonitoringKeyboard() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isOptionKeyPressed = event.modifierFlags.contains(.option)
            return event
        }
    }
    
    private func stopMonitoringKeyboard() {
        // Event monitor cleanup happens automatically
    }
    #endif
    
    // MARK: - Variant Indicators
    @ViewBuilder
    private func variantIndicators(in size: CGSize) -> some View {
        ForEach(Array(availableVariants.enumerated()), id: \.element.id) { index, variant in
            // Skip base variant - it doesn't need an indicator
            if variant.variantType != .base, let badgeIcon = variant.badgeIcon {
                let alignment = cornerAlignment(for: index, variant: variant)
                
                VariantIndicatorButton(
                    icon: badgeIcon,
                    isActive: index == currentVariantIndex,
                    alignment: alignment,
                    size: indicatorSize,
                    onTap: {
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
                        
                        Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            pressStartedOnIndicator = false
                        }
                    },
                    onDragChanged: { location in
                        if !isDraggingOnIndicator {
                            isDraggingOnIndicator = true
                            pressStartedOnIndicator = true
                        }
                        
                        if let newIndex = findIndicatorAt(location: location, in: size) {
                            if newIndex != currentVariantIndex {
                                withAnimation(.spring(duration: 0.15)) {
                                    currentVariantIndex = newIndex
                                }
                                
                                #if os(macOS)
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                #endif
                            }
                        }
                    },
                    onDragEnded: {
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
    
    private var indicatorSize: CGFloat {
        return 12 + (gridScale * 5)
    }
    
    private func cornerAlignment(for index: Int, variant: SymbolVariant) -> Alignment {
        switch variant.variantType {
        case .base:
            return .topLeading
        case .fill:
            return .bottomLeading
        case .badge:
            let badgeIndex = availableVariants.prefix(index).filter { $0.variantType == .badge }.count
            switch badgeIndex {
            case 0: return .topTrailing
            case 1: return .bottomTrailing
            case 2: return .topLeading
            default: return .bottomLeading
            }
        }
    }
    
    private func findIndicatorAt(location: CGPoint, in size: CGSize) -> Int? {
        let hitSize: CGFloat = 44
        
        for (index, variant) in availableVariants.enumerated() {
            guard variant.variantType != .base else { continue }
            
            let alignment = cornerAlignment(for: index, variant: variant)
            let rect = hitRect(for: alignment, size: size, hitSize: hitSize)
            
            if rect.contains(location) {
                return index
            }
        }
        
        return nil
    }
    
    private func hitRect(for alignment: Alignment, size: CGSize, hitSize: CGFloat) -> CGRect {
        switch alignment {
        case .topLeading:
            return CGRect(x: 0, y: 0, width: hitSize, height: hitSize)
        case .topTrailing:
            return CGRect(x: size.width - hitSize, y: 0, width: hitSize, height: hitSize)
        case .bottomTrailing:
            return CGRect(x: size.width - hitSize, y: size.height - hitSize, width: hitSize, height: hitSize)
        case .bottomLeading:
            return CGRect(x: 0, y: size.height - hitSize, width: hitSize, height: hitSize)
        default:
            return .zero
        }
    }
    
    // MARK: - Main Action
    private func handleMainAction() {
        action()
        
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
        
        Image(systemName: displayVariant.symbolName)
            .font(.system(size: contentSize * 0.65))
            .foregroundColor(isSelected ? .accentColor : (vegasMode ? randomColor : symbolColor))
            .symbolRenderingMode(renderingMode.swiftUIMode)
            .scaleEffect(vegasMode ? animationScale : 1)
            .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
            .offset(x: vegasMode ? animationOffset : 0)
            .modifier(VegasSymbolEffects(isActive: vegasMode))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
            .id(displayVariant.id)
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

// MARK: - Variant Indicator Button Component
private struct VariantIndicatorButton: View {
    let icon: String
    let isActive: Bool
    let alignment: Alignment
    let size: CGFloat
    let onTap: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size))
            .foregroundStyle(isActive ? .primary : .secondary)
            .scaleEffect(isActive ? 1.3 : 1.0)
            .frame(width: 44, height: 44) // Fixed frame for consistent hit area
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .onTapGesture {
                onTap()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onDragChanged(value.location)
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
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
                    .badge("app.badge.plus", baseSymbolName: "app"),
                    .badge("app.badge.checkmark", baseSymbolName: "app")
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
                    .badge("folder.badge", baseSymbolName: "folder"),
                    .badge("folder.badge.gearshape", baseSymbolName: "folder")
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
                    .badge("bell.badge", baseSymbolName: "bell")
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