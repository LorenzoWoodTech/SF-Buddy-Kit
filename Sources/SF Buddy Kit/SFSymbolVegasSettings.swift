//
//  SFSymbolVegasSettings.swift
//  SF Buddy Kit
//
//  Vegas animation settings for the SF Symbol package
//

import SwiftUI

@Observable
@MainActor
public class SFSymbolVegasSettings {
    public static let shared = SFSymbolVegasSettings()
    
    // Vegas animation settings
    public var vegasAnimationSpeed: Double = 1.0
    public var vegasColorCycleSpeed: Double = 1.0
    public var vegasIntensity: Double = 1.0
    public var vegasRandomnessLevel: Double = 0.5
    public var vegasScaleIntensity: Double = 0.3
    public var vegasMovementIntensity: Double = 5.0
    public var vegasRotationEnabled: Bool = true
    
    private static let userDefaultsPrefix = "SFSymbolPackage_Vegas_"
    
    public init() {
        loadSettings()
    }
    
    private func loadSettings() {
        vegasAnimationSpeed = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)AnimationSpeed") as? Double ?? 1.0
        vegasColorCycleSpeed = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)ColorCycleSpeed") as? Double ?? 1.0
        vegasIntensity = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)Intensity") as? Double ?? 1.0
        vegasRandomnessLevel = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)RandomnessLevel") as? Double ?? 0.5
        vegasScaleIntensity = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)ScaleIntensity") as? Double ?? 0.3
        vegasMovementIntensity = UserDefaults.standard.object(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)MovementIntensity") as? Double ?? 5.0
        vegasRotationEnabled = UserDefaults.standard.bool(forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)RotationEnabled")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(vegasAnimationSpeed, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)AnimationSpeed")
        UserDefaults.standard.set(vegasColorCycleSpeed, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)ColorCycleSpeed")
        UserDefaults.standard.set(vegasIntensity, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)Intensity")
        UserDefaults.standard.set(vegasRandomnessLevel, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)RandomnessLevel")
        UserDefaults.standard.set(vegasScaleIntensity, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)ScaleIntensity")
        UserDefaults.standard.set(vegasMovementIntensity, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)MovementIntensity")
        UserDefaults.standard.set(vegasRotationEnabled, forKey: "\(SFSymbolVegasSettings.userDefaultsPrefix)RotationEnabled")
    }
    
    public func randomizeVegas() {
        vegasAnimationSpeed = Double.random(in: 0.5...3.0)
        vegasColorCycleSpeed = Double.random(in: 0.2...5.0)
        vegasIntensity = Double.random(in: 0.3...2.0)
        vegasRandomnessLevel = Double.random(in: 0.0...1.0)
        vegasScaleIntensity = Double.random(in: 0.1...1.0)
        vegasMovementIntensity = Double.random(in: 1.0...15.0)
        vegasRotationEnabled = Bool.random()
        saveSettings()
    }
    
    public func triggerVegasChaos() {
        vegasAnimationSpeed = Double.random(in: 2.0...3.0)
        vegasColorCycleSpeed = Double.random(in: 3.0...5.0)
        vegasIntensity = Double.random(in: 1.5...2.0)
        vegasRandomnessLevel = Double.random(in: 0.8...1.0)
        vegasScaleIntensity = Double.random(in: 0.7...1.0)
        vegasMovementIntensity = Double.random(in: 10.0...15.0)
        vegasRotationEnabled = true
        saveSettings()
    }
}
