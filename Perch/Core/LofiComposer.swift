import AVFoundation
import Foundation

/// Composes a random, seamless lofi loop: mellow seventh-chord pads, a lazy
/// bass, swung dusty drums, and vinyl crackle. Every call randomizes tempo,
/// key, progression, and groove, so no two rendered tracks are the same.
/// Every sound is envelope-bounded inside the loop, so it repeats click-free.
enum LofiComposer {

    private static let sampleRate = 44_100.0

    private struct ChordSpec {
        let degree: Int
        let intervals: [Int]
    }

    private static let maj7 = [0, 4, 7, 11]
    private static let min7 = [0, 3, 7, 10]
    private static let dom7 = [0, 4, 7, 10]

    private static let progressions: [[ChordSpec]] = [
        [ChordSpec(degree: 2, intervals: min7), ChordSpec(degree: 7, intervals: dom7),
         ChordSpec(degree: 0, intervals: maj7), ChordSpec(degree: 9, intervals: min7)],
        [ChordSpec(degree: 0, intervals: maj7), ChordSpec(degree: 9, intervals: min7),
         ChordSpec(degree: 5, intervals: maj7), ChordSpec(degree: 7, intervals: dom7)],
        [ChordSpec(degree: 9, intervals: min7), ChordSpec(degree: 5, intervals: maj7),
         ChordSpec(degree: 0, intervals: maj7), ChordSpec(degree: 7, intervals: dom7)],
        [ChordSpec(degree: 5, intervals: maj7), ChordSpec(degree: 4, intervals: min7),
         ChordSpec(degree: 2, intervals: min7), ChordSpec(degree: 0, intervals: maj7)],
    ]

    static func render(to url: URL) -> Bool {
        let bpm = Double(Int.random(in: 72...88))
        let beat = 60.0 / bpm
        let bars = 8
        let beatsPerBar = 4
        let loopSeconds = Double(bars * beatsPerBar) * beat
        let frames = Int((sampleRate * loopSeconds).rounded())
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)

        let key = Int.random(in: 0..<12)
        let progression = progressions.randomElement()!
        let chordSeconds = Double(2 * beatsPerBar) * beat

        renderPads(progression: progression, key: key, chordSeconds: chordSeconds,
                   into: &left, and: &right)
        renderBass(progression: progression, key: key, beat: beat, bars: bars,
                   frames: frames, into: &left, and: &right)
        renderDrums(beat: beat, bars: bars, frames: frames, into: &left, and: &right)
        renderVinyl(frames: frames, into: &left, and: &right)

        normalize(&left, &right, toPeak: 0.4)
        return write(left: left, right: right, frames: frames, to: url)
    }

    // MARK: Pads

    private static func renderPads(
        progression: [ChordSpec], key: Int, chordSeconds: Double,
        into left: inout [Float], and right: inout [Float]
    ) {
        let toneGains: [Float] = [0.9, 0.7, 0.65, 0.5]
        for (chordIndex, chord) in progression.enumerated() {
            let start = Double(chordIndex) * chordSeconds
            for (toneIndex, interval) in chord.intervals.enumerated() {
                let frequency = toneFrequency(key + chord.degree + interval)
                for (pairIndex, detune) in [-0.0018, 0.0018].enumerated() {
                    let wide: Float = 0.78
                    let narrow: Float = 0.55
                    let leftFirst = (toneIndex + pairIndex).isMultiple(of: 2)
                    addPadTone(
                        frequency: frequency * (1 + detune),
                        window: start..<(start + chordSeconds),
                        gain: toneGains[toneIndex] * (pairIndex == 0 ? 0.5 : 0.32),
                        panLeft: leftFirst ? wide : narrow,
                        panRight: leftFirst ? narrow : wide,
                        into: &left, and: &right
                    )
                }
            }
        }
    }

    private static func addPadTone(
        frequency: Double, window: Range<Double>, gain: Float,
        panLeft: Float, panRight: Float,
        into left: inout [Float], and right: inout [Float]
    ) {
        let attack = 0.5
        let release = 0.9
        let startFrame = Int(window.lowerBound * sampleRate)
        let endFrame = min(left.count, Int(window.upperBound * sampleRate))
        guard startFrame < endFrame else { return }
        let phase = Double.random(in: 0..<(2 * .pi))
        let tremoloRate = Double.random(in: 0.15...0.35)
        let tremoloPhase = Double.random(in: 0..<(2 * .pi))
        let twoPi = 2.0 * Double.pi
        for frame in startFrame..<endFrame {
            let t = Double(frame) / sampleRate - window.lowerBound
            let untilEnd = window.upperBound - window.lowerBound - t
            var envelope = 1.0
            if t < attack { envelope = 0.5 - 0.5 * cos(.pi * t / attack) }
            if untilEnd < release { envelope *= 0.5 - 0.5 * cos(.pi * untilEnd / release) }
            envelope *= 0.85 + 0.15 * sin(twoPi * tremoloRate * t + tremoloPhase)
            let sample = Float(sin(twoPi * frequency * t + phase) * envelope) * gain
            left[frame] += sample * panLeft
            right[frame] += sample * panRight
        }
    }

    // MARK: Bass

    private static func renderBass(
        progression: [ChordSpec], key: Int, beat: Double, bars: Int, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let bounceBeat = [2.0, 2.5, 3.0].randomElement()!
        let bounceChance = Double.random(in: 0.3...0.8)
        for bar in 0..<bars {
            let chord = progression[bar / 2]
            let frequency = toneFrequency(key + chord.degree) / 2
            let barStart = Double(bar) * 4 * beat
            addBassNote(frequency: frequency, start: barStart, beat: beat,
                        gain: 0.5, frames: frames, into: &left, and: &right)
            if Double.random(in: 0...1) < bounceChance {
                addBassNote(frequency: frequency, start: barStart + bounceBeat * beat, beat: beat,
                            gain: 0.35, frames: frames, into: &left, and: &right)
            }
        }
    }

    private static func addBassNote(
        frequency: Double, start: Double, beat: Double, gain: Float, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let length = 1.6 * beat
        let startFrame = Int(start * sampleRate)
        let endFrame = min(frames, Int((start + length) * sampleRate))
        guard startFrame < endFrame else { return }
        let twoPi = 2.0 * Double.pi
        for frame in startFrame..<endFrame {
            let t = Double(frame) / sampleRate - start
            var envelope = exp(-t / (0.45 * beat))
            if t < 0.008 { envelope *= t / 0.008 }
            envelope *= clippedFade(frame: frame, endFrame: endFrame)
            let tone = sin(twoPi * frequency * t) + 0.3 * sin(twoPi * 2 * frequency * t)
            let sample = Float(tone * envelope) * gain
            left[frame] += sample
            right[frame] += sample
        }
    }

    // MARK: Drums

    private static func renderDrums(
        beat: Double, bars: Int, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let level = Double.random(in: 0.5...0.85)
        let swing = Double.random(in: 0.54...0.62)
        let midKickChance = Double.random(in: 0.4...0.8)
        let hatSkipChance = Double.random(in: 0.05...0.2)

        for bar in 0..<bars {
            let barStart = Double(bar) * 4 * beat
            addKick(at: barStart, level: level, frames: frames, into: &left, and: &right)
            if Double.random(in: 0...1) < midKickChance {
                addKick(at: barStart + 2.5 * beat, level: level * 0.8, frames: frames, into: &left, and: &right)
            }
            addSnare(at: barStart + 1 * beat, level: level, frames: frames, into: &left, and: &right)
            addSnare(at: barStart + 3 * beat, level: level, frames: frames, into: &left, and: &right)
            for eighth in 0..<8 {
                if Double.random(in: 0...1) < hatSkipChance { continue }
                var time = barStart + Double(eighth) * 0.5 * beat
                let isOffbeat = !eighth.isMultiple(of: 2)
                if isOffbeat { time += (swing - 0.5) * beat }
                let velocity = (isOffbeat ? 0.10 : 0.16) * Double.random(in: 0.7...1.0)
                addHat(at: time, level: level * velocity, frames: frames, into: &left, and: &right)
            }
        }
    }

    private static func addKick(
        at start: Double, level: Double, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let startFrame = Int(start * sampleRate)
        let endFrame = min(frames, startFrame + Int(0.3 * sampleRate))
        guard startFrame < endFrame else { return }
        var phase = 0.0
        for frame in startFrame..<endFrame {
            let t = Double(frame - startFrame) / sampleRate
            let frequency = 45 + 75 * exp(-t / 0.05)
            phase += 2 * .pi * frequency / sampleRate
            var envelope = exp(-t / 0.12) * level * 0.5
            if t < 0.002 { envelope *= t / 0.002 }
            envelope *= clippedFade(frame: frame, endFrame: endFrame)
            let sample = Float(sin(phase) * envelope)
            left[frame] += sample
            right[frame] += sample
        }
    }

    private static func addSnare(
        at start: Double, level: Double, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let startFrame = Int(start * sampleRate)
        let endFrame = min(frames, startFrame + Int(0.18 * sampleRate))
        guard startFrame < endFrame else { return }
        var lowState = 0.0
        var highState = 0.0
        let lowAlpha = onePoleAlpha(cutoff: 5_500)
        let highAlpha = onePoleAlpha(cutoff: 900)
        let twoPi = 2.0 * Double.pi
        for frame in startFrame..<endFrame {
            let t = Double(frame - startFrame) / sampleRate
            let white = Double.random(in: -1...1)
            lowState += lowAlpha * (white - lowState)
            highState += highAlpha * (white - highState)
            let band = lowState - highState
            var envelope = exp(-t / 0.055) * level * 0.55
            envelope *= clippedFade(frame: frame, endFrame: endFrame)
            let thump = 0.3 * sin(twoPi * 185 * t) * exp(-t / 0.03)
            let sample = Float((band * 2.2 + thump) * envelope)
            left[frame] += sample
            right[frame] += sample
        }
    }

    private static func addHat(
        at start: Double, level: Double, frames: Int,
        into left: inout [Float], and right: inout [Float]
    ) {
        let startFrame = Int(start * sampleRate)
        let endFrame = min(frames, startFrame + Int(0.05 * sampleRate))
        guard startFrame < endFrame else { return }
        var previous = 0.0
        let pan = Float.random(in: 0.4...0.6)
        for frame in startFrame..<endFrame {
            let t = Double(frame - startFrame) / sampleRate
            let white = Double.random(in: -1...1)
            let high = white - previous
            previous = white
            var envelope = exp(-t / 0.014) * level
            envelope *= clippedFade(frame: frame, endFrame: endFrame)
            let sample = Float(high * envelope)
            left[frame] += sample * (1 - pan)
            right[frame] += sample * pan
        }
    }

    // MARK: Vinyl

    private static func renderVinyl(
        frames: Int, into left: inout [Float], and right: inout [Float]
    ) {
        var b0 = 0.0, b1 = 0.0, b2 = 0.0
        var filtered = 0.0
        let alpha = onePoleAlpha(cutoff: 1_800)
        let hissGain = 0.006
        for frame in 0..<frames {
            let white = Double.random(in: -1...1)
            b0 = 0.99765 * b0 + white * 0.0990460
            b1 = 0.96300 * b1 + white * 0.2965164
            b2 = 0.57000 * b2 + white * 1.0526913
            let pink = b0 + b1 + b2 + white * 0.1848
            filtered += alpha * (pink - filtered)
            let hiss = Float(filtered * hissGain)
            left[frame] += hiss
            right[frame] += hiss
        }

        let meanGap = Double.random(in: 0.5...1.4)
        var popTime = Double.random(in: 0...meanGap)
        let loopSeconds = Double(frames) / sampleRate
        while popTime < loopSeconds - 0.01 {
            let startFrame = Int(popTime * sampleRate)
            let endFrame = min(frames, startFrame + Int(0.004 * sampleRate))
            let amplitude = Double.random(in: 0.04...0.15)
            let pan = Float.random(in: 0.3...0.7)
            for frame in startFrame..<endFrame {
                let t = Double(frame - startFrame) / sampleRate
                let sample = Float(Double.random(in: -1...1) * amplitude * exp(-t / 0.001))
                left[frame] += sample * (1 - pan)
                right[frame] += sample * pan
            }
            popTime += -log(Double.random(in: 0.0001...1)) * meanGap
        }
    }

    // MARK: Helpers

    /// Frequency for a semitone offset, folded into a mellow mid register.
    private static func toneFrequency(_ semitone: Int) -> Double {
        var frequency = 220.0 * pow(2.0, Double(semitone) / 12.0)
        while frequency > 350 { frequency /= 2 }
        while frequency < 175 { frequency *= 2 }
        return frequency
    }

    /// Forces the last ~7 ms of an event clipped by the loop end to fade out,
    /// keeping the loop point silent for that event.
    private static func clippedFade(frame: Int, endFrame: Int) -> Double {
        min(1.0, Double(endFrame - 1 - frame) / 300.0)
    }

    private static func onePoleAlpha(cutoff: Double) -> Double {
        1 - exp(-2 * .pi * cutoff / sampleRate)
    }

    private static func normalize(_ left: inout [Float], _ right: inout [Float], toPeak peak: Float) {
        var maxSample: Float = 0.0001
        for frame in 0..<left.count {
            maxSample = max(maxSample, abs(left[frame]), abs(right[frame]))
        }
        let scale = peak / maxSample
        for frame in 0..<left.count {
            left[frame] *= scale
            right[frame] *= scale
        }
    }

    private static func write(left: [Float], right: [Float], frames: Int, to url: URL) -> Bool {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else { return false }
        left.withUnsafeBufferPointer { channels[0].update(from: $0.baseAddress!, count: frames) }
        right.withUnsafeBufferPointer { channels[1].update(from: $0.baseAddress!, count: frames) }
        buffer.frameLength = AVAudioFrameCount(frames)
        do {
            try? FileManager.default.removeItem(at: url)
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return true
        } catch {
            return false
        }
    }
}
