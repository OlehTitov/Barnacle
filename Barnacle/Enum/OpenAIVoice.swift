//
//  OpenAIVoice.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

import Foundation

enum OpenAIVoice: String, CaseIterable {

    case alloy

    case ash

    case ballad

    case coral

    case echo

    case fable

    case onyx

    case nova

    case sage

    case shimmer

    case verse

    case marin

    case cedar

    var label: String { rawValue.capitalized }
}
