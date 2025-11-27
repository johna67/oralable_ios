//
//  PPGChannelOrder.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  PPGChannelOrder.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Enum for PPG channel ordering configuration
//

import Foundation

/// Defines the order of PPG channels (for debugging channel mapping issues)
enum PPGChannelOrder: String, CaseIterable, Codable {
    case standard = "Red, IR, Green"
    case alternate1 = "IR, Red, Green"
    case alternate2 = "Green, Red, IR"
    case alternate3 = "Red, Green, IR"
    case alternate4 = "IR, Green, Red"
    case alternate5 = "Green, IR, Red"
    
    var description: String {
        return rawValue
    }
}
