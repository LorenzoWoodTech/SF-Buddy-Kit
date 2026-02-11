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
    @State private var gridSize: SymbolGridSize = .medium
    @State private var justCopiedSymbolName: String?
    @State private var debouncedFilteredSymbols: [String] = []
    @State private var filterTask: Task<Void, Never>?
    @State private var showingSettings = false
    @State private var showingInlineConfig = false
    
    private let showDismissButton: Bool
    private let mode: PickerMode
    
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
        NavigationStack {
            VStack(spacing: 0) {
                controlBar
                
                if showingCategoryFilter {
                    categoryFilterBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                symbolGridView
            }
            .navigationTitle("SF Symbols")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search locally or press Enter for AI suggestions...")
            .onSubmit(of: .search) {
                if !searchText.isEmpty {
                    Task {
                        await symbolService.processText(searchText)
                    }
                }
            }
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
            .toolbar {
                if showDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingCategoryFilter.toggle()
                        }
                    } label: {
                        Image(systemName: showingCategoryFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.accentColor)
                    }
                    .help("Toggle Categories")
                }
            }
        }
    }
    
    // MARK: - Control Bar
    private var controlBar: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Menu {
                ForEach(SymbolGridSize.allCases) { size in
                    Button {
                        gridSize = size
                    } label: {
                        Label(size.displayName, systemImage: size.iconName)
                    }
                }
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
            
            Menu {
                // Rendering Mode Section
                Section("Rendering Mode") {
                    ForEach(SymbolRenderingMode.allCases) { mode in
                        Button {
                            symbolService.currentRenderingMode = mode
                        } label: {
                            HStack {
                                if symbolService.currentRenderingMode == mode {
                                    Image(systemName: "checkmark")
                                }
                                Label(mode.displayName, systemImage: mode.iconName)
                            }
                        }
                    }
                }
                
                // Color Section
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
                
                // Vegas Mode Submenu
                Menu {
                    Button {
                        withAnimation(.bouncy) {
                            vegasMode.toggle()
                        }
                    } label: {
                        HStack {
                            if vegasMode {
                                Image(systemName: "checkmark")
                            }
                            Label("Vegas Mode", systemImage: "sparkles")
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        VegasSettings.shared.triggerVegasChaos()
                    } label: {
                        Label("Trigger Chaos", systemImage: "flame")
                    }
                    .disabled(!vegasMode)
                    
                    Button {
                        VegasSettings.shared.randomizeVegas()
                    } label: {
                        Label("Randomize Settings", systemImage: "dice")
                    }
                    .disabled(!vegasMode)
                } label: {
                    Label("Vegas Mode", systemImage: "sparkles")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                    Text("View")
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
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
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
    
    // MARK: - Category Filter Bar
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
                                repeating: GridItem(
                                    .flexible(minimum: gridSize.buttonSize.min, maximum: gridSize.buttonSize.max),
                                    spacing: 10
                                ),
                                count: gridSize.columnCount
                            ),
                            spacing: 10
                        ) {
                            ForEach(aiSuggestedSymbols) { suggestion in
                                SymbolGridButton(
                                    symbolName: suggestion.name,
                                    isSelected: selectedSymbol == suggestion.name,
                                    symbolColor: .purple,
                                    vegasMode: vegasMode,
                                    gridSize: gridSize,
                                    renderingMode: symbolService.currentRenderingMode,
                                    justCopied: justCopiedSymbolName == suggestion.name
                                ) {
                                    handleSymbolTap(suggestion.name)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
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
                                repeating: GridItem(
                                    .flexible(minimum: gridSize.buttonSize.min, maximum: gridSize.buttonSize.max),
                                    spacing: 10
                                ),
                                count: gridSize.columnCount
                            ),
                            spacing: 10
                        ) {
                            ForEach(debouncedFilteredSymbols, id: \.self) { symbolName in
                                SymbolGridButton(
                                    symbolName: symbolName,
                                    isSelected: selectedSymbol == symbolName,
                                    symbolColor: selectedColor,
                                    vegasMode: vegasMode,
                                    gridSize: gridSize,
                                    renderingMode: symbolService.currentRenderingMode,
                                    justCopied: justCopiedSymbolName == symbolName
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
        switch mode {
        case .browser:
            selectedSymbol = symbolName
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dismiss()
            }
            
        case .picker:
            symbolService.replaceTextWithSymbol(symbolName)
            withAnimation {
                justCopiedSymbolName = symbolName
            }
            
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    withAnimation {
                        if justCopiedSymbolName == symbolName {
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
        
        // Smart sorting by relevance when searching
        if !searchText.isEmpty {
            let sorted = limitedSymbols.sorted { symbol1, symbol2 in
                let score1 = symbolRelevanceScore(symbol1, searchTerm: searchText)
                let score2 = symbolRelevanceScore(symbol2, searchTerm: searchText)
                return score1 > score2
            }
            debouncedFilteredSymbols = sorted
        } else {
            debouncedFilteredSymbols = limitedSymbols
        }
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

#Preview {
    SymbolPickerView(mode: .picker)
        .environment(VegasSettings.shared)
}