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
    var hooksToken: String
    var elevenLabsAPIKey: String
    var voiceID: String
    var isOnboarded: Bool

    init() {
        self.gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
        self.voiceID = UserDefaults.standard.string(forKey: "voiceID") ?? ""
        self.isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")

        if let tokenData = KeychainStore.load(key: "hooksToken"),
           let token = String(data: tokenData, encoding: .utf8)
        {
            self.hooksToken = token
        } else {
            self.hooksToken = ""
        }

        if let keyData = KeychainStore.load(key: "elevenLabsAPIKey"),
           let key = String(data: keyData, encoding: .utf8)
        {
            self.elevenLabsAPIKey = key
        } else {
            self.elevenLabsAPIKey = ""
        }
    }

    func save() {
        UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL")
        UserDefaults.standard.set(voiceID, forKey: "voiceID")
        UserDefaults.standard.set(isOnboarded, forKey: "isOnboarded")

        if let data = hooksToken.data(using: .utf8) {
            KeychainStore.save(key: "hooksToken", data: data)
        }

        if let data = elevenLabsAPIKey.data(using: .utf8) {
            KeychainStore.save(key: "elevenLabsAPIKey", data: data)
        }
    }
}
