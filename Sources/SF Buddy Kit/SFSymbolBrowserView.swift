//
//  SFSymbolBrowserView.swift
//  SF Buddy
//
//  Enhanced symbol browser with ALL advanced features from SymbolPickerView
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SFSafeSymbols

public struct SFSymbolBrowserView: View {
    @Binding var selectedSymbol: String?
    @Environment(\.dismiss) private var dismiss
    
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    @State private var searchText = ""
    @State private var selectedCategory: SFSymbolCategory = .all
    @State private var selectedColor: Color = .primary
    @State private var selectedRenderingMode: BrowserRenderingMode = .hierarchical
    @State private var showingStylePopover = false
    @State private var showingColorPopover = false
    @State private var showingGridSizePopover = false
    @State private var showingVegasSettingsPopover = false
    @State private var showingCategoryFilter = false
    @State private var vegasMode = false
    @State private var gridSize: BrowserGridSize = .medium
    
    public init(selectedSymbol: Binding<String?>) {
        self._selectedSymbol = selectedSymbol
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Control Bar with ALL features from SymbolPickerView
                controlBar
                
                // Category Filter Bar (collapsible with smooth animation)
                if showingCategoryFilter {
                    categoryFilterBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Symbol Grid with enhanced empty state and performance optimization
                symbolGridView
            }
            .navigationTitle("SF Symbols")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search symbols...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // Category toggle button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingCategoryFilter.toggle()
                            }
                        } label: {
                            Image(systemName: showingCategoryFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .foregroundColor(.accentColor)
                        }
                        .help("Toggle Categories")
                        
                        // Info button showing symbol count
                        Button {
                            // Could show detailed info about current filter/search
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("\(filteredSymbols.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }
                        .help("Symbol count: \(filteredSymbols.count)")
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Control Bar (ALL features from SymbolPickerView)
    private var controlBar: some View {
        HStack(spacing: 12) {
            Spacer()
            
            // Grid Size Control with enhanced styling
            Button {
                showingGridSizePopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: gridSize.iconName)
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
                BrowserGridSizePopover(selectedGridSize: $gridSize)
            }
            
            // Rendering Mode Control with enhanced styling
            Button {
                showingStylePopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedRenderingMode.iconName)
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
                BrowserRenderingModePopover(selectedRenderingMode: $selectedRenderingMode)
            }
            
            // Color Control with enhanced styling
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
                BrowserColorPickerPopover(selectedColor: $selectedColor)
            }
            
            // Vegas Mode Control with ALL features from SymbolPickerView
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
                    .background(vegasMode ? Color.yellow.opacity(0.2) : Color.clear,
                               in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Vegas Settings") {
                    showingVegasSettingsPopover.toggle()
                }
                
                Divider()
                
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
                BrowserVegasSettingsPopover()
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Category Filter Bar (Enhanced from SymbolPickerView concept)
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SFSymbolCategory.allCases, id: \.rawValue) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemImage)
                                .font(.caption2)
                            Text(category.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedCategory == category ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Symbol Grid View with Enhanced Empty State and Performance
    private var symbolGridView: some View {
        ScrollView {
            if !filteredSymbols.isEmpty {
                let columns: [GridItem] = Array(
                    repeating: GridItem(
                        .flexible(
                            minimum: gridSize.buttonSize.min,
                            maximum: gridSize.buttonSize.max
                        ),
                        spacing: 10
                    ),
                    count: gridSize.columnCount
                )
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredSymbols, id: \.self) { symbolName in
                        BrowserSymbolGridButton(
                            symbolName: symbolName,
                            isSelected: selectedSymbol == symbolName,
                            symbolColor: selectedColor,
                            vegasMode: vegasMode,
                            gridSize: gridSize,
                            renderingMode: selectedRenderingMode
                        ) {
                            selectedSymbol = symbolName
                            
                            #if os(iOS)
                            // Haptic feedback on iOS for immediate selection feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            #endif
                            
                            // Auto-dismiss after selection with slight delay for visual feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Enhanced empty state with context-aware messaging
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "square.grid.3x2" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text(searchText.isEmpty ? "No symbols to display" : "No symbols found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if !searchText.isEmpty {
                            Text("Try different search terms or clear filters")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        } else if selectedCategory != .all {
                            Text("This category appears to be empty")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Quick action buttons for empty state
                    if !searchText.isEmpty || selectedCategory != .all {
                        HStack(spacing: 12) {
                            if !searchText.isEmpty {
                                Button("Clear Search") {
                                    searchText = ""
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            if selectedCategory != .all {
                                Button("Show All") {
                                    withAnimation {
                                        selectedCategory = .all
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Enhanced Filtered Symbols with Category Support
    private var filteredSymbols: [String] {
        // Get all SF Symbols using SFSafeSymbols
        let allSymbols = Array(SFSymbol.allSymbols).map { $0.rawValue }
        var symbols = allSymbols
        
        // Apply category filter with enhanced categorization
        if selectedCategory != .all {
            symbols = symbols.filter { symbolName in
                return symbolBelongsToCategory(symbolName, category: selectedCategory)
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            symbols = symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Performance-optimized result limits
        let maxResults = searchText.isEmpty ? 400 : 800
        return Array(symbols.prefix(maxResults))
    }
    
    // MARK: - Enhanced Category Matching
    private func symbolBelongsToCategory(_ symbolName: String, category: SFSymbolCategory) -> Bool {
        switch category {
        case .all:
            return true
        case .communication:
            return symbolName.contains("message") || symbolName.contains("phone") ||
                   symbolName.contains("mail") || symbolName.contains("bubble") ||
                   symbolName.contains("text") || symbolName.contains("chat")
        case .weather:
            return symbolName.contains("cloud") || symbolName.contains("sun") ||
                   symbolName.contains("rain") || symbolName.contains("snow") ||
                   symbolName.contains("wind") || symbolName.contains("moon")
        case .objectsTools:
            return symbolName.contains("wrench") || symbolName.contains("hammer") ||
                   symbolName.contains("screwdriver") || symbolName.contains("gear") ||
                   symbolName.contains("tool")
        case .devices:
            return symbolName.contains("iphone") || symbolName.contains("ipad") ||
                   symbolName.contains("mac") || symbolName.contains("laptop") ||
                   symbolName.contains("display") || symbolName.contains("tv")
        case .gaming:
            return symbolName.contains("gamecontroller") || symbolName.contains("dice") ||
                   symbolName.contains("joystick")
        case .connectivity:
            return symbolName.contains("wifi") || symbolName.contains("bluetooth") ||
                   symbolName.contains("antenna") || symbolName.contains("network")
        case .transportation:
            return symbolName.contains("car") || symbolName.contains("bus") ||
                   symbolName.contains("airplane") || symbolName.contains("bicycle") ||
                   symbolName.contains("train") || symbolName.contains("boat")
        case .automotive:
            return symbolName.contains("car") && !symbolName.contains("card")
        case .accessibility:
            return symbolName.contains("accessibility") || symbolName.contains("ear") ||
                   symbolName.contains("eye")
        case .privacy:
            return symbolName.contains("lock") || symbolName.contains("key") ||
                   symbolName.contains("shield") || symbolName.contains("security")
        case .human:
            return symbolName.contains("person") || symbolName.contains("figure") ||
                   symbolName.contains("hand") || symbolName.contains("face")
        case .home:
            return symbolName.contains("house") || symbolName.contains("home") ||
                   symbolName.contains("door") || symbolName.contains("bed")
        case .fitness:
            return (symbolName.contains("figure") && (symbolName.contains("run") ||
                   symbolName.contains("walk") || symbolName.contains("bike"))) ||
                   symbolName.contains("dumbbell")
        case .nature:
            return symbolName.contains("leaf") || symbolName.contains("tree") ||
                   symbolName.contains("flower") || symbolName.contains("mountain") ||
                   symbolName.contains("water")
        case .editing:
            return symbolName.contains("pencil") || symbolName.contains("paintbrush") ||
                   symbolName.contains("crop") || symbolName.contains("scissors")
        case .textFormatting:
            return symbolName.contains("textformat") || symbolName.contains("bold") ||
                   symbolName.contains("italic") || symbolName.contains("underline")
        case .media:
            return symbolName.contains("play") || symbolName.contains("pause") ||
                   symbolName.contains("stop") || symbolName.contains("music") ||
                   symbolName.contains("video") || symbolName.contains("camera")
        case .keyboard:
            return symbolName.contains("keyboard") || symbolName.contains("command") ||
                   symbolName.contains("option") || symbolName.contains("shift")
        case .commerce:
            return symbolName.contains("cart") || symbolName.contains("bag") ||
                   symbolName.contains("creditcard") || symbolName.contains("dollar") ||
                   symbolName.contains("purchase")
        case .time:
            return symbolName.contains("clock") || symbolName.contains("timer") ||
                   symbolName.contains("calendar") || symbolName.contains("alarm")
        case .health:
            return symbolName.contains("heart") || symbolName.contains("cross") ||
                   symbolName.contains("pill") || symbolName.contains("medical")
        case .shapes:
            return (symbolName.contains("circle") || symbolName.contains("square") ||
                   symbolName.contains("triangle") || symbolName.contains("diamond")) &&
                   !symbolName.contains("person") && !symbolName.contains("figure")
        case .arrows:
            return symbolName.contains("arrow") || symbolName.contains("chevron")
        case .indices:
            return symbolName.matches(pattern: "^[a-z]\\.circle") ||
                   symbolName.matches(pattern: "^[0-9]\\.circle")
        case .math:
            return symbolName.contains("plus") || symbolName.contains("minus") ||
                   symbolName.contains("multiply") || symbolName.contains("divide") ||
                   symbolName.contains("equal") || symbolName.contains("percent")
        }
    }
}

// MARK: - Symbol Grid Button with FULL Vegas Mode Support (ALL features from SymbolPickerView)
struct BrowserSymbolGridButton: View {
    let symbolName: String
    let isSelected: Bool
    let symbolColor: Color
    let vegasMode: Bool
    let gridSize: BrowserGridSize
    let renderingMode: BrowserRenderingMode
    let action: () -> Void
    
    @Environment(SFSymbolVegasSettings.self) private var vegasSettings
    @State private var isHovered = false
    @State private var animationOffset: CGFloat = 0
    @State private var animationRotation: Double = 0
    @State private var animationScale: CGFloat = 1
    @State private var randomColor: Color = .primary
    @State private var vegasTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            symbolContent
                .frame(
                    minWidth: gridSize.buttonSize.min,
                    maxWidth: gridSize.buttonSize.max,
                    minHeight: gridSize.buttonSize.height,
                    maxHeight: gridSize.buttonSize.height
                )
                .background(backgroundShape)
                .overlay(overlayShape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0)) {
                isHovered = hovering
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
        .onDisappear {
            stopVegasAnimations()
        }
    }
    
    private var effectiveSymbolColor: Color {
        (isHovered || isSelected) ? .white : (vegasMode ? randomColor : symbolColor)
    }
    
    @ViewBuilder
    private var symbolContent: some View {
        let mode = swiftUIRenderingMode
        VStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: gridSize.symbolSize))
                .foregroundColor(effectiveSymbolColor)
                .symbolRenderingMode(mode)
                .frame(width: gridSize.symbolSize + 12, height: gridSize.symbolSize + 12)
                .scaleEffect(vegasMode ? animationScale : 1)
                .rotationEffect(.degrees(vegasMode ? animationRotation : 0))
                .offset(x: vegasMode ? animationOffset : 0)
            
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
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isHovered || isSelected ? Color.accentColor : Color.clear)
            .opacity(vegasMode ? 0.8 : 1)
    }
    
    private var overlayShape: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.1),
                lineWidth: isSelected ? 2 : 1
            )
    }
    
    private var swiftUIRenderingMode: SymbolRenderingMode {
        switch renderingMode {
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .palette: return .palette
        case .multicolor: return .multicolor
        }
    }
    
    // MARK: - Complete Vegas Animations (EXACTLY like SymbolButton from SymbolPickerView)
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
}

// MARK: - All Supporting Views and Enums (renamed to avoid conflicts)

enum BrowserGridSize: String, CaseIterable, Identifiable {
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
    
    var iconName: String {
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

enum BrowserRenderingMode: String, CaseIterable, Identifiable {
    case monochrome = "monochrome"
    case hierarchical = "hierarchical"
    case palette = "palette"
    case multicolor = "multicolor"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .hierarchical: return "Hierarchical"
        case .palette: return "Palette"
        case .multicolor: return "Multicolor"
        }
    }
    
    var iconName: String {
        switch self {
        case .monochrome: return "circle"
        case .hierarchical: return "circle.lefthalf.striped.horizontal"
        case .palette: return "paintpalette"
        case .multicolor: return "circle.hexagongrid"
        }
    }
}

private struct BrowserGridSizePopover: View {
    @Binding var selectedGridSize: BrowserGridSize
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grid Size")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(BrowserGridSize.allCases) { size in
                    Button {
                        selectedGridSize = size
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: size.iconName)
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
                        .background(selectedGridSize == size ? Color.accentColor.opacity(0.1) : Color.clear,
                                   in: RoundedRectangle(cornerRadius: 4))
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

private struct BrowserRenderingModePopover: View {
    @Binding var selectedRenderingMode: BrowserRenderingMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Render Mode")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(BrowserRenderingMode.allCases) { mode in
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
                        .background(selectedRenderingMode == mode ? Color.accentColor.opacity(0.1) : Color.clear,
                                   in: RoundedRectangle(cornerRadius: 4))
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

private struct BrowserColorPickerPopover: View {
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

// MARK: - Complete Vegas Settings Popover (EXACTLY from SymbolPickerView)
struct BrowserVegasSettingsPopover: View {
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

// MARK: - Enhanced SF Symbol Categories
public enum SFSymbolCategory: String, CaseIterable {
    case all = "All"
    case communication = "Communication"
    case weather = "Weather"
    case objectsTools = "Objects & Tools"
    case devices = "Devices"
    case gaming = "Gaming"
    case connectivity = "Connectivity"
    case transportation = "Transportation"
    case automotive = "Automotive"
    case accessibility = "Accessibility"
    case privacy = "Privacy & Security"
    case human = "Human"
    case home = "Home"
    case fitness = "Fitness"
    case nature = "Nature"
    case editing = "Editing"
    case textFormatting = "Text Formatting"
    case media = "Media"
    case keyboard = "Keyboard"
    case commerce = "Commerce"
    case time = "Time"
    case health = "Health"
    case shapes = "Shapes"
    case arrows = "Arrows"
    case indices = "Indices"
    case math = "Math"
    
    public var displayName: String {
        rawValue
    }
    
    public var systemImage: String {
        switch self {
        case .all: return "square.grid.3x3"
        case .communication: return "bubble.left.and.bubble.right"
        case .weather: return "cloud.sun"
        case .objectsTools: return "wrench.and.screwdriver"
        case .devices: return "laptopcomputer"
        case .gaming: return "gamecontroller"
        case .connectivity: return "wifi"
        case .transportation: return "car"
        case .automotive: return "car.front.waves.up"
        case .accessibility: return "accessibility"
        case .privacy: return "lock.shield"
        case .human: return "person"
        case .home: return "house"
        case .fitness: return "figure.run"
        case .nature: return "leaf"
        case .editing: return "pencil"
        case .textFormatting: return "textformat"
        case .media: return "play.rectangle"
        case .keyboard: return "keyboard"
        case .commerce: return "cart"
        case .time: return "clock"
        case .health: return "heart"
        case .shapes: return "circle.square"
        case .arrows: return "arrow.right"
        case .indices: return "a.circle"
        case .math: return "plus.forwardslash.minus"
        }
    }
}

// MARK: - String Extension for Pattern Matching
extension String {
    func matches(pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

#Preview {
    SFSymbolBrowserView(selectedSymbol: .constant(nil))
        .environment(SFSymbolVegasSettings.shared)
}

