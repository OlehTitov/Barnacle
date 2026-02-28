//
//  GeistPixelFont.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

enum GeistPixelFont: String, CaseIterable {

    case circle = "GeistPixel-Circle"

    case grid = "GeistPixel-Grid"

    case line = "GeistPixel-Line"

    case square = "GeistPixel-Square"

    case triangle = "GeistPixel-Triangle"

    var label: String {
        switch self {
        case .circle:
            "Circle"
        case .grid:
            "Grid"
        case .line:
            "Line"
        case .square:
            "Square"
        case .triangle:
            "Triangle"
        }
    }

    func font(size: CGFloat) -> Font {
        .custom(rawValue, size: size)
    }
}
