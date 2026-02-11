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
    @State private var hoveredIndicatorIndex: Int?
    
    private var hasVariants: Bool {
        !availableVariants.isEmpty
    }
    
    private var fillVariantIndex: Int? {
        availableVariants.firstIndex { $0.variantType == .fill }
    }
    
    private var displayVariant: SymbolVariant {
        // Get the current base variant (could be base or a badge)
        let baseVariant = hasVariants && currentVariantIndex < availableVariants.count 
            ? availableVariants[currentVariantIndex] 
            : SymbolVariant.base(symbolName)
        
        // If Option key is held, try to show filled version of current variant
        if isOptionKeyPressed {
            let fillSymbolName = baseVariant.symbolName.hasSuffix(".fill") 
                ? baseVariant.symbolName 
                : baseVariant.symbolName + ".fill"
            
            // Check if this filled variant exists in our list
            if let filledVariant = availableVariants.first(where: { $0.symbolName == fillSymbolName }) {
                return filledVariant
            }
        }
        
        return baseVariant
    }
    
    private var currentVariant: SymbolVariant {
        if hasVariants && currentVariantIndex < availableVariants.count {
            return availableVariants[currentVariantIndex]
        }
        return .base(symbolName)
    }
    
    private var isShowingFill: Bool {
        displayVariant.symbolName.contains(".fill")
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
            // Variant indicators outside, above card (always reserve space for alignment)
            if hasVariants {
                variantIndicators
            } else {
                Spacer()
                    .frame(height: 20)
            }
            
            GeometryReader { geometry in
                ZStack {
                    // Main card content
                    cardContent(availableSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleMainAction()
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
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    private var variantIndicators: some View {
        let nonBaseVariants = availableVariants.enumerated().filter { $0.element.variantType != .base }
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(nonBaseVariants, id: \.element.id) { index, variant in
                    if let badgeIcon = variant.badgeIcon {
                        let isFillIndicator = variant.variantType == .fill
                        let shouldHighlight: Bool = {
                            if isFillIndicator {
                                // Highlight if we're showing any filled version
                                return isShowingFill
                            } else if variant.variantType == .badge {
                                // For badges, only highlight if EXACTLY this badge variant is selected
                                // Don't strip .fill - we want exact match
                                return currentVariant.symbolName == variant.symbolName
                            } else {
                                // For other variants (slash, circle), highlight if this is the selected variant (excluding fills)
                                let currentBaseName = currentVariant.symbolName.replacingOccurrences(of: ".fill", with: "")
                                let variantBaseName = variant.symbolName.replacingOccurrences(of: ".fill", with: "")
                                return currentBaseName == variantBaseName
                            }
                        }()
                        
                        VariantIndicatorButton(
                            icon: badgeIcon,
                            isActive: shouldHighlight,
                            isHovered: hoveredIndicatorIndex == index,
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
                                
                                Task {
                                    try? await Task.sleep(for: .milliseconds(100))
                                    pressStartedOnIndicator = false
                                }
                            },
                            onHoverChange: { hovering in
                                hoveredIndicatorIndex = hovering ? index : nil
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
        .clipped()
        .frame(height: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var indicatorSize: CGFloat {
        let nonBaseCount = availableVariants.filter { $0.variantType != .base }.count
        // Make indicators smaller when there are many variants
        if nonBaseCount > 4 {
            return 8 + (gridScale * 3)
        } else {
            return 10 + (gridScale * 4)
        }
    }
    
    // MARK: - Main Action
    private func handleMainAction() {
        action()
        
        withAnimation(.spring(duration: 0.3)) {
            showCopyFeedback = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(1.2))
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
        
        ZStack {
            // Main symbol
            Image(systemName: displayVariant.symbolName)
                .font(.system(size: contentSize * 0.65))
                .foregroundColor(isSelected ? .accentColor : (vegasMode ? randomColor : symbolColor))
                .symbolRenderingMode(renderingMode.swiftUIMode)
                .scaleEffect(vegasMode ? animationScale : 1)
                .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
                .offset(x: vegasMode ? animationOffset : 0)
                .modifier(VegasSymbolEffects(isActive: vegasMode))
                .opacity(showCopyFeedback ? 0.2 : 1.0)
                .id(displayVariant.id)
            
            // Copy feedback overlay
            if showCopyFeedback {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: contentSize * 0.5))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showCopyFeedback)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(padding)
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
    let isHovered: Bool
    let size: CGFloat
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size))
            .foregroundStyle(isActive ? .primary : .secondary)
            .scaleEffect(isHovered ? 1.3 : 1.0)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    onHoverChange(true)
                case .ended:
                    onHoverChange(false)
                }
            }
            #endif
            .animation(.spring(duration: 0.2), value: isHovered)
    }
}

#Preview {
    VStack(spacing: 20) {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
            spacing: 20
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
                    .slash("bell"),
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
                    .fill("heart"),
                    .circle("heart"),
                    .circleFill("heart")
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