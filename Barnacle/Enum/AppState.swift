//
//  AppState.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

enum AppState {

    case idle

    case recording

    case processing

    case speaking

    case error(String)
}
