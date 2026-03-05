//
//  DisplayPlayground.swift
//  Barnacle
//
//  Created by Oleh Titov on 05.03.2026.
//

import SwiftUI

struct DisplayPlayground: View {
    let background = Color(#colorLiteral(red: 0.8979493976, green: 0.8979490399, blue: 0.8893644214, alpha: 1))
    let display = Color(#colorLiteral(red: 0.8979493976, green: 0.8979490399, blue: 0.8893644214, alpha: 1))
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 24)
                .fill()
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1.5
                        )
                )
                .padding()
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    DisplayPlayground()
}
