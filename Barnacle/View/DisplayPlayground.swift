//
//  DisplayPlayground.swift
//  Barnacle
//
//  Created by Oleh Titov on 05.03.2026.
//

import SwiftUI

struct DisplayPlayground: View {
    let background = Color(#colorLiteral(red: 0.8979493976, green: 0.8979490399, blue: 0.8893644214, alpha: 1))
    let display = Color(#colorLiteral(red: 0.1176147535, green: 0.1176147535, blue: 0.1176147535, alpha: 1))
    var body: some View {
        VStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(background)
                    .frame(height: 12)
                    .overlay {
                        Color.black.opacity(0.5)
                    }
                Rectangle()
                    .fill(display)
                Rectangle()
                    .fill(background)
                    .frame(height: 12)
                    .overlay {
                        Color.white.opacity(0.5)
                    }
                
            }
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    DisplayPlayground()
}
