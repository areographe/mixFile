//
//  ExtAudioReader.swift
//  MixFile
//
//  Created by David O'Neill on 5/9/18.
//  Copyright © 2018 cinematicstrings. All rights reserved.
//

import Foundation
import AVFoundation

class ExtAudioReader {
    let audioFile: ExtAudioFileRef
    let processingFormat: AVAudioFormat
    init(url: URL, processingFormat: AVAudioFormat) throws {

        if !processingFormat.isStandard {
            fatalError()
        }

        var ref: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(url as CFURL, &ref)
        guard let f = ref, status == noErr else {
            throw NSError.withOSStatus(status: status)
        }
        self.processingFormat = processingFormat
        audioFile = f

        var asbd = processingFormat.streamDescription.pointee
        let propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, propSize, &asbd)
        if status != noErr {
            throw NSError.withOSStatus(status: status)
        }
    }
    func read(into buffer: AVAudioPCMBuffer) throws {
        if processingFormat != buffer.format {
            fatalError()
        }
        var frames = UInt32(buffer.frameCapacity)
        buffer.frameLength = frames
        let status = ExtAudioFileRead(audioFile, &frames, buffer.mutableAudioBufferList)
        if status != noErr {
            throw NSError.withOSStatus(status: status)
        }
        buffer.frameLength = frames
    }

    private var _duration: Double?
    var duration: Double {
        if let d = _duration {
            return d
        }
        var frames: Int64 = 0
        var propSize = UInt32(MemoryLayout<Int64>.size)
        var status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &propSize, &frames)
        if status != noErr {
            fatalError()
        }
        var asbd = AudioStreamBasicDescription()
        propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &propSize, &asbd)
        if status != noErr {
            fatalError()
        }
        let d = asbd.mSampleRate * Double(frames)
        _duration = d
        return d
    }
    deinit {
        ExtAudioFileDispose(audioFile)
    }
}
