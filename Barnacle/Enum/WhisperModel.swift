//
//  WhisperModel.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import Foundation

enum WhisperModel: String, CaseIterable {

    case whisper1 = "whisper-1"

    case gpt4oTranscribe = "gpt-4o-transcribe"

    var label: String {
        switch self {
        case .whisper1: "whisper-1"
        case .gpt4oTranscribe: "gpt-4o-transcribe"
        }
    }
}
