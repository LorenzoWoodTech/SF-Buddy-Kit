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
            badgeIcon: "circle",
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
    
    /// Create badge variant with appropriate icon
    static func badge(_ baseSymbolName: String, badgeType: BadgeType) -> SymbolVariant {
        let suffix = badgeType.suffix
        let fullName = baseSymbolName + suffix
        return SymbolVariant(
            symbolName: fullName,
            displayName: badgeType.displayName,
            badgeIcon: badgeType.icon,
            isBase: false,
            variantType: .badge
        )
    }
}

enum BadgeType: String, CaseIterable {
    case badge = ".badge"
    case badgePlus = ".badge.plus"
    case badgeMinus = ".badge.minus"
    case badgeCheckmark = ".badge.checkmark"
    case badgeXmark = ".badge.xmark"
    case badgeEllipsis = ".badge.ellipsis"
    case badgeQuestionmark = ".badge.questionmark"
    case badgeExclamationmark = ".badge.exclamationmark"
    case trianglebadgeExclamationmark = ".trianglebadge.exclamationmark"
    case badgeGearshape = ".badge.gearshape"
    
    var suffix: String { rawValue }
    
    var displayName: String {
        switch self {
        case .badge: return "Badge"
        case .badgePlus: return "Plus"
        case .badgeMinus: return "Minus"
        case .badgeCheckmark: return "Check"
        case .badgeXmark: return "X"
        case .badgeEllipsis: return "More"
        case .badgeQuestionmark: return "?"
        case .badgeExclamationmark: return "!"
        case .trianglebadgeExclamationmark: return "⚠️"
        case .badgeGearshape: return "Gear"
        }
    }
    
    var icon: String {
        switch self {
        case .badge: return "circle.fill"
        case .badgePlus: return "plus"
        case .badgeMinus: return "minus"
        case .badgeCheckmark: return "checkmark"
        case .badgeXmark: return "xmark"
        case .badgeEllipsis: return "ellipsis"
        case .badgeQuestionmark: return "questionmark"
        case .badgeExclamationmark: return "exclamationmark"
        case .trianglebadgeExclamationmark: return "exclamationmark.triangle.fill"
        case .badgeGearshape: return "gearshape"
        }
    }
}