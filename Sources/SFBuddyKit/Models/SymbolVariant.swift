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
                _ = parts[1]
                // For trianglebadge, use the triangle version if it exists
                return "exclamationmark.triangle.fill"
            }
        }
        
        // Check for regular badge
        if suffix.contains(".badge.") {
            let parts = suffix.components(separatedBy: ".badge.")
            if parts.count > 1 {
                let iconName = parts[1]
                return iconName // Use the actual badge icon name
            }
        }
        
        // Just ".badge" with no icon specified
        if suffix == ".badge" {
            return "circle.fill"
        }
        
        // Fallback
        return "circle.fill"
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