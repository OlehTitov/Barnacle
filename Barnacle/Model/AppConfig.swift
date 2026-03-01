//
//  AppConfig.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

@Observable
final class AppConfig {

    var gatewayURL: String
    var gatewayToken: String
    var elevenLabsAPIKey: String
    var voiceID: String
    var ttsProvider: TTSProvider
    var ttsModel: TTSModel
    var ttsStability: TTSStability
    var ttsSimilarityBoost: Double
    var ttsStyle: Double
    var elevenLabsSpeed: Double
    var openAIVoice: OpenAIVoice
    var openAIVoiceInstructions: String
    var openAISpeed: Double
    var isOnboarded: Bool
    var transcriptionEngine: TranscriptionEngine
    var whisperModel: WhisperModel
    var openAIAPIKey: String
    var displayFont: GeistPixelFont
    var displayFontSize: Double
    var displayAllCaps: Bool
    var visualTheme: VisualTheme

    var showDebugMessages: Bool

    init() {
        self.ttsProvider = TTSProvider(
            rawValue: UserDefaults.standard.string(forKey: "ttsProvider") ?? ""
        ) ?? .elevenLabs
        self.ttsModel = TTSModel(
            rawValue: UserDefaults.standard.string(forKey: "ttsModel") ?? ""
        ) ?? .v3
        self.ttsStability = TTSStability(rawValue: UserDefaults.standard.double(forKey: "ttsStability")) ?? .natural
        self.ttsSimilarityBoost = UserDefaults.standard.object(forKey: "ttsSimilarityBoost") != nil
            ? UserDefaults.standard.double(forKey: "ttsSimilarityBoost") : 0.8
        self.ttsStyle = UserDefaults.standard.object(forKey: "ttsStyle") != nil
            ? UserDefaults.standard.double(forKey: "ttsStyle") : 0.4
        self.elevenLabsSpeed = UserDefaults.standard.object(forKey: "elevenLabsSpeed") != nil
            ? UserDefaults.standard.double(forKey: "elevenLabsSpeed") : 1.0
        self.openAIVoice = OpenAIVoice(
            rawValue: UserDefaults.standard.string(forKey: "openAIVoice") ?? ""
        ) ?? .coral
        self.openAIVoiceInstructions = UserDefaults.standard.string(forKey: "openAIVoiceInstructions") ?? ""
        self.openAISpeed = UserDefaults.standard.object(forKey: "openAISpeed") != nil
            ? UserDefaults.standard.double(forKey: "openAISpeed") : 1.0
        self.isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")
        self.transcriptionEngine = TranscriptionEngine(
            rawValue: UserDefaults.standard.string(forKey: "transcriptionEngine") ?? ""
        ) ?? .fluid
        self.whisperModel = WhisperModel(
            rawValue: UserDefaults.standard.string(forKey: "whisperModel") ?? ""
        ) ?? .whisper1
        self.displayFont = GeistPixelFont(
            rawValue: UserDefaults.standard.string(forKey: "displayFont") ?? ""
        ) ?? .square
        self.displayFontSize = UserDefaults.standard.object(forKey: "displayFontSize") != nil
            ? UserDefaults.standard.double(forKey: "displayFontSize") : 14
        self.displayAllCaps = UserDefaults.standard.object(forKey: "displayAllCaps") != nil
            ? UserDefaults.standard.bool(forKey: "displayAllCaps") : true
        self.visualTheme = VisualTheme(
            rawValue: UserDefaults.standard.string(forKey: "visualTheme") ?? ""
        ) ?? .midnight
        self.showDebugMessages = UserDefaults.standard.bool(forKey: "showDebugMessages")

        if let data = KeychainStore.load(key: "gatewayURL"),
           let value = String(data: data, encoding: .utf8)
        {
            self.gatewayURL = value
        } else if let legacy = UserDefaults.standard.string(forKey: "gatewayURL"), !legacy.isEmpty {
            self.gatewayURL = legacy
            if let data = legacy.data(using: .utf8) { KeychainStore.save(key: "gatewayURL", data: data) }
            UserDefaults.standard.removeObject(forKey: "gatewayURL")
        } else {
            self.gatewayURL = ""
        }

        if let tokenData = KeychainStore.load(key: "gatewayToken"),
           let token = String(data: tokenData, encoding: .utf8)
        {
            self.gatewayToken = token
        } else {
            self.gatewayToken = ""
        }

        if let keyData = KeychainStore.load(key: "elevenLabsAPIKey"),
           let key = String(data: keyData, encoding: .utf8)
        {
            self.elevenLabsAPIKey = key
        } else {
            self.elevenLabsAPIKey = ""
        }

        if let data = KeychainStore.load(key: "voiceID"),
           let value = String(data: data, encoding: .utf8)
        {
            self.voiceID = value
        } else if let legacy = UserDefaults.standard.string(forKey: "voiceID"), !legacy.isEmpty {
            self.voiceID = legacy
            if let data = legacy.data(using: .utf8) { KeychainStore.save(key: "voiceID", data: data) }
            UserDefaults.standard.removeObject(forKey: "voiceID")
        } else {
            self.voiceID = ""
        }

        if let keyData = KeychainStore.load(key: "openAIAPIKey"),
           let key = String(data: keyData, encoding: .utf8)
        {
            self.openAIAPIKey = key
        } else {
            self.openAIAPIKey = ""
        }
    }

    var ttsConfig: TTSConfig {
        TTSConfig(
            provider: ttsProvider,
            apiKey: elevenLabsAPIKey,
            voiceID: voiceID,
            modelID: ttsModel.rawValue,
            stability: ttsStability.rawValue,
            similarityBoost: ttsSimilarityBoost,
            style: ttsStyle,
            elevenLabsSpeed: elevenLabsSpeed,
            openAIAPIKey: openAIAPIKey,
            openAIVoice: openAIVoice.rawValue,
            openAIVoiceInstructions: openAIVoiceInstructions,
            openAISpeed: openAISpeed
        )
    }

    var hasTTS: Bool {
        switch ttsProvider {
        case .elevenLabs:
            !elevenLabsAPIKey.isEmpty && !voiceID.isEmpty
        case .openAI:
            !openAIAPIKey.isEmpty
        }
    }

    func save() {
        UserDefaults.standard.set(ttsProvider.rawValue, forKey: "ttsProvider")
        UserDefaults.standard.set(ttsModel.rawValue, forKey: "ttsModel")
        UserDefaults.standard.set(ttsStability.rawValue, forKey: "ttsStability")
        UserDefaults.standard.set(ttsSimilarityBoost, forKey: "ttsSimilarityBoost")
        UserDefaults.standard.set(ttsStyle, forKey: "ttsStyle")
        UserDefaults.standard.set(elevenLabsSpeed, forKey: "elevenLabsSpeed")
        UserDefaults.standard.set(openAIVoice.rawValue, forKey: "openAIVoice")
        UserDefaults.standard.set(openAIVoiceInstructions, forKey: "openAIVoiceInstructions")
        UserDefaults.standard.set(openAISpeed, forKey: "openAISpeed")
        UserDefaults.standard.set(isOnboarded, forKey: "isOnboarded")
        UserDefaults.standard.set(transcriptionEngine.rawValue, forKey: "transcriptionEngine")
        UserDefaults.standard.set(whisperModel.rawValue, forKey: "whisperModel")
        UserDefaults.standard.set(displayFont.rawValue, forKey: "displayFont")
        UserDefaults.standard.set(displayFontSize, forKey: "displayFontSize")
        UserDefaults.standard.set(displayAllCaps, forKey: "displayAllCaps")
        UserDefaults.standard.set(visualTheme.rawValue, forKey: "visualTheme")
        UserDefaults.standard.set(showDebugMessages, forKey: "showDebugMessages")

        if let data = gatewayURL.data(using: .utf8) {
            KeychainStore.save(key: "gatewayURL", data: data)
        }

        if let data = gatewayToken.data(using: .utf8) {
            KeychainStore.save(key: "gatewayToken", data: data)
        }

        if let data = elevenLabsAPIKey.data(using: .utf8) {
            KeychainStore.save(key: "elevenLabsAPIKey", data: data)
        }

        if let data = voiceID.data(using: .utf8) {
            KeychainStore.save(key: "voiceID", data: data)
        }

        if let data = openAIAPIKey.data(using: .utf8) {
            KeychainStore.save(key: "openAIAPIKey", data: data)
        }
    }
}
