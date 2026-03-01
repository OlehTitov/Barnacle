//
//  BarnacleTheme.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

enum BarnacleTheme {

    static var current: VisualTheme = .midnight

    static var accent: Color { current.accent }

    static var background: Color { current.background }

    static var displayBackground: Color { current.displayBackground }

    static var buttonSurface: Color { current.buttonSurface }

    static var buttonBorder: Color { current.buttonBorder }

    static var textPrimary: Color { current.textPrimary }

    static var surface: Color { current.surface }

    static var surfaceElevated: Color { current.surfaceElevated }

    static var buttonBase: Color { current.buttonBase }

    static var buttonGradientEdge: Color { current.buttonGradientEdge }

    static var buttonStrokeTop: Color { current.buttonStrokeTop }

    static var buttonStrokeBottom: Color { current.buttonStrokeBottom }

    static var buttonIconActive: Color { current.buttonIconActive }

    static var buttonIconInactive: Color { current.buttonIconInactive }

    static var ledIdle: Color { current.ledIdle }

    static var audioBlockInactive: Color { current.audioBlockInactive }

    static var audioBlockActive: Color { current.audioBlockActive }

    static var dotMatrix: Color { current.dotMatrix }

    static let controlButtonSize: CGFloat = 80

    static let displayCornerRadius: CGFloat = 20

    static let cornerRadius: CGFloat = 16

    static let monoBody: Font = .system(.body, design: .monospaced)

    static let monoCaption: Font = .system(.caption, design: .monospaced)

    static let monoTitle: Font = .system(.title3, design: .monospaced, weight: .bold)

    static let monoLabel: Font = .system(.caption2, design: .monospaced)
}
