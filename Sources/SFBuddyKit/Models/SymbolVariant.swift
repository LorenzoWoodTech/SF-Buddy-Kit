//
//  SymbolVariant.swift
//  SFBuddyKit
//
//  Model for SF Symbol variants (fill, badge, etc.)
//

import Foundation

struct SymbolVariant: Identifiable, Hashable {
    let id = UUID()
    let symbolName: String
    let displayName: String
    let badgeIcon: String?
    let isBase: Bool
    let variantType: VariantType
    
    init(symbolName: String, displayName: String, badgeIcon: String? = nil, isBase: Bool = false, variantType: VariantType = .base) {
        self.symbolName = symbolName
        self.displayName = displayName
        self.badgeIcon = badgeIcon
        self.isBase = isBase
        self.variantType = variantType
    }
    
    enum VariantType {
        case base
        case fill
        case badge
        case slash
        case circle
    }
}

extension SymbolVariant {
    /// Create base variant (no badge/fill modifiers)
    static func base(_ symbolName: String) -> SymbolVariant {
        SymbolVariant(
            symbolName: symbolName,
            displayName: "Base",
            badgeIcon: nil, // Base doesn't need an icon
            isBase: true,
            variantType: .base
        )
    }
    
    /// Create fill variant
    static func fill(_ baseSymbolName: String) -> SymbolVariant {
        SymbolVariant(
            symbolName: baseSymbolName + ".fill",
            displayName: "Fill",
            badgeIcon: "paintbrush.fill",
            isBase: false,
            variantType: .fill
        )
    }
    
    /// Create slash variant
    static func slash(_ baseSymbolName: String) -> SymbolVariant {
        SymbolVariant(
            symbolName: baseSymbolName + ".slash",
            displayName: "Slash",
            badgeIcon: "slash.circle",
            isBase: false,
            variantType: .slash
        )
    }
    
    /// Create circle variant
    static func circle(_ baseSymbolName: String) -> SymbolVariant {
        SymbolVariant(
            symbolName: baseSymbolName + ".circle",
            displayName: "Circle",
            badgeIcon: "circle",
            isBase: false,
            variantType: .circle
        )
    }
    
    /// Create circle.fill variant
    static func circleFill(_ baseSymbolName: String) -> SymbolVariant {
        SymbolVariant(
            symbolName: baseSymbolName + ".circle.fill",
            displayName: "Circle Fill",
            badgeIcon: "circle.fill",
            isBase: false,
            variantType: .circle
        )
    }
    
    /// Create badge variant by parsing the badge icon from the symbol name
    static func badge(_ fullSymbolName: String, baseSymbolName: String) -> SymbolVariant {
        // Extract badge icon name from the symbol
        // e.g., "folder.badge.gearshape" -> "gearshape"
        // e.g., "app.badge.plus" -> "plus"
        // e.g., "bell.badge" -> "circle.fill" (default)
        
        let badgeIcon = extractBadgeIcon(from: fullSymbolName, base: baseSymbolName)
        let displayName = extractBadgeDisplayName(from: fullSymbolName)
        
        return SymbolVariant(
            symbolName: fullSymbolName,
            displayName: displayName,
            badgeIcon: badgeIcon,
            isBase: false,
            variantType: .badge
        )
    }
    
    private static func extractBadgeIcon(from fullSymbol: String, base: String) -> String {
        // Get everything after the base symbol name
        let suffix = String(fullSymbol.dropFirst(base.count))
        
        // Check for triangle badge first
        if suffix.contains(".trianglebadge.") {
            let parts = suffix.components(separatedBy: ".trianglebadge.")
            if parts.count > 1 {
                var iconName = parts[1]
                // Strip .fill from the end - fill state of badge icon is irrelevant
                iconName = iconName.replacingOccurrences(of: ".fill", with: "")
                // For trianglebadge, wrap in triangle shape
                return wrapInShape(iconName, preferredShape: "triangle")
            }
        }
        
        // Check for regular badge
        if suffix.contains(".badge.") {
            let parts = suffix.components(separatedBy: ".badge.")
            if parts.count > 1 {
                var iconName = parts[1]
                // Strip .fill from the end - fill state of badge icon is irrelevant
                iconName = iconName.replacingOccurrences(of: ".fill", with: "")
                return wrapInShape(iconName, preferredShape: "circle")
            }
        }
        
        // Just ".badge" with no icon specified
        if suffix == ".badge" || suffix == ".badge.fill" {
            return "circle.fill"
        }
        
        // Fallback
        return "circle.fill"
    }
    
    private static func wrapInShape(_ iconName: String, preferredShape: String) -> String {
        // Icons that already have a shape - return as-is
        let hasShape = iconName.contains(".circle") || 
                       iconName.contains(".square") || 
                       iconName.contains(".triangle") ||
                       iconName.contains(".diamond") ||
                       iconName.contains(".rectangle") ||
                       iconName.contains(".capsule") ||
                       iconName.contains(".shield")
        
        if hasShape {
            return iconName
        }
        
        // Common badge icons that should be wrapped in a shape
        let simpleIcons = [
            "plus", "minus", "multiply", "divide", "equal",
            "checkmark", "xmark", "questionmark", "exclamationmark",
            "person", "star", "heart", "bolt", "flag",
            "bell", "tag", "bookmark", "gear", "gearshape",
            "clock", "calendar", "location", "pin",
            "arrow", "chevron", "link", "paperclip",
            "number", "character", "letter"
        ]
        
        // Check if icon starts with any simple icon name
        let needsShape = simpleIcons.contains { iconName.hasPrefix($0) || iconName == $0 }
        
        if needsShape {
            // Use the preferred shape (circle for badges, triangle for trianglebadges)
            return "\(iconName).\(preferredShape).fill"
        }
        
        // For other icons (like "gearshape"), wrap in circle by default
        return "\(iconName).\(preferredShape).fill"
    }
    
    private static func extractBadgeDisplayName(from fullSymbol: String) -> String {
        if fullSymbol.contains(".badge.") {
            let parts = fullSymbol.components(separatedBy: ".badge.")
            if parts.count > 1 {
                return parts[1].capitalized
            }
        }
        return "Badge"
    }
}