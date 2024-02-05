//
//  Audio.swift
//  MinuteOfSilence
//
//  Created by Wladislaw Derevianko on 07.01.2024.
//

import Foundation
import AVFAudio
import Combine

var isPlaying = false
var errorPublisher = PassthroughSubject<Error, Never>()

enum AudioError: LocalizedError {
	case noOutput, badSampleRate, badOutputFormat, memoryAllocation
	
	var errorDescription: String? {
		switch self {
		case .noOutput: return String(localized: "Cannot access speaker")
		case .badSampleRate: return String(localized: "Bad speaker audio parameters")
		case .badOutputFormat: return String(localized: "Cannot process audio format")
		case .memoryAllocation: return String(localized: "Failed memory allocation")
		}
	}
}

func startSound() -> Bool {
	audioEngine?.stop()
	
	// mixer is not used
	let engine = AVAudioEngine()
	if engine.outputNode.numberOfOutputs == 0 {
		errorPublisher.send(AudioError.noOutput)
		return false
	}
	let playerNode = AVAudioPlayerNode()
	engine.attach(playerNode)
	let formatOfOutput = engine.outputNode.outputFormat(forBus: 0)
	let rate = formatOfOutput.sampleRate
	if rate <= 0 {
		errorPublisher.send(AudioError.badSampleRate)
		return false
	}
	
	// make a similar format with single channel
	guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
	else {
		errorPublisher.send(AudioError.badSampleRate)
		return false
	}
	engine.connect(playerNode, to: engine.outputNode, format: format)
	audioEngine = engine
	bangPlayerNode = playerNode
	prepareBangBuffer(format: format)
	
	do {
		try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
		try engine.start()
		return true
	} catch {
		errorPublisher.send(error)
		return false
	}
	
}

func playSoundBuffer() {
	guard let buffer = bangBuffer, let player = bangPlayerNode else { return }
	player.scheduleBuffer(buffer)
	if !player.isPlaying {
		player.play()
	}
}

func playDeclaration() {
	let url = Bundle.main.url(forResource: "declare_silence", withExtension: "m4a")
	guard let url = url, let player = bangPlayerNode else { return }
	do {
		let file = try AVAudioFile(forReading: url)
		player.scheduleFile(file, at: nil) {
			//print("-- the declaration is done --")
		}
		if !player.isPlaying {
			player.play()
		}
	} catch {
		//print("-- error reading declaration audio --")
		errorPublisher.send(error)
	}
	
}

func stopSound() {
	bangPlayerNode?.stop()
	audioEngine?.stop()
	do {
		try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
		audioEngine = nil
		bangPlayerNode = nil
	} catch {
		errorPublisher.send(error)
	}
}

fileprivate var ablX: AudioBufferList?

fileprivate func prepareBangBuffer(format: AVAudioFormat) {
	let dt = 0.040 // 40 milliseconds
	let n = AVAudioFrameCount(dt * format.sampleRate)
	let bufferLength = 3 * n
	
	let pData = UnsafeMutablePointer<Float>.allocate(capacity: Int(bufferLength))
	
	let byteSize = UInt32(MemoryLayout<Float>.size) * bufferLength
	let buf = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: pData)
	let abl = AudioBufferList(mNumberBuffers: 1, mBuffers: (buf))
	ablX = abl
	let trialBuffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: &ablX!) { ablPtr in
		ablPtr.pointee.mBuffers.mData?.deallocate()
	}
	guard let buffer = trialBuffer,
		  let pChannnelsData = buffer.floatChannelData else {
		errorPublisher.send(AudioError.badOutputFormat)
		return
	}
	
	let ntau = AVAudioFrameCount(dt * format.sampleRate * (2 - sqrt(3.0)))
	let frequency = 400.0 // 400 Hz
	let omega = 2 * Double.pi * frequency / format.sampleRate
	
	let pDataMono = pChannnelsData[0]
	
	// fill the first part of buffer a(t) = 1 - ((i - n) / n)^2
	let tauIndex = n + ntau
	let floatN = Float(n)
	for i in 0..<tauIndex {
		let x = (Float(i) / floatN) - 1 // amplitude
		pDataMono[Int(i)] = (1.0 - x * x) * Float(sin(omega * Double(i)))
	}
	
	// fill the remaining part of buffer
	let startingX = Float(ntau) / floatN
	let slope = (1 - startingX * startingX) / Float(bufferLength - tauIndex)
	
	for i in tauIndex..<bufferLength {
		let a = Float(bufferLength - i) * slope
		pDataMono[Int(i)] = a * Float(sin(omega * Double(i)))
	}
	bangBuffer = buffer
}


fileprivate var audioEngine: AVAudioEngine?
fileprivate var bangPlayerNode: AVAudioPlayerNode?
fileprivate var bangBuffer: AVAudioPCMBuffer?
