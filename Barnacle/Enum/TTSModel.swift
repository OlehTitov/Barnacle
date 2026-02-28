//
//  TTSModel.swift
//  Barnacle
//
//  Created by Oleh Titov on 25.02.2026.
//

import Foundation

enum TTSModel: String, CaseIterable {

    case v3 = "eleven_v3"

    case turbo = "eleven_turbo_v2_5"

    case flash = "eleven_flash_v2_5"

    var label: String {
        switch self {
        case .v3: "V3 (Best Quality)"
        case .turbo: "Turbo v2.5 (Balanced)"
        case .flash: "Flash v2.5 (Fastest)"
        }
    }
}
