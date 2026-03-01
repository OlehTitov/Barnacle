//
//  AudioUtilities.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

@preconcurrency import AVFoundation

enum AudioUtilities {

    nonisolated static func normalizeDecibels(_ db: Float) -> Float {
        let linear = max(0, min(1, (db + 50) / 50))
        return sqrt(linear)
    }

    nonisolated static func audioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(max(frames, 1)))
        let db = 20 * log10(max(rms, 1e-10))
        return normalizeDecibels(db)
    }

    static var transcriptionFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }

    nonisolated static func convertToMono16kHz(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> [Float]? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else { return nil }

        var inputProvided = false
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputProvided {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputProvided = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, convertedBuffer.frameLength > 0,
              let floatData = convertedBuffer.floatChannelData?[0]
        else { return nil }

        let count = Int(convertedBuffer.frameLength)
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = floatData[i]
        }
        return samples
    }
}

class AudioPlayerFinishDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {

    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
