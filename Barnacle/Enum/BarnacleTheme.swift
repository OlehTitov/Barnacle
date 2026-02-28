//
//  BarnacleTheme.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

enum BarnacleTheme {

    static let accent = Color(red: 0.0, green: 0.85, blue: 0.45)

    static let background = Color(red: 0.11, green: 0.13, blue: 0.16)

    static let displayBackground = Color(red: 0.08, green: 0.09, blue: 0.11)

    static let buttonSurface = Color(red: 0.14, green: 0.16, blue: 0.19)

    static let buttonBorder = Color(white: 0.25)

    static let textPrimary = Color(white: 0.75)

    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)

    static let surfaceElevated = Color(red: 0.18, green: 0.18, blue: 0.18)

    static let controlButtonSize: CGFloat = 80

    static let displayCornerRadius: CGFloat = 20

    static let cornerRadius: CGFloat = 16

    static let monoBody: Font = .system(.body, design: .monospaced)

    static let monoCaption: Font = .system(.caption, design: .monospaced)

    static let monoTitle: Font = .system(.title3, design: .monospaced, weight: .bold)

    static let monoLabel: Font = .system(.caption2, design: .monospaced)
}
