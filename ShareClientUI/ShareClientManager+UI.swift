//
//  ShareClientManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit
import ShareClient

extension ShareClientManager: CGMManagerUI {
    public static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManagerUI> {
        return .userInteractionRequired(ShareClientSetupViewController())
    }

    public func settingsViewController(for preferredGlucoseUnit: HKUnit, colorPalette: LoopUIColorPalette) -> (UIViewController & CGMManagerOnboardNotifying & PreferredGlucoseUnitObserver & CompletionNotifying) {
        let settings = ShareClientSettingsViewController(cgmManager: self, glucoseUnit: preferredGlucoseUnit, allowsDeletion: true)
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var smallImage: UIImage? {
        return nil
    }

    // TODO Placeholder. This functionality will come with LOOP-1311
    public var cgmStatusHighlight: DeviceStatusHighlight? {
        return nil
    }

    // TODO Placeholder. This functionality will come with LOOP-1311
    public var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return nil
    }
}
