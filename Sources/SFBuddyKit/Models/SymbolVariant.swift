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
                let iconName = parts[1]
                return wrapInShape(iconName, preferredShape: "triangle")
            }
        }
        
        // Check for regular badge
        if suffix.contains(".badge.") {
            let parts = suffix.components(separatedBy: ".badge.")
            if parts.count > 1 {
                let iconName = parts[1]
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
        // Check if the icon name ends with .fill
        let hasFillSuffix = iconName.hasSuffix(".fill")
        let baseIconName = hasFillSuffix ? String(iconName.dropLast(5)) : iconName
        
        // Icons that already have a shape - return as-is
        let hasShape = baseIconName.contains(".circle") || 
                       baseIconName.contains(".square") || 
                       baseIconName.contains(".triangle") ||
                       baseIconName.contains(".diamond") ||
                       baseIconName.contains(".rectangle") ||
                       baseIconName.contains(".capsule") ||
                       baseIconName.contains(".shield")
        
        if hasShape {
            return iconName // Return original with .fill if it had it
        }
        
        // Icons that are already complete shapes and shouldn't be wrapped
        let completeShapeIcons = [
            "clock", "bell", "flag", "tag", "bookmark", 
            "heart", "star", "moon", "sun", "cloud",
            "bolt", "flame", "drop", "snowflake",
            "leaf", "antenna", "hourglass"
        ]
        
        if completeShapeIcons.contains(baseIconName) {
            return iconName // Use directly - clock, clock.fill, etc.
        }
        
        // Common badge icons that should be wrapped in a shape
        let simpleIcons = [
            "plus", "minus", "multiply", "divide", "equal",
            "checkmark", "xmark", "questionmark", "exclamationmark",
            "person", "location", "pin",
            "arrow", "chevron", "link", "paperclip",
            "number", "character", "letter", "gear", "gearshape"
        ]
        
        // Check if icon starts with any simple icon name
        let needsShape = simpleIcons.contains { baseIconName.hasPrefix($0) || baseIconName == $0 }
        
        if needsShape {
            // Wrap with shape, preserving fill state
            if hasFillSuffix {
                return "\(baseIconName).\(preferredShape).fill"
            } else {
                return "\(baseIconName).\(preferredShape)"
            }
        }
        
        // For other icons, wrap in shape with fill
        if hasFillSuffix {
            return "\(baseIconName).\(preferredShape).fill"
        } else {
            return "\(baseIconName).\(preferredShape)"
        }
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