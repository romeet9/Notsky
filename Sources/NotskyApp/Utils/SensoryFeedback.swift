import AppKit
import AVFoundation

public final class SensoryFeedback {
    private static var players: [String: AVAudioPlayer] = [:]
    private static let queue = DispatchQueue(label: "com.notsky.audio", qos: .userInteractive)
    
    // Pre-cache synthesized tactile click sounds
    private static let completeSoundData = generateMechanicalClick(frequency: 3600, bodyFreq: 950, duration: 0.024, attack: 0.0008, decay: 0.02, clickSharpness: 0.9)
    private static let uncheckSoundData  = generateMechanicalClick(frequency: 2900, bodyFreq: 800, duration: 0.018, attack: 0.0008, decay: 0.016, clickSharpness: 0.75)
    private static let addSoundData      = generateMechanicalClick(frequency: 4100, bodyFreq: 1150, duration: 0.028, attack: 0.0006, decay: 0.024, clickSharpness: 0.95)
    private static let deleteSoundData   = generateMechanicalClick(frequency: 2400, bodyFreq: 600, duration: 0.03, attack: 0.001, decay: 0.026, clickSharpness: 0.7)
    private static let buttonSoundData   = generateMechanicalClick(frequency: 3200, bodyFreq: 900, duration: 0.02, attack: 0.0008, decay: 0.018, clickSharpness: 0.8)
    private static let timerStartData    = generateMechanicalClick(frequency: 3800, bodyFreq: 1200, duration: 0.025, attack: 0.0006, decay: 0.022, clickSharpness: 0.9)
    private static let copySoundData     = generateMechanicalClick(frequency: 4400, bodyFreq: 1350, duration: 0.022, attack: 0.0005, decay: 0.018, clickSharpness: 0.95)
    private static let timerChimeData    = generateChime(notes: [(659.25, 0.0), (880.0, 0.12), (1046.5, 0.24)], totalDuration: 0.75)
    
    public static var soundEnabled: Bool = true
    public static var hapticsEnabled: Bool = true
    public static var chimeEnabled: Bool = true
    
    public static func playClick(data: Data, volume: Float = 0.85) {
        guard soundEnabled else { return }
        queue.async {
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = volume
                player.prepareToPlay()
                player.play()
                
                let key = UUID().uuidString
                players[key] = player
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    queue.async {
                        players.removeValue(forKey: key)
                    }
                }
            } catch {
                // Ignore fallback
            }
        }
    }
    
    private static func triggerHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
    
    public static func taskCompleted() {
        triggerHaptic(.alignment)
        playClick(data: completeSoundData, volume: 0.9)
    }
    
    public static func taskUnchecked() {
        triggerHaptic(.levelChange)
        playClick(data: uncheckSoundData, volume: 0.75)
    }
    
    public static func taskAdded() {
        triggerHaptic(.alignment)
        playClick(data: addSoundData, volume: 0.85)
    }
    
    public static func taskDeleted() {
        triggerHaptic(.levelChange)
        playClick(data: deleteSoundData, volume: 0.7)
    }
    
    public static func widgetSpawned() {
        triggerHaptic(.alignment)
        playClick(data: buttonSoundData, volume: 0.85)
    }
    
    public static func buttonClicked() {
        triggerHaptic(.generic)
        playClick(data: buttonSoundData, volume: 0.75)
    }
    
    public static func copied() {
        triggerHaptic(.alignment)
        playClick(data: copySoundData, volume: 0.9)
    }
    
    public static func timerStarted() {
        triggerHaptic(.alignment)
        playClick(data: timerStartData, volume: 0.9)
    }
    
    public static func timerPaused() {
        triggerHaptic(.levelChange)
        playClick(data: uncheckSoundData, volume: 0.75)
    }
    
    public static func timerFinished() {
        triggerHaptic(.alignment)
        guard chimeEnabled else { return }
        playClick(data: timerChimeData, volume: 0.9)
    }
    
    // Synthesizes a crisp, tactile mechanical switch click WAV in memory
    private static func generateMechanicalClick(
        frequency: Double,
        bodyFreq: Double,
        duration: Double,
        attack: Double,
        decay: Double,
        clickSharpness: Double
    ) -> Data {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)
        
        let twoPi = 2.0 * Double.pi
        
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            
            // Envelope: Fast exponential decay
            let envelope: Double
            if t < attack {
                envelope = t / attack
            } else {
                envelope = exp(-(t - attack) / decay)
            }
            
            // 1. Initial mechanical transient impulse / impact burst (0 - 3ms)
            var noise: Double = 0.0
            if t < 0.0035 {
                let noiseEnv = (1.0 - t / 0.0035)
                let randVal = Double.random(in: -1.0...1.0)
                noise = randVal * noiseEnv * clickSharpness
            }
            
            // 2. High crisp click leaf tone (e.g. 3000-4000Hz) with fast pitch drop
            let instantFreq = frequency * (1.0 + 0.6 * exp(-t / 0.004))
            let clickSine = sin(twoPi * instantFreq * t)
            
            // 3. Resonant switch housing body thock (lower frequency)
            let bodySine = sin(twoPi * bodyFreq * t) * 0.45
            
            // 4. Harmonic overtone
            let harmonicSine = sin(twoPi * (instantFreq * 1.5) * t) * 0.25
            
            // Mix
            let mixed = (noise * 0.45 + clickSine * 0.45 + bodySine + harmonicSine) * envelope
            
            // Clamp and convert to 16-bit PCM
            let clamped = max(-1.0, min(1.0, mixed))
            let pcmSample = Int16(clamped * 32767.0)
            samples.append(pcmSample)
        }
        
        // Build valid WAV File Data
        var data = Data()
        let byteRate = UInt32(sampleRate * 1.0 * 2.0)
        let blockAlign = UInt16(2)
        let subchunk2Size = UInt32(samples.count * 2)
        let chunkSize = 36 + subchunk2Size
        
        // RIFF Header
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: [UInt8]("WAVE".utf8))
        
        // fmt subchunk
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1 // PCM
        let numChannels: UInt16 = 1 // Mono
        let sampleRateU32 = UInt32(sampleRate)
        let bitsPerSample: UInt16 = 16
        
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRateU32.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data subchunk
        data.append(contentsOf: [UInt8]("data".utf8))
        data.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian) { Array($0) })
        
        // PCM Samples
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }
        
        return data
    }
    
    // Synthesizes a soft, harmonic celebration chime (arpeggiated sine waves with smooth bell envelopes)
    private static func generateChime(notes: [(freq: Double, start: Double)], totalDuration: Double) -> Data {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * totalDuration)
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)
        
        let twoPi = 2.0 * Double.pi
        
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            var sampleVal: Double = 0.0
            
            for note in notes {
                if t >= note.start {
                    let noteTime = t - note.start
                    let envelope = exp(-noteTime / 0.18)
                    let tone = sin(twoPi * note.freq * noteTime)
                    let overtone = sin(twoPi * (note.freq * 2.0) * noteTime) * 0.2
                    sampleVal += (tone + overtone) * envelope * 0.4
                }
            }
            
            let clamped = max(-1.0, min(1.0, sampleVal))
            let pcmSample = Int16(clamped * 32767.0)
            samples.append(pcmSample)
        }
        
        // Build valid WAV File Data
        var data = Data()
        let byteRate = UInt32(sampleRate * 1.0 * 2.0)
        let blockAlign = UInt16(2)
        let subchunk2Size = UInt32(samples.count * 2)
        let chunkSize = 36 + subchunk2Size
        
        // RIFF Header
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: [UInt8]("WAVE".utf8))
        
        // fmt subchunk
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1 // PCM
        let numChannels: UInt16 = 1 // Mono
        let sampleRateU32 = UInt32(sampleRate)
        let bitsPerSample: UInt16 = 16
        
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRateU32.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data subchunk
        data.append(contentsOf: [UInt8]("data".utf8))
        data.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian) { Array($0) })
        
        // PCM Samples
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }
        
        return data
    }
}

