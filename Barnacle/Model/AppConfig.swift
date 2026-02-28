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
    var ttsModel: TTSModel
    var ttsStability: TTSStability
    var ttsSimilarityBoost: Double
    var ttsStyle: Double
    var isOnboarded: Bool
    var transcriptionEngine: TranscriptionEngine
    var whisperModel: WhisperModel
    var openAIAPIKey: String

    init() {
        self.gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
        self.voiceID = UserDefaults.standard.string(forKey: "voiceID") ?? ""
        self.ttsModel = TTSModel(
            rawValue: UserDefaults.standard.string(forKey: "ttsModel") ?? ""
        ) ?? .v3
        self.ttsStability = TTSStability(rawValue: UserDefaults.standard.double(forKey: "ttsStability")) ?? .natural
        self.ttsSimilarityBoost = UserDefaults.standard.object(forKey: "ttsSimilarityBoost") != nil
            ? UserDefaults.standard.double(forKey: "ttsSimilarityBoost") : 0.8
        self.ttsStyle = UserDefaults.standard.object(forKey: "ttsStyle") != nil
            ? UserDefaults.standard.double(forKey: "ttsStyle") : 0.4
        self.isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")
        self.transcriptionEngine = TranscriptionEngine(
            rawValue: UserDefaults.standard.string(forKey: "transcriptionEngine") ?? ""
        ) ?? .fluid
        self.whisperModel = WhisperModel(
            rawValue: UserDefaults.standard.string(forKey: "whisperModel") ?? ""
        ) ?? .whisper1

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

        if let keyData = KeychainStore.load(key: "openAIAPIKey"),
           let key = String(data: keyData, encoding: .utf8)
        {
            self.openAIAPIKey = key
        } else {
            self.openAIAPIKey = ""
        }
    }

    func save() {
        UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL")
        UserDefaults.standard.set(voiceID, forKey: "voiceID")
        UserDefaults.standard.set(ttsModel.rawValue, forKey: "ttsModel")
        UserDefaults.standard.set(ttsStability.rawValue, forKey: "ttsStability")
        UserDefaults.standard.set(ttsSimilarityBoost, forKey: "ttsSimilarityBoost")
        UserDefaults.standard.set(ttsStyle, forKey: "ttsStyle")
        UserDefaults.standard.set(isOnboarded, forKey: "isOnboarded")
        UserDefaults.standard.set(transcriptionEngine.rawValue, forKey: "transcriptionEngine")
        UserDefaults.standard.set(whisperModel.rawValue, forKey: "whisperModel")

        if let data = gatewayToken.data(using: .utf8) {
            KeychainStore.save(key: "gatewayToken", data: data)
        }

        if let data = elevenLabsAPIKey.data(using: .utf8) {
            KeychainStore.save(key: "elevenLabsAPIKey", data: data)
        }

        if let data = openAIAPIKey.data(using: .utf8) {
            KeychainStore.save(key: "openAIAPIKey", data: data)
        }
    }
}
