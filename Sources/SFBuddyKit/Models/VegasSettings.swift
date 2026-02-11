//
//  VegasSettings.swift
//  SFBuddyKit
//
//  Vegas mode animation settings
//

import SwiftUI

@Observable
@MainActor
public class VegasSettings {
    public static let shared = VegasSettings()
    
    private static let vegasAnimationSpeedKey = "SFBuddyKit_VegasAnimationSpeed"
    private static let vegasColorCycleSpeedKey = "SFBuddyKit_VegasColorCycleSpeed"
    private static let vegasIntensityKey = "SFBuddyKit_VegasIntensity"
    private static let vegasRotationEnabledKey = "SFBuddyKit_VegasRotationEnabled"
    private static let vegasRandomnessLevelKey = "SFBuddyKit_VegasRandomnessLevel"
    private static let vegasScaleIntensityKey = "SFBuddyKit_VegasScaleIntensity"
    private static let vegasMovementIntensityKey = "SFBuddyKit_VegasMovementIntensity"
    
    public var vegasAnimationSpeed: Double {
        didSet {
            UserDefaults.standard.set(vegasAnimationSpeed, forKey: VegasSettings.vegasAnimationSpeedKey)
        }
    }
    
    public var vegasColorCycleSpeed: Double {
        didSet {
            UserDefaults.standard.set(vegasColorCycleSpeed, forKey: VegasSettings.vegasColorCycleSpeedKey)
        }
    }
    
    public var vegasIntensity: Double {
        didSet {
            UserDefaults.standard.set(vegasIntensity, forKey: VegasSettings.vegasIntensityKey)
        }
    }
    
    public var vegasRotationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(vegasRotationEnabled, forKey: VegasSettings.vegasRotationEnabledKey)
        }
    }

    public var vegasRandomnessLevel: Double {
        didSet {
            UserDefaults.standard.set(vegasRandomnessLevel, forKey: VegasSettings.vegasRandomnessLevelKey)
        }
    }
    
    public var vegasScaleIntensity: Double {
        didSet {
            UserDefaults.standard.set(vegasScaleIntensity, forKey: VegasSettings.vegasScaleIntensityKey)
        }
    }
    
    public var vegasMovementIntensity: Double {
        didSet {
            UserDefaults.standard.set(vegasMovementIntensity, forKey: VegasSettings.vegasMovementIntensityKey)
        }
    }

    public func triggerVegasChaos() {
        randomizeVegas()
    }

    public func randomizeVegas() {
        vegasAnimationSpeed = Double.random(in: 0.5...3.0)
        vegasColorCycleSpeed = Double.random(in: 0.2...5.0)
        vegasIntensity = Double.random(in: 0.3...2.0)
        vegasRandomnessLevel = Double.random(in: 0.0...1.0)
        vegasScaleIntensity = Double.random(in: 0.1...1.0)
        vegasMovementIntensity = Double.random(in: 1.0...15.0)
        vegasRotationEnabled = Bool.random()
    }

    public init() {
        self.vegasAnimationSpeed = UserDefaults.standard.object(forKey: VegasSettings.vegasAnimationSpeedKey) as? Double ?? 1.0
        self.vegasColorCycleSpeed = UserDefaults.standard.object(forKey: VegasSettings.vegasColorCycleSpeedKey) as? Double ?? 1.0
        self.vegasIntensity = UserDefaults.standard.object(forKey: VegasSettings.vegasIntensityKey) as? Double ?? 1.0
        self.vegasRotationEnabled = UserDefaults.standard.object(forKey: VegasSettings.vegasRotationEnabledKey) as? Bool ?? true
        self.vegasRandomnessLevel = UserDefaults.standard.object(forKey: VegasSettings.vegasRandomnessLevelKey) as? Double ?? 0.5
        self.vegasScaleIntensity = UserDefaults.standard.object(forKey: VegasSettings.vegasScaleIntensityKey) as? Double ?? 0.5
        self.vegasMovementIntensity = UserDefaults.standard.object(forKey: VegasSettings.vegasMovementIntensityKey) as? Double ?? 8.0
    }
}
