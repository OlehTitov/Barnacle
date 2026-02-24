//
//  ConversationPhase.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

enum ConversationPhase {

    case idle

    case greeting

    case listening

    case processing

    case speaking

    case finished

    case failed(String)
}
