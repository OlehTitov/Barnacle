//
//  AudioSampleBuffer.swift
//  Barnacle
//
//  Created by Oleh Titov on 01.03.2026.
//

import Foundation

final class AudioSampleBuffer: @unchecked Sendable {

    private let lock = NSLock()

    nonisolated(unsafe) private var samples: [Float] = []

    nonisolated func append(_ newSamples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        samples.append(contentsOf: newSamples)
    }

    nonisolated func drain(size: Int) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        guard samples.count >= size else { return nil }
        let chunk = Array(samples.prefix(size))
        samples.removeFirst(size)
        return chunk
    }

    nonisolated func clear() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll()
    }
}
