//
//  ButtonPlayground.swift
//  Barnacle
//
//  Created by Oleh Titov on 04.03.2026.
//

import SwiftUI

struct ButtonPlayground: View {
    let background = Color(#colorLiteral(red: 0.8979493976, green: 0.8979490399, blue: 0.8893644214, alpha: 1))
    let button = Color(#colorLiteral(red: 0.8710157871, green: 0.846331954, blue: 0.798853457, alpha: 1))
    
    var body: some View {
        HStack(spacing: 36) {
            //Pressed button
            ZStack {
                Circle()
                    .fill(button)
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(LinearGradient(colors: [.black.opacity(0.2), .white.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: 82, height: 82)
                    .blur(radius: 0.5)
                Circle()
                    .fill(button)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white, button],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    )
                Circle()
                    .fill(LinearGradient(colors: [.black.opacity(0.2), .white.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 78, height: 78)
                Ellipse()
                    .fill(button)
                    .frame(width: 78, height: 50)
                    .blur(radius: 14)
                    .opacity(0.8)
            }
            
            //Unpressed button
            ZStack {
                
                Circle()
                    .fill(button)
                    .frame(width: 92, height: 92)
                Ellipse()
                    .fill(LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.2), .clear], startPoint: .center, endPoint: .bottom))
                    .frame(width: 78, height: 100)
                    .blur(radius: 3)
                    .opacity(0.8)
                    .offset(y: 10)
                Circle()
                    .fill(LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(.black.opacity(0.9))
                    .frame(width: 82, height: 82)
                    .blur(radius: 0.5)
                Ellipse()
                    .fill(LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.3), .clear], startPoint: .center, endPoint: .bottom))
                    .frame(width: 78, height: 100)
                    .blur(radius: 5)
                    .opacity(0.1)
                    .offset(y: 10)
                Circle()
                    .fill(button)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white, button],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    )
                Circle()
                    .fill(LinearGradient(colors: [.black.opacity(0.2), .white.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 78, height: 78)
                Ellipse()
                    .fill(button)
                    .frame(width: 78, height: 50)
                    .blur(radius: 14)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    ButtonPlayground()
}
