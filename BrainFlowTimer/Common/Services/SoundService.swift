//
//  SoundService.swift
//  BrainFlowTimer
//
//  Created by Ruslan Popesku on 12/7/18.
//  Copyright © 2018 Yalantis. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

enum SoundType: String {
    
    case startCountdown1
    case clockTick1
    case clockTick2
    case clockTick3
    case finish1
    
}

final class SoundService {
    
    static let shared = SoundService()
    
    func playSound(_ alertType: SoundType, withVibration: Bool = false) {
        if let filePath = Bundle.main.path(forResource: alertType.rawValue, ofType: "wav") {
            let soundURL = URL(fileURLWithPath: filePath)
            var soundID: SystemSoundID = 0
            if withVibration {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
            AudioServicesPlaySystemSound(soundID)
        }
    }
    
}
