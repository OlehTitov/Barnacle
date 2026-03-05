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
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(background)
                    .padding()
                LinearGradient(colors: [.black.opacity(0.2), .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding()
                AngularGradient(colors: [.black.opacity(0.2), .black.opacity(0.3), background, .white.opacity(0.7), .black.opacity(0.2)], center: .center, angle: Angle(degrees: 180))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding()
                RoundedRectangle(cornerRadius: 16)
                    .fill(display)
                    .padding(26)
                
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
