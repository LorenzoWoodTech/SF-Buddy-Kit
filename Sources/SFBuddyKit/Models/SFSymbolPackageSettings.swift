//
//  SFSymbolPackageSettings.swift
//  Package
//
//  Clean settings for the SF Symbol package
//

import SwiftUI

@Observable
@MainActor
public class SFSymbolPackageSettings {
    public static let shared = SFSymbolPackageSettings()
    
    private static let symbolCountKey = "SFSymbolPackage_SymbolCount"
    private static let selectedModelKey = "SFSymbolPackage_SelectedModel"
    private static let modelProviderKey = "SFSymbolPackage_ModelProvider"
    
    public var symbolCount: Int {
        didSet {
            UserDefaults.standard.set(symbolCount, forKey: SFSymbolPackageSettings.symbolCountKey)
        }
    }
    
    public var selectedModel: ClaudeModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: SFSymbolPackageSettings.selectedModelKey)
        }
    }
    
    public var modelProvider: ModelProvider {
        didSet {
            UserDefaults.standard.set(modelProvider.rawValue, forKey: SFSymbolPackageSettings.modelProviderKey)
        }
    }
    
    public init() {
        self.symbolCount = UserDefaults.standard.object(forKey: SFSymbolPackageSettings.symbolCountKey) as? Int ?? 12
        let modelRawValue = UserDefaults.standard.string(forKey: SFSymbolPackageSettings.selectedModelKey) ?? ClaudeModel.sonnet45.rawValue
        self.selectedModel = ClaudeModel(rawValue: modelRawValue) ?? .sonnet45
        
        let providerRawValue = UserDefaults.standard.string(forKey: SFSymbolPackageSettings.modelProviderKey) ?? ModelProvider.apple.rawValue
        self.modelProvider = ModelProvider(rawValue: providerRawValue) ?? .apple
    }
}

public enum ModelProvider: String, CaseIterable, Identifiable {
    case apple = "apple"
    case claude = "claude"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .apple: return "Apple Intelligence"
        case .claude: return "Claude API"
        }
    }
    
    public var description: String {
        switch self {
        case .apple: return "On-device, private, requires iOS 26+"
        case .claude: return "Cloud-based, requires API key"
        }
    }
}

public enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus46 = "claude-opus-4-6"
    case sonnet45 = "claude-sonnet-4-5-20250929"
    case haiku45 = "claude-haiku-4-5-20251001"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .opus46: return "Claude Opus 4.6"
        case .sonnet45: return "Claude Sonnet 4.5"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }
    
    public var description: String {
        switch self {
        case .opus46: return "Most intelligent for agents and coding"
        case .sonnet45: return "Best speed/intelligence balance (recommended)"
        case .haiku45: return "Fastest with near-frontier intelligence"
        }
    }
}