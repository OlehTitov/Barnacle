//
//  TTSStability.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

enum TTSStability: Double, CaseIterable {

    case creative = 0.0

    case natural = 0.5

    case robust = 1.0

    var label: String {
        switch self {
        case .creative: "Creative"
        case .natural: "Natural"
        case .robust: "Robust"
        }
    }
}
