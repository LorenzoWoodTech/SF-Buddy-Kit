//
//  SymbolPickerView.swift
//  SF Buddy
//
//  Unified symbol picker combining browsing and AI search
//

import SwiftUI
import SFSafeSymbols
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Liquid Glass Effect Extension
private extension View {
    @ViewBuilder
    func liquidGlassEffect() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    func liquidGlassEffect(in shape: some Shape) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

public struct SymbolPickerView: View {
    @Binding var selectedSymbol: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var symbolService = SFSymbolService.shared
    @Environment(VegasSettings.self) private var appSettings
    
    @State private var searchText = ""
    @State private var selectedCategory: SFSymbolCategory = .all
    @State private var selectedColor: Color = .primary
    @State private var showingCategoryFilter = false
    @State private var vegasMode = false
    @State private var gridScale: Double = 0.5 // 0 = smallest (8 cols), 1 = largest (1 col)
    @State private var justCopiedSymbolName: String?
    @State private var hoveredSymbolName: String?
    @State private var showTitles = false
    @State private var debouncedFilteredSymbols: [String] = []
    @State private var filterTask: Task<Void, Never>?
    @State private var showingSettings = false
    @State private var showingInlineConfig = false
    @State private var groupVariants = false
    
    private let showDismissButton: Bool
    private let mode: PickerMode
    
    // Control height constant
    private let controlHeight: CGFloat = 20
    
    public enum PickerMode {
        case browser // Select and dismiss
        case picker  // Copy to clipboard
    }
    
    public init(
        selectedSymbol: Binding<String?> = .constant(nil),
        showDismissButton: Bool = true,
        mode: PickerMode = .picker
    ) {
        self._selectedSymbol = selectedSymbol
        self.showDismissButton = showDismissButton
        self.mode = mode
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar with categories (icon-only)
            List(SFSymbolCategory.allCases, id: \.rawValue, selection: $selectedCategory) { category in
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .tag(category)
                    .help(category.displayName)
            }
            .listStyle(.sidebar)
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 50, ideal: 50, max: 50)
            #endif
            .safeAreaPadding(.vertical, 8)
        } detail: {
            // Main content area - ScrollView with floating toolbar
            symbolGridView
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        searchBar
                        controlBar
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let displayName = hoveredSymbolName ?? justCopiedSymbolName {
                        HStack {
                            Spacer()
                            Text(displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 16))
                            Spacer()
                        }
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .navigationTitle("SF Symbols")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar(removing: .sidebarToggle)
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)
            
            TextField("Enter to generate suggestions...", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    if !searchText.isEmpty {
                        Task {
                            await symbolService.processText(searchText)
                        }
                    }
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 400)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .onChange(of: searchText) { _, newValue in
            filterTask?.cancel()
            filterTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                if !Task.isCancelled {
                    await updateFilteredSymbols()
                }
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            filterTask?.cancel()
            filterTask = Task {
                await updateFilteredSymbols()
            }
        }
        .onAppear {
            Task {
                await updateFilteredSymbols()
            }
        }
    }
    
    // MARK: - Computed Column Count
    private var columnCount: Int {
        // Map slider 0.0-1.0 to 8-1 columns (inverted: small icons = more columns)
        let maxColumns = 8
        let minColumns = 1
        return max(minColumns, maxColumns - Int(round(gridScale * Double(maxColumns - minColumns))))
    }
    
    // Computed top padding based on actual toolbar height
    private var topPadding: CGFloat {
        // Base height calculation: search bar + control bar
        // Search bar: ~52pt, Control bar: ~52pt, plus some buffer
        return 116
    }
    
    // MARK: - Control Bar
    private var controlBar: some View {
        HStack(spacing: 12) {
            // Rendering Mode + Color Palette in one glass island
            HStack(spacing: 8) {
                // Rendering Mode Menu
                Menu {
                    ForEach(SymbolRenderingMode.allCases) { mode in
                        Button {
                            symbolService.currentRenderingMode = mode
                            if mode == .vegas {
                                vegasMode = true
                            } else {
                                vegasMode = false
                            }
                        } label: {
                            HStack {
                                if symbolService.currentRenderingMode == mode {
                                    Image(systemName: "checkmark")
                                }
                                Label(mode.displayName, systemImage: mode.iconName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Text(symbolService.currentRenderingMode.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: controlHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Color Palette (only visible for modes that support color customization)
                if symbolService.currentRenderingMode.supportsColorCustomization {
                    Divider()
                        .frame(height: 16)
                    
                    Menu {
                        Section("Color") {
                            ControlGroup {
                                ForEach(colorPaletteFirstRow, id: \.0) { colorName, color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        Label(colorName, systemImage: selectedColor == color ? "circle.fill" : "circle")
                                    }
                                    .tint(color)
                                }
                            }
                            .controlGroupStyle(.palette)
                            
                            ControlGroup {
                                ForEach(colorPaletteSecondRow, id: \.0) { colorName, color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        Label(colorName, systemImage: selectedColor == color ? "circle.fill" : "circle")
                                    }
                                    .tint(color)
                                }
                            }
                            .controlGroupStyle(.palette)
                        }
                    } label: {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 16))
            
            Spacer()
            
            // Show Titles Toggle (now a menu)
            Menu {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showTitles.toggle()
                    }
                } label: {
                    HStack {
                        if showTitles {
                            Image(systemName: "checkmark")
                        }
                        Text("Show Names Below Icons")
                    }
                }
                
                Section("Beta Features") {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            groupVariants.toggle()
                        }
                    } label: {
                        HStack {
                            if groupVariants {
                                Image(systemName: "checkmark")
                            }
                            Text("Group Icon Variants")
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat")
                    .font(.body)
                    .foregroundStyle(showTitles ? Color.accentColor : .secondary)
                    .frame(height: controlHeight)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 16))
            .help("Display options")
            
            // Grid size slider with icons
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Slider(value: $gridScale, in: 0...1)
                    .frame(width: 120)
                
                Image(systemName: "square.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: controlHeight)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.3), value: symbolService.currentRenderingMode.supportsColorCustomization)
    }
    
    // MARK: - Color Palette Data
    private var colorPaletteFirstRow: [(String, Color)] {
        [
            ("Red", .red),
            ("Orange", .orange),
            ("Yellow", .yellow),
            ("Green", .green),
            ("Mint", .mint),
            ("Teal", .teal),
            ("Cyan", .cyan),
            ("Blue", .blue)
        ]
    }
    
    private var colorPaletteSecondRow: [(String, Color)] {
        [
            ("Indigo", .indigo),
            ("Purple", .purple),
            ("Pink", .pink),
            ("Brown", .brown),
            ("Gray", .gray),
            ("Primary", .primary),
            ("Secondary", .secondary)
        ]
    }
    
    // MARK: - Symbol Grid View
    private var symbolGridView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Configuration error view
                if symbolService.currentError != .none && !symbolService.isProcessing && aiSuggestedSymbols.isEmpty && !searchText.isEmpty {
                    configurationErrorView
                }
                
                // AI Suggestions Section
                if !aiSuggestedSymbols.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("AI Suggestions", systemImage: "sparkles")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            if symbolService.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            
                            Button("Clear") {
                                symbolService.suggestedSymbols = []
                                symbolService.invalidSymbolNamesFromClaude = []
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 10),
                                count: columnCount
                            ),
                            spacing: 16
                        ) {
                            ForEach(aiSuggestedSymbols) { suggestion in
                                IconCard(
                                    symbolName: suggestion.name,
                                    isSelected: selectedSymbol == suggestion.name,
                                    symbolColor: .purple,
                                    vegasMode: vegasMode,
                                    gridScale: gridScale,
                                    renderingMode: symbolService.currentRenderingMode,
                                    showTitle: showTitles,
                                    availableVariants: groupVariants ? getAvailableVariants(for: suggestion.name) : [],
                                    onHover: { isHovering in
                                        hoveredSymbolName = isHovering ? suggestion.name : nil
                                    },
                                    onVariantChange: { variant in
                                        hoveredSymbolName = variant
                                    }
                                ) {
                                    handleSymbolTap(suggestion.name)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        
                        if !symbolService.invalidSymbolNamesFromClaude.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("AI suggested \(symbolService.invalidSymbolNamesFromClaude.count) invalid symbol(s):")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                 }
                                Text(symbolService.invalidSymbolNamesFromClaude.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
                
                // All/Filtered Symbols Section
                if !debouncedFilteredSymbols.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !aiSuggestedSymbols.isEmpty {
                            HStack {
                                Label("All Symbols", systemImage: "square.grid.3x3")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(debouncedFilteredSymbols.count) symbols")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 10),
                                count: columnCount
                            ),
                            spacing: 20
                        ) {
                            ForEach(debouncedFilteredSymbols, id: \.self) { symbolName in
                                IconCard(
                                    symbolName: symbolName,
                                    isSelected: selectedSymbol == symbolName,
                                    symbolColor: selectedColor,
                                    vegasMode: vegasMode,
                                    gridScale: gridScale,
                                    renderingMode: symbolService.currentRenderingMode,
                                    showTitle: showTitles,
                                    availableVariants: groupVariants ? getAvailableVariants(for: symbolName) : [],
                                    onHover: { isHovering in
                                        hoveredSymbolName = isHovering ? symbolName : nil
                                    },
                                    onVariantChange: { variant in
                                        hoveredSymbolName = variant
                                    }
                                ) {
                                    handleSymbolTap(symbolName)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else if searchText.isEmpty && aiSuggestedSymbols.isEmpty {
                    emptyStateView
                } else if !symbolService.isProcessing {
                    noResultsView
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .modifier(VegasSymbolEffects(isActive: vegasMode))
            
            VStack(spacing: 8) {
                Text("Search for Symbols")
                    .font(.headline)
                Text("Type to filter locally, press Enter for AI suggestions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(["home", "settings", "heart", "weather"], id: \.self) { example in
                    Button {
                        searchText = example
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.caption2)
                            Text(example)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 60)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No symbols found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Try different search terms or press Enter for AI suggestions")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Clear Search") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
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
        .padding(.top, 80)
    }
    
    private var configurationErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: symbolService.currentError.icon)
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: symbolService.currentError)
            
            VStack(spacing: 12) {
                Text(symbolService.currentError.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(symbolService.currentError.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button {
                    showingInlineConfig = true
                } label: {
                    Label("Configure AI", systemImage: "gearshape")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Quick actions based on error type
                if symbolService.currentError == .claudeAPIKeyMissing {
                    Link(destination: URL(string: "https://console.anthropic.com/account/keys")!) {
                        Label("Get Claude API Key", systemImage: "link")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if case .appleIntelligenceUnavailable = symbolService.currentError {
                    Button {
                        SFSymbolPackageSettings.shared.modelProvider = .claude
                        showingInlineConfig = true
                    } label: {
                        Label("Switch to Claude API", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Browse Symbols Manually") {
                    searchText = ""
                    symbolService.currentError = .none
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .sheet(isPresented: $showingInlineConfig) {
            AIConfigurationView()
        }
    }
    
    // MARK: - Symbol Handling
    private func handleSymbolTap(_ symbolName: String) {
        // Use the currently selected variant from hoveredSymbolName
        let actualSymbolName = hoveredSymbolName ?? symbolName
        
        switch mode {
        case .browser:
            selectedSymbol = actualSymbolName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dismiss()
            }
            
        case .picker:
            // Copy the actual variant to clipboard
            symbolService.replaceTextWithSymbol(actualSymbolName)
            withAnimation {
                justCopiedSymbolName = actualSymbolName
            }
            
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    withAnimation {
                        if justCopiedSymbolName == actualSymbolName {
                            justCopiedSymbolName = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var aiSuggestedSymbols: [SFSymbolSuggestion] {
        symbolService.suggestedSymbols
    }
    
    private var totalSymbolCount: Int {
        aiSuggestedSymbols.count + debouncedFilteredSymbols.count
    }
    
    // MARK: - Async Filtering
    @MainActor
    private func updateFilteredSymbols() async {
        let allSymbols = SFSymbol.allSymbols.map { $0.rawValue }
        var symbols = allSymbols
        
        // Filter out variants from main list only if grouping is enabled
        if groupVariants {
            symbols = symbols.filter { symbolName in
                !symbolName.hasSuffix(".fill") && 
                !symbolName.contains(".badge") && 
                !symbolName.hasSuffix(".slash") &&
                !symbolName.hasSuffix(".circle") &&
                !symbolName.hasSuffix(".circle.fill")
            }
        }

        // Filter out fill and badge variants from main list
        symbols = symbols.filter { symbolName in
            !symbolName.hasSuffix(".fill") && !symbolName.contains(".badge")
        }
        
        if selectedCategory != .all {
            symbols = symbols.filter { symbolName in
                symbolBelongsToCategory(symbolName, category: selectedCategory)
            }
        }
        
        if !searchText.isEmpty {
            symbols = symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        let maxResults = searchText.isEmpty ? 400 : 800
        let limitedSymbols = Array(symbols.prefix(maxResults))
        
        // Smart sorting by relevance when searching, otherwise by dot count and alphabetically
        if !searchText.isEmpty {
            let sorted = limitedSymbols.sorted { symbol1, symbol2 in
                let score1 = symbolRelevanceScore(symbol1, searchTerm: searchText)
                let score2 = symbolRelevanceScore(symbol2, searchTerm: searchText)
                return score1 > score2
            }
            debouncedFilteredSymbols = sorted
        } else {
            // Sort by dot count first, then alphabetically
            let sorted = limitedSymbols.sorted { symbol1, symbol2 in
                let dots1 = symbol1.filter { $0 == "." }.count
                let dots2 = symbol2.filter { $0 == "." }.count
                
                if dots1 != dots2 {
                    return dots1 < dots2
                } else {
                    return symbol1.localizedStandardCompare(symbol2) == .orderedAscending
                }
            }
            debouncedFilteredSymbols = sorted
        }
    }
    
    // MARK: - Variant Detection
    private func getAvailableVariants(for symbolName: String) -> [SymbolVariant] {
        var variants: [SymbolVariant] = []
        let allSymbols = SFSymbol.allSymbols.map { $0.rawValue }
        
        // Always include base variant first
        variants.append(.base(symbolName))
        
        // Check for fill variant of base (must be exactly symbolName.fill)
        if hasFillVariant(symbolName) {
            variants.append(.fill(symbolName))
        }
        
        // Check for slash variant (must be exactly symbolName.slash or symbolName.slash.fill)
        let slashVariant = symbolName + ".slash"
        if allSymbols.contains(slashVariant) {
            variants.append(.slash(symbolName))
            
            // Also check for slash.fill
            let slashFillVariant = slashVariant + ".fill"
            if allSymbols.contains(slashFillVariant) {
                variants.append(SymbolVariant(
                    symbolName: slashFillVariant,
                    displayName: "Slash Fill",
                    badgeIcon: "slash.circle.fill",
                    isBase: false,
                    variantType: .slash
                ))
            }
        }
        
        // Check for circle and circle.fill variants (must be exactly symbolName.circle or symbolName.circle.fill)
        let circleVariant = symbolName + ".circle"
        let circleFillVariant = symbolName + ".circle.fill"
        
        if allSymbols.contains(circleVariant) {
            variants.append(.circle(symbolName))
        }
        
        if allSymbols.contains(circleFillVariant) {
            variants.append(.circleFill(symbolName))
        }
        
        // Track badge variants we've already added (without .fill suffix)
        var addedBadgeBase: Set<String> = []
        
        // Check for badge variants - must come immediately after base symbol
        // Valid: symbolName.badge, symbolName.badge.plus, symbolName.badge.checkmark, etc.
        // Invalid: symbolName.window.badge (that's a variant of symbolName.window)
        for symbol in allSymbols {
            // Must start with base symbol + .badge or base symbol + .trianglebadge
            let badgePattern = symbolName + ".badge"
            let triangleBadgePattern = symbolName + ".trianglebadge"
            
            let isBadgeVariant = symbol.hasPrefix(badgePattern) && 
                                 (symbol.count == badgePattern.count || 
                                  symbol[symbol.index(symbol.startIndex, offsetBy: badgePattern.count)] == ".")
            
            let isTriangleBadgeVariant = symbol.hasPrefix(triangleBadgePattern) && 
                                        (symbol.count == triangleBadgePattern.count || 
                                         symbol[symbol.index(symbol.startIndex, offsetBy: triangleBadgePattern.count)] == ".")
            
            if isBadgeVariant || isTriangleBadgeVariant {
                // Get the base badge name (without .fill)
                let baseBadgeName = symbol.replacingOccurrences(of: ".fill", with: "")
                
                // Only add each badge variant once (prefer non-fill version for the indicator)
                if !addedBadgeBase.contains(baseBadgeName) {
                    variants.append(.badge(baseBadgeName, baseSymbolName: symbolName))
                    addedBadgeBase.insert(baseBadgeName)
                    
                    // Also check if this badge has a fill variant
                    let fillBadgeName = baseBadgeName + ".fill"
                    if allSymbols.contains(fillBadgeName) {
                        // Add the fill version as a separate entry so Option key can find it
                        variants.append(.badge(fillBadgeName, baseSymbolName: symbolName))
                    }
                }
            }
        }
        
        // Return empty array if only base variant exists
        return variants.count > 1 ? variants : []
    }
    
    // MARK: - Fill Variant Detection
    private func hasFillVariant(_ symbolName: String) -> Bool {
        // Don't show fill indicator if the symbol already contains "fill"
        guard !symbolName.contains("fill") else { return false }
        
        // Also skip if symbol already ends in .circle or .slash (those have their own fill handling)
        if symbolName.hasSuffix(".circle") || symbolName.hasSuffix(".slash") {
            return false
        }
        
        // Check if a .fill variant exists for this symbol (must be exactly symbolName.fill)
        let fillVariant = symbolName + ".fill"
        let exists = SFSymbol.allSymbols.contains { $0.rawValue == fillVariant }
        
        return exists
    }
    
    private func getFillVariant(_ symbolName: String) -> String? {
        let fillVariant = symbolName + ".fill"
        return hasFillVariant(symbolName) ? fillVariant : nil
    }
    
    // MARK: - Relevance Scoring
    private func symbolRelevanceScore(_ symbol: String, searchTerm: String) -> Int {
        var score = 0
        let lower = symbol.lowercased()
        let search = searchTerm.lowercased()
        
        // Exact match: highest priority
        if lower == search {
            score += 10000
        }
        // Starts with search term
        else if lower.hasPrefix(search) {
            score += 5000
        }
        // Base symbol name matches (before first dot)
        else if let baseSymbol = symbol.split(separator: ".").first,
                baseSymbol.lowercased() == search {
            score += 3000
        }
        // Base symbol starts with search
        else if let baseSymbol = symbol.split(separator: ".").first,
                baseSymbol.lowercased().hasPrefix(search) {
            score += 1000
        }
        // Contains search term
        else if lower.contains(search) {
            score += 500
        }
        
        // Bonus for common/popular base symbols
        if let baseSymbol = symbol.split(separator: ".").first {
            let popularSymbols: Set<String> = [
                "house", "gear", "person", "heart", "star", "plus", "minus",
                "magnifyingglass", "checkmark", "xmark", "trash", "pencil",
                "folder", "bell", "envelope", "phone", "message", "camera",
                "arrow", "square", "circle", "text", "doc", "photo", "video"
            ]
            if popularSymbols.contains(String(baseSymbol).lowercased()) {
                score += 100
            }
        }
        
        // Prefer simpler symbols (fewer modifiers)
        let dots = symbol.filter { $0 == "." }.count
        score -= dots * 50
        
        // Prefer shorter names
        score -= symbol.count
        
        return score
    }
    
    // MARK: - Category Matching
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

// MARK: - SF Symbol Categories
enum SFSymbolCategory: String, CaseIterable {
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
    
    var displayName: String {
        rawValue
    }
    
    var systemImage: String {
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

#Preview("Picker Mode - Copies to Clipboard") {
    SymbolPickerView(mode: .picker)
        .environment(VegasSettings.shared)
}

#Preview("Popover Presentation") {
    struct PopoverDemo: View {
        @State private var showingPicker = false
        @State private var selectedSymbol: String?
        
        var body: some View {
            VStack(spacing: 20) {
                if let symbol = selectedSymbol {
                    Text("Selected: \(symbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showingPicker.toggle()
                } label: {
                    HStack {
                        Image(systemName: selectedSymbol ?? "square.grid.3x3")
                        Text(selectedSymbol ?? "Pick a Symbol")
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingPicker) {
                    SymbolPickerView(selectedSymbol: $selectedSymbol, mode: .browser)
                        .frame(width: 800, height: 600)
                        .environment(VegasSettings.shared)
                }
            }
        }
    }
    
    return PopoverDemo()
}