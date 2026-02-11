//
//  SharedSymbolComponents.swift
//  SF Buddy
//
//  Shared components for symbol pickers to avoid duplication and naming conflicts
//

import SwiftUI

// MARK: - Grid Size Configuration
enum SymbolGridSize: String, CaseIterable, Identifiable {
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

// MARK: - Symbol Rendering Mode
enum SymbolRenderingStyle: String, CaseIterable, Identifiable {
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
    
    var swiftUIMode: SymbolRenderingMode {
        switch self {
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .palette: return .palette
        case .multicolor: return .multicolor
        }
    }
}

// MARK: - Grid Size Menu
struct SymbolGridSizeMenu: View {
    @Binding var selectedGridSize: SymbolGridSize
    
    var body: some View {
        Menu {
            ForEach(SymbolGridSize.allCases) { size in
                Button {
                    selectedGridSize = size
                } label: {
                    Label(size.displayName, systemImage: size.iconName)
                }
            }
        } label: {
            Image(systemName: selectedGridSize.iconName)
        }
    }
}

// MARK: - Rendering Mode Menu
struct SymbolRenderingModeMenu: View {
    @Binding var selectedRenderingMode: SymbolRenderingStyle
    
    var body: some View {
        Menu {
            ForEach(SymbolRenderingStyle.allCases) { mode in
                Button {
                    selectedRenderingMode = mode
                } label: {
                    Label(mode.displayName, systemImage: mode.iconName)
                }
            }
        } label: {
            Image(systemName: selectedRenderingMode.iconName)
        }
    }
}

// MARK: - Color Picker Popover
struct SymbolColorPickerPopover: View {
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

// MARK: - Previews
#Preview("Grid Size Menu") {
    @Previewable @State var gridSize: SymbolGridSize = .medium
    
    SymbolGridSizeMenu(selectedGridSize: $gridSize)
        .padding()
}

#Preview("Rendering Mode Menu") {
    @Previewable @State var renderMode: SymbolRenderingStyle = .hierarchical
    
    SymbolRenderingModeMenu(selectedRenderingMode: $renderMode)
        .padding()
}

#Preview("Color Picker Popover") {
    @Previewable @State var color: Color = .blue
    
    SymbolColorPickerPopover(selectedColor: $color)
        .padding()
}