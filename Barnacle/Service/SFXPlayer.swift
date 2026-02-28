//
//  SFXPlayer.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import AVFoundation

enum SFXPlayer {

    private nonisolated(unsafe) static var player: AVAudioPlayer?

    static func play(_ name: String, ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
