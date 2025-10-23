import Foundation

// MARK: - Symbol Actions

public enum SymbolAction: String, CaseIterable, Codable {
    case copied, exported, favorited, reSearched
    
    public var displayName: String {
        switch self {
        case .copied: return "Copied"
        case .exported: return "Exported" 
        case .favorited: return "Favorited"
        case .reSearched: return "Re-searched"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .copied: return "doc.on.clipboard"
        case .exported: return "square.and.arrow.up"
        case .favorited: return "heart.fill"
        case .reSearched: return "arrow.clockwise"
        }
    }
}

public struct SymbolActionRecord: Codable, Identifiable {
    public var id = UUID()
    public let action: SymbolAction
    public let date: Date
    
    public init(action: SymbolAction, date: Date = Date()) {
        self.action = action
        self.date = date
    }
}