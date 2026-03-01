//
//  FluidTranscriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 25.02.2026.
//

@preconcurrency import AVFoundation
import CoreML
import FluidAudio
import Foundation

@Observable
final class FluidTranscriber {

    private(set) var displayText: String = ""

    private(set) var audioLevel: Float = 0

    private(set) var silenceProgress: Double = 0

    private(set) var state: RecordingState = .idle

    private(set) var finalTranscript: String = ""

    private var vadManager: VadManager?
    private var vadState: VadStreamState?
    private var asrManager: StreamingEouAsrManager?
    private var audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var isSpeechActive = false
    private var silenceStartDate: Date?
    private let vadSilenceDuration: TimeInterval = 3.0
    private var silenceTimer: Timer?
    private var recordingTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 60
    private var processingTask: Task<Void, Never>?
    private let sampleBuffer = AudioSampleBuffer()

    func loadModels() async throws {
        guard vadManager == nil || asrManager == nil else { return }

        if vadManager == nil {
            vadManager = try await VadManager(
                config: VadConfig(defaultThreshold: 0.75)
            )
        }

        if asrManager == nil {
            let manager = StreamingEouAsrManager(
                chunkSize: .ms160,
                eouDebounceMs: 1280
            )

            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let modelsDir = appSupport
                .appendingPathComponent("FluidAudio", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)

            _ = try await DownloadUtils.loadModels(
                .parakeetEou160,
                modelNames: [
                    ModelNames.ParakeetEOU.encoderFile,
                    ModelNames.ParakeetEOU.decoderFile,
                    ModelNames.ParakeetEOU.jointFile,
                ],
                directory: modelsDir,
                computeUnits: .cpuAndNeuralEngine
            )

            let modelDir = modelsDir.appendingPathComponent(
                Repo.parakeetEou160.folderName,
                isDirectory: true
            )
            try await manager.loadModels(modelDir: modelDir)
            asrManager = manager
        }
    }

    func start(skipAudioSessionSetup: Bool = false) async throws {
        if !skipAudioSessionSetup {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }

        try await loadModels()

        vadState = await vadManager!.makeStreamState()
        await asrManager!.reset()

        await asrManager!.setPartialCallback { [weak self] partial in
            Task { @MainActor in
                guard let self else { return }
                self.displayText = partial
            }
        }

        await asrManager!.setEouCallback { [weak self] transcript in
            Task { @MainActor in
                guard let self else { return }
                self.finalTranscript = transcript
                self.stop()
            }
        }

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        let tFormat = AudioUtilities.transcriptionFormat
        targetFormat = tFormat

        guard let converter = AVAudioConverter(
            from: nativeFormat,
            to: tFormat
        ) else {
            return
        }
        audioConverter = converter

        sampleBuffer.clear()

        let buffer = sampleBuffer
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] pcm, _ in
            guard let self else { return }
            let level = AudioUtilities.audioLevel(from: pcm)
            Task { @MainActor [weak self] in self?.audioLevel = level }
            if let samples = AudioUtilities.convertToMono16kHz(
                buffer: pcm,
                converter: converter,
                targetFormat: tFormat
            ) {
                buffer.append(samples)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        state = .recording
        audioLevel = 0
        silenceProgress = 0
        isSpeechActive = false
        silenceStartDate = nil
        displayText = ""
        finalTranscript = ""

        processingTask = Task { [weak self] in
            await self?.processAudioLoop()
        }

        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: maxRecordingDuration,
            repeats: false
        ) { [weak self] _ in
            self?.stop()
        }

        startSilenceMonitor()
    }

    func stop() {
        guard state == .recording else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        processingTask?.cancel()
        processingTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        silenceStartDate = nil
        state = .stopped
    }

    func reset() {
        displayText = ""
        finalTranscript = ""
        state = .idle
        audioLevel = 0
        silenceProgress = 0
        isSpeechActive = false
    }

    private func processAudioLoop() async {
        let chunkSize = VadManager.chunkSize

        while state == .recording {
            let chunk = sampleBuffer.drain(size: chunkSize)

            guard let chunk else {
                try? await Task.sleep(for: .milliseconds(10))
                continue
            }

            await processVadChunk(chunk)
        }
    }

    private func processVadChunk(_ chunk: [Float]) async {
        guard let vadManager, let currentState = vadState else { return }

        do {
            let result = try await vadManager.processStreamingChunk(
                chunk,
                state: currentState,
                config: .default,
                returnSeconds: true,
                timeResolution: 2
            )
            vadState = result.state

            if let event = result.event {
                switch event.kind {
                case .speechStart:
                    isSpeechActive = true
                    silenceStartDate = nil
                    silenceProgress = 0
                    await asrManager?.reset()
                case .speechEnd:
                    isSpeechActive = false
                    if silenceStartDate == nil {
                        silenceStartDate = Date()
                    }
                }
            }

            if isSpeechActive || result.probability > 0.5 {
                guard let tFormat = targetFormat else { return }
                guard let pcmBuffer = AVAudioPCMBuffer(
                    pcmFormat: tFormat,
                    frameCapacity: AVAudioFrameCount(chunk.count)
                ) else { return }
                pcmBuffer.frameLength = AVAudioFrameCount(chunk.count)
                chunk.withUnsafeBufferPointer { src in
                    pcmBuffer.floatChannelData![0].update(
                        from: src.baseAddress!,
                        count: chunk.count
                    )
                }
                _ = try await asrManager?.process(audioBuffer: pcmBuffer)
            }
        } catch {
            print("[FluidTranscriber] VAD/ASR error: \(error)")
        }
    }

    private func startSilenceMonitor() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            if self.isSpeechActive {
                self.silenceStartDate = nil
                self.silenceProgress = 0
            } else if let start = self.silenceStartDate {
                let elapsed = Date().timeIntervalSince(start)
                self.silenceProgress = min(1, elapsed / self.vadSilenceDuration)
                if elapsed >= self.vadSilenceDuration {
                    Task {
                        let transcript = try? await self.asrManager?.finish()
                        await MainActor.run {
                            if let transcript, !transcript.isEmpty {
                                self.finalTranscript = transcript
                            }
                            self.stop()
                        }
                    }
                }
            }
        }
    }
}
