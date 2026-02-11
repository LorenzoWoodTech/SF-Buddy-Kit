//
//  SFBuddyKit.swift
//  SFBuddyKit
//
//  Main entry point for SFBuddyKit package
//

import Foundation
import SwiftUI

// MARK: - Symbol Actions

public enum SymbolAction: String, Codable, CaseIterable {
    case copied = "copied"
    case exported = "exported"
    
    public var displayName: String {
        switch self {
        case .copied: return "Copied"
        case .exported: return "Exported"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .copied: return "doc.on.clipboard"
        case .exported: return "square.and.arrow.up"
        }
    }
}

public struct SymbolActionRecord: Codable, Hashable {
    public let action: SymbolAction
    public let date: Date
    
    public init(action: SymbolAction, date: Date) {
        self.action = action
        self.date = date
    }
}

// MARK: - Symbol Suggestion

public struct SFSymbolSuggestion: Identifiable {
    public let id = UUID()
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}