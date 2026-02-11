//
//  RenderStyles.swift
//  SF Buddy
//
//  Shared symbol rendering and grid configuration
//

import SwiftUI

// MARK: - Grid Size Configuration
public enum SymbolGridSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    public var columnCount: Int {
        switch self {
        case .small: return 8
        case .medium: return 4
        case .large: return 3
        case .extraLarge: return 1
        }
    }
    
    public var iconName: String {
        switch self {
        case .small: return "grid"
        case .medium: return "square.grid.2x2"
        case .large: return "rectangle.grid.1x2"
        case .extraLarge: return "square.fill"
        }
    }
    
    public var symbolSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 24
        case .large: return 32
        case .extraLarge: return 64
        }
    }
    
    public var buttonSize: (min: CGFloat, max: CGFloat, height: CGFloat) {
        switch self {
        case .small: return (40, 50, 50)
        case .medium: return (70, 85, 75)
        case .large: return (90, 110, 90)
        case .extraLarge: return (300, 350, 140)
        }
    }
}

// MARK: - Symbol Rendering Mode (Unified)
public enum SymbolRenderingMode: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case monochrome = "monochrome"
    case hierarchical = "hierarchical"
    case palette = "palette"
    case vegas = "vegas"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .monochrome: return "Monochrome"
        case .hierarchical: return "Hierarchical"
        case .palette: return "Palette"
        case .vegas: return "Vegas"
        }
    }
    
    public var iconName: String {
        switch self {
        case .automatic: return "circle.hexagongrid"
        case .monochrome: return "circle"
        case .hierarchical: return "circle.lefthalf.striped.horizontal"
        case .palette: return "paintpalette"
        case .vegas: return "sparkles"
        }
    }
    
    public var swiftUIMode: SwiftUI.SymbolRenderingMode {
        switch self {
        case .automatic: return .multicolor
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .palette: return .palette
        case .vegas: return .hierarchical
        }
    }
    
    public var supportsColorCustomization: Bool {
        switch self {
        case .monochrome, .hierarchical, .palette:
            return true
        case .automatic, .vegas:
            return false
        }
    }
}