//
//  SFSymbolPackageSettings.swift
//  SF Buddy Package
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
    
    public init() {
        self.symbolCount = UserDefaults.standard.object(forKey: SFSymbolPackageSettings.symbolCountKey) as? Int ?? 12
        let modelRawValue = UserDefaults.standard.string(forKey: SFSymbolPackageSettings.selectedModelKey) ?? ClaudeModel.sonnet.rawValue
        self.selectedModel = ClaudeModel(rawValue: modelRawValue) ?? .sonnet
    }
}

public enum ClaudeModel: String, CaseIterable, Identifiable {
    case sonnet = "claude-3-5-sonnet-20240620"
    case opus = "claude-3-opus-20240229"
    case claude4 = "claude-4-20241120"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .sonnet: return "Claude 3.5 Sonnet"
        case .opus: return "Claude 3 Opus"
        case .claude4: return "Claude 4"
        }
    }
    
    public var description: String {
        switch self {
        case .sonnet: return "Fast and intelligent (recommended)"
        case .opus: return "Most capable, slower"
        case .claude4: return "Latest and most advanced (experimental)"
        }
    }
}