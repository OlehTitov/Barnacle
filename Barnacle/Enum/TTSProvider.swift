//
//  TTSProvider.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

enum TTSProvider: String, CaseIterable {

    case elevenLabs

    case openAI

    var label: String {
        switch self {
        case .elevenLabs: "ElevenLabs"
        case .openAI: "OpenAI"
        }
    }
}
