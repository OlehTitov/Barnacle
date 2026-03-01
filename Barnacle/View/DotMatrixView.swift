//
//  DotMatrixView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct DotMatrixView: View {

    private let columns = 6
    private let rows = 4

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                GridRow {
                    ForEach(0..<columns, id: \.self) { _ in
                        Circle()
                            .fill(BarnacleTheme.dotMatrix)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
    }
}
