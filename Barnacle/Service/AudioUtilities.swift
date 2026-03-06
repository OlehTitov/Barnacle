//
//  AudioUtilities.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

@preconcurrency import AVFoundation

enum AudioUtilities {

    static func activateVoiceCaptureSession(
        routingMode: AudioRoutingMode = .nativeCarBluetooth
    ) throws {
        let session = AVAudioSession.sharedInstance()
        switch routingMode {
        case .nativeCarBluetooth:
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetoothHFP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            if let input = preferredBluetoothInput(in: session) {
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetoothHFP]
                )
                try session.setActive(true)
                try session.setPreferredInput(input)
            } else {
                try session.setPreferredInput(nil)
            }

        case .bluetoothAdapter:
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.setPreferredInput(nil)
        }
    }

    @discardableResult
    static func applyPreferredInput(
        for routingMode: AudioRoutingMode,
        in session: AVAudioSession = .sharedInstance()
    ) throws -> Bool {
        switch routingMode {
        case .nativeCarBluetooth:
            guard let input = preferredBluetoothInput(in: session) else {
                try session.setPreferredInput(nil)
                return false
            }
            try session.setPreferredInput(input)
            return true
        case .bluetoothAdapter:
            try session.setPreferredInput(nil)
            return false
        }
    }

    nonisolated static func normalizeDecibels(_ db: Float) -> Float {
        let linear = max(0, min(1, (db + 50) / 50))
        return sqrt(linear)
    }

    nonisolated static func audioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = monoSamples(from: buffer), !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-10))
        return normalizeDecibels(db)
    }

    static func currentOutputRoute() -> AudioOutputRoute {
        let route = AVAudioSession.sharedInstance().currentRoute

        if route.inputs.contains(where: isBluetoothPort) || route.outputs.contains(where: isBluetoothPort) {
            return .bluetooth
        }

        if route.inputs.contains(where: isHeadphonePort) || route.outputs.contains(where: isHeadphonePort) {
            return .headphones
        }

        guard let port = route.outputs.first else { return .other }
        switch port.portType {
        case .builtInSpeaker:
            return .builtInSpeaker
        case .builtInReceiver:
            return .builtInReceiver
        default:
            return .other
        }
    }

    static func shouldEnableVoiceProcessing() -> Bool {
        let route = currentOutputRoute()
        switch route {
        case .bluetooth, .headphones:
            return false
        case .builtInSpeaker, .builtInReceiver, .other:
            return true
        }
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

    nonisolated static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            if let channelData = buffer.floatChannelData {
                return mixDown(
                    frames: Int(buffer.frameLength),
                    channels: Int(buffer.format.channelCount)
                ) { channel, frame in
                    channelData[channel][frame]
                }
            }
        case .pcmFormatInt16:
            if let channelData = buffer.int16ChannelData {
                return mixDown(
                    frames: Int(buffer.frameLength),
                    channels: Int(buffer.format.channelCount)
                ) { channel, frame in
                    Float(channelData[channel][frame]) / Float(Int16.max)
                }
            }
        case .pcmFormatInt32:
            if let channelData = buffer.int32ChannelData {
                return mixDown(
                    frames: Int(buffer.frameLength),
                    channels: Int(buffer.format.channelCount)
                ) { channel, frame in
                    Float(channelData[channel][frame]) / Float(Int32.max)
                }
            }
        default:
            break
        }

        return convertToMonoFloat(buffer: buffer)
    }

    private static func preferredBluetoothInput(
        in session: AVAudioSession
    ) -> AVAudioSessionPortDescription? {
        session.availableInputs?.first(where: { isBluetoothPort($0) })
    }

    private nonisolated static func convertToMonoFloat(
        buffer: AVAudioPCMBuffer
    ) -> [Float]? {
        guard let analysisFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: buffer.format.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return nil }

        guard let converter = AVAudioConverter(
            from: buffer.format,
            to: analysisFormat
        ) else { return nil }

        let frameCapacity = AVAudioFrameCount(buffer.frameLength)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: analysisFormat,
            frameCapacity: frameCapacity
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

        guard error == nil,
              convertedBuffer.frameLength > 0,
              let channelData = convertedBuffer.floatChannelData?[0]
        else { return nil }

        let count = Int(convertedBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }

    private nonisolated static func mixDown(
        frames: Int,
        channels: Int,
        sampleAt: (_ channel: Int, _ frame: Int) -> Float
    ) -> [Float] {
        guard frames > 0, channels > 0 else { return [] }

        if channels == 1 {
            return (0..<frames).map { sampleAt(0, $0) }
        }

        let scale = 1 / Float(channels)
        return (0..<frames).map { frame in
            var sum: Float = 0
            for channel in 0..<channels {
                sum += sampleAt(channel, frame)
            }
            return sum * scale
        }
    }

    private static func isBluetoothPort(_ port: AVAudioSessionPortDescription) -> Bool {
        isBluetoothPortType(port.portType)
    }

    private static func isHeadphonePort(_ port: AVAudioSessionPortDescription) -> Bool {
        switch port.portType {
        case .headphones, .headsetMic:
            return true
        default:
            return false
        }
    }

    private static func isBluetoothPortType(_ type: AVAudioSession.Port) -> Bool {
        switch type {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return true
        default:
            return false
        }
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
