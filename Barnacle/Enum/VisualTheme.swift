//
//  VisualTheme.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

import SwiftUI

enum VisualTheme: String, CaseIterable {

    case midnight

    case plastic

    var label: String {
        switch self {
        case .midnight:
            "Midnight"
        case .plastic:
            "Plastic"
        }
    }

    var accent: Color {
        switch self {
        case .midnight:
            Color(red: 0.0, green: 0.85, blue: 0.45)
        case .plastic:
            Color(red: 0.88, green: 0.32, blue: 0.27)
        }
    }

    var background: Color {
        switch self {
        case .midnight:
            Color(red: 0.11, green: 0.13, blue: 0.16)
        case .plastic:
            Color(red: 0.83, green: 0.79, blue: 0.71)
        }
    }

    var displayBackground: Color {
        switch self {
        case .midnight:
            Color(red: 0.08, green: 0.09, blue: 0.11)
        case .plastic:
            Color(red: 0.75, green: 0.72, blue: 0.65)
        }
    }

    var buttonSurface: Color {
        switch self {
        case .midnight:
            Color(red: 0.14, green: 0.16, blue: 0.19)
        case .plastic:
            Color(red: 0.88, green: 0.32, blue: 0.27)
        }
    }

    var buttonBorder: Color {
        switch self {
        case .midnight:
            Color(white: 0.25)
        case .plastic:
            Color(red: 0.72, green: 0.22, blue: 0.18)
        }
    }

    var textPrimary: Color {
        switch self {
        case .midnight:
            Color(white: 0.75)
        case .plastic:
            Color(red: 0.20, green: 0.18, blue: 0.15)
        }
    }

    var surface: Color {
        switch self {
        case .midnight:
            Color(red: 0.12, green: 0.12, blue: 0.12)
        case .plastic:
            Color(red: 0.80, green: 0.76, blue: 0.68)
        }
    }

    var surfaceElevated: Color {
        switch self {
        case .midnight:
            Color(red: 0.18, green: 0.18, blue: 0.18)
        case .plastic:
            Color(red: 0.85, green: 0.81, blue: 0.73)
        }
    }

    var buttonSocketInner: Color {
        switch self {
        case .midnight:
            Color(red: 0.04, green: 0.04, blue: 0.06)
        case .plastic:
            Color(red: 0.55, green: 0.15, blue: 0.12)
        }
    }

    var buttonDomeHighlight: Color {
        switch self {
        case .midnight:
            Color(red: 0.22, green: 0.24, blue: 0.28)
        case .plastic:
            Color(red: 0.95, green: 0.42, blue: 0.36)
        }
    }

    var buttonBase: Color {
        switch self {
        case .midnight:
            .black
        case .plastic:
            Color(red: 0.72, green: 0.22, blue: 0.18)
        }
    }

    var buttonGradientEdge: Color {
        switch self {
        case .midnight:
            Color(red: 0.08, green: 0.09, blue: 0.11)
        case .plastic:
            Color(red: 0.78, green: 0.26, blue: 0.22)
        }
    }

    var buttonStrokeTop: Color {
        switch self {
        case .midnight:
            Color(white: 0.35)
        case .plastic:
            Color(red: 0.95, green: 0.45, blue: 0.38)
        }
    }

    var buttonStrokeBottom: Color {
        switch self {
        case .midnight:
            Color(white: 0.08)
        case .plastic:
            Color(red: 0.62, green: 0.18, blue: 0.14)
        }
    }

    var buttonIconActive: Color {
        switch self {
        case .midnight:
            .white
        case .plastic:
            .white
        }
    }

    var buttonIconInactive: Color {
        switch self {
        case .midnight:
            Color(white: 0.4)
        case .plastic:
            Color(red: 0.83, green: 0.79, blue: 0.71)
        }
    }

    var ledIdle: Color {
        switch self {
        case .midnight:
            Color(white: 0.3)
        case .plastic:
            Color(red: 0.68, green: 0.64, blue: 0.57)
        }
    }

    var audioBlockInactive: Color {
        switch self {
        case .midnight:
            Color(white: 0.2)
        case .plastic:
            Color(red: 0.72, green: 0.68, blue: 0.61)
        }
    }

    var audioBlockActive: Color {
        switch self {
        case .midnight:
            .white
        case .plastic:
            accent
        }
    }

    var dotMatrix: Color {
        switch self {
        case .midnight:
            .black
        case .plastic:
            Color(red: 0.58, green: 0.54, blue: 0.48)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .midnight:
            .dark
        case .plastic:
            .light
        }
    }
}
