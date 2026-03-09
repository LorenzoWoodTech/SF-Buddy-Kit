//
//  IconCard.swift
//  SFBuddyKit
//
//  SF Symbol card with native platform gestures and optimized performance
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
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
    @State private var pressStartedOnIndicator = false
    @State private var isOptionKeyPressed = false
    @State private var hoveredIndicatorIndex: Int?
    
    // Gesture state
    @State private var swipeOffset: CGFloat = 0
    @State private var lastScrollTime: Date = .distantPast
    @State private var accumulatedDelta: CGFloat = 0
    
    #if os(iOS)
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    #endif
    
    private var hasVariants: Bool {
        !availableVariants.isEmpty
    }
    
    private var displayVariant: SymbolVariant {
        let baseVariant = hasVariants && currentVariantIndex < availableVariants.count 
            ? availableVariants[currentVariantIndex] 
            : SymbolVariant.base(symbolName)
        
        if isOptionKeyPressed {
            let fillSymbolName = baseVariant.symbolName.hasSuffix(".fill") 
                ? baseVariant.symbolName 
                : baseVariant.symbolName + ".fill"
            
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
            // Variant indicators
            if hasVariants {
                variantIndicators
            } else {
                Spacer()
                    .frame(height: 20)
            }
            
            GeometryReader { geometry in
                ZStack {
                    cardContent(availableSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        #if os(macOS)
                        .offset(x: swipeOffset)
                        .background(
                            ScrollWheelGestureView(
                                isEnabled: hasVariants && isHovered,
                                onScroll: { deltaX in
                                    handleScrollWheel(deltaX: deltaX)
                                }
                            )
                        )
                        #else
                        .offset(x: isDragging ? dragOffset : 0)
                        .gesture(
                            hasVariants ? 
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    if !isDragging {
                                        isDragging = true
                                    }
                                    dragOffset = value.translation.width * 0.3
                                }
                                .onEnded { value in
                                    handleSwipeEnd(translation: value.translation.width)
                                    withAnimation(.spring(duration: 0.3)) {
                                        dragOffset = 0
                                        isDragging = false
                                    }
                                }
                            : nil
                        )
                        #endif
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { _ in
                                    #if os(iOS)
                                    if !isDragging {
                                        handleMainAction()
                                    }
                                    #else
                                    handleMainAction()
                                    #endif
                                }
                        )
                    
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
                        accumulatedDelta = 0
                    }
                }
                #endif
            }
            .aspectRatio(1.0, contentMode: .fit)
            .drawingGroup()
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
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
        .onChange(of: currentVariantIndex) { oldValue, newValue in
            print("🔄 Variant index changed: \(oldValue) → \(newValue) | Symbol: \(currentVariant.symbolName)")
            onVariantChange(currentVariant.symbolName)
        }
        .onChange(of: isOptionKeyPressed) { _, _ in
            onVariantChange(displayVariant.symbolName)
        }
    }
    
    // MARK: - macOS Scroll Handling
    
    #if os(macOS)
    private func handleScrollWheel(deltaX: CGFloat) {
        let now = Date()
        let timeSinceLastScroll = now.timeIntervalSince(lastScrollTime)
        
        // Reset accumulation if too much time has passed
        if timeSinceLastScroll > 0.3 {
            accumulatedDelta = 0
        }
        
        lastScrollTime = now
        accumulatedDelta += deltaX
        
        print("📊 Scroll deltaX: \(deltaX), accumulated: \(accumulatedDelta)")
        
        // Visual feedback
        withAnimation(.interpolatingSpring(duration: 0.2)) {
            swipeOffset = accumulatedDelta * 0.3
        }
        
        // Threshold for triggering variant change
        let threshold: CGFloat = 20
        
        if abs(accumulatedDelta) >= threshold {
            print("🎯 Threshold reached! Cycling variant...")
            
            if accumulatedDelta < 0 {
                // Scroll left = next variant
                cycleVariant(direction: .next)
            } else {
                // Scroll right = previous variant
                cycleVariant(direction: .previous)
            }
            
            // Reset accumulation
            accumulatedDelta = 0
            
            // Reset visual offset
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(duration: 0.3)) {
                    swipeOffset = 0
                }
            }
        }
    }
    #endif
    
    // MARK: - iOS Swipe Handling
    
    #if os(iOS)
    private func handleSwipeEnd(translation: CGFloat) {
        guard hasVariants else { return }
        
        let threshold: CGFloat = 30
        
        if abs(translation) > threshold {
            if translation > 0 {
                cycleVariant(direction: .previous)
            } else {
                cycleVariant(direction: .next)
            }
            triggerHapticFeedback()
        }
    }
    #endif
    
    private func cycleVariant(direction: VariantDirection) {
        let oldIndex = currentVariantIndex
        
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
            switch direction {
            case .next:
                currentVariantIndex = (currentVariantIndex + 1) % availableVariants.count
            case .previous:
                currentVariantIndex = (currentVariantIndex - 1 + availableVariants.count) % availableVariants.count
            }
        }
        
        print("🔄 Cycled variant: \(oldIndex) → \(currentVariantIndex) (\(direction))")
        triggerHapticFeedback()
    }
    
    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    
    private enum VariantDirection {
        case next, previous
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
        // Cleanup handled automatically
    }
    #endif
    
    // MARK: - Variant Indicators
    @ViewBuilder
    private var variantIndicators: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                // Find all non-base variants with their ACTUAL indices
                ForEach(Array(availableVariants.enumerated()), id: \.element.id) { actualIndex, variant in
                    if variant.variantType != .base, let badgeIcon = variant.badgeIcon {
                        let shouldHighlight: Bool = {
                            if variant.variantType == .fill {
                                return isShowingFill
                            } else if variant.variantType == .badge {
                                return currentVariant.symbolName == variant.symbolName
                            } else {
                                let currentBaseName = currentVariant.symbolName.replacingOccurrences(of: ".fill", with: "")
                                let variantBaseName = variant.symbolName.replacingOccurrences(of: ".fill", with: "")
                                return currentBaseName == variantBaseName
                            }
                        }()
                        
                        VariantIndicatorButton(
                            icon: badgeIcon,
                            isActive: shouldHighlight,
                            isHovered: hoveredIndicatorIndex == actualIndex,
                            size: indicatorSize,
                            onTap: {
                                print("🎯 Tapped indicator at index \(actualIndex), variant: \(variant.symbolName)")
                                withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                                    if actualIndex == currentVariantIndex {
                                        // Toggle back to base
                                        currentVariantIndex = 0
                                    } else {
                                        // Switch to this variant
                                        currentVariantIndex = actualIndex
                                    }
                                }
                                triggerHapticFeedback()
                            },
                            onHoverChange: { hovering in
                                hoveredIndicatorIndex = hovering ? actualIndex : nil
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

// MARK: - Scroll Wheel Gesture View (macOS)

#if os(macOS)
private struct ScrollWheelGestureView: NSViewRepresentable {
    let isEnabled: Bool
    let onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelCaptureView()
        view.onScroll = onScroll
        view.isEnabled = isEnabled
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ScrollWheelCaptureView {
            view.isEnabled = isEnabled
        }
    }
    
    class ScrollWheelCaptureView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        var isEnabled: Bool = false
        
        override func scrollWheel(with event: NSEvent) {
            guard isEnabled else {
                super.scrollWheel(with: event)
                return
            }
            
            let deltaX = event.scrollingDeltaX
            
            // Only handle horizontal scrolling
            guard abs(deltaX) > abs(event.scrollingDeltaY) else {
                super.scrollWheel(with: event)
                return
            }
            
            // Require minimum threshold
            guard abs(deltaX) > 2 else {
                super.scrollWheel(with: event)
                return
            }
            
            print("🖱️ ScrollWheel event: deltaX=\(deltaX), deltaY=\(event.scrollingDeltaY)")
            
            onScroll?(deltaX)
            
            // Don't call super - consume the event
        }
    }
}
#endif

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
            .animation(.spring(duration: 0.2), value: isActive)
    }
}

#Preview {
    VStack(spacing: 20) {
        #if os(macOS)
        Text("Hover and use trackpad swipe (two-finger horizontal scroll) to cycle variants")
            .font(.caption)
            .foregroundStyle(.secondary)
        #else
        Text("Swipe left/right on cards to cycle variants")
            .font(.caption)
            .foregroundStyle(.secondary)
        #endif
        
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