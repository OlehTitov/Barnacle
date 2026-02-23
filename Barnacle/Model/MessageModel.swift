//
//  MessageModel.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

struct MessageModel: Identifiable {

    let id = UUID()
    let role: MessageRole
    var text: String
}
