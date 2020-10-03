//
//  AVAudioPCMBufferExt.swift
//  MixFile
//
//  Created by David O'Neill on 5/9/18.
//  Copyright © 2018 cinematicstrings. All rights reserved.
//  Last modified by Luke Midworth 2020

import Foundation
import AVFoundation
import Accelerate

extension AVAudioPCMBuffer { // LM 9JUL added delay float to mixIn
    func mixIn(other: AVAudioPCMBuffer, volume: Float, pan: Float, delay: Float, phaseInv: Bool) {
        guard let buff = floatChannelData,
            var oBuff = other.floatChannelData,
            format == other.format,
            other.frameLength <= frameCapacity else {
                return
        }
        
        // print("audio of framelength \(other.frameLength) and audioseize")
        
/* Luke's notes as of 29 SEP:
the behaviour of the panning algorithm in this tool does not match
the panning algorithm used by the Cubase DAW.
Alex has assessed the difference in volume between the output of
the tool and the DAW and charted them in Excel.
         
These are imported below: ignore until panning algorithm fixed.

 */
/*
        // 1. Create two arrays of decibel differences based on Alex's CSV spreadsheet.
        // PanCorrectionL is the difference in volume required to get the left channel to phase cancel in Cubase
        let PanCorrectionL = [0.07, 0.13, 0.2, 0.26, 0.33, 0.39, 0.45, 0.51, 0.57, 0.63, 0.69, 0.75, 0.8, 0.86, 0.91, 0.96, 1.02, 1.07, 1.12, 1.17, 1.22, 1.27, 1.31, 1.36, 1.41, 1.45, 1.5, 1.54, 1.58, 1.63, 1.67, 1.71, 1.75, 1.79, 1.83, 1.86, 1.9, 1.94, 1.97, 2.01, 2.04, 2.08, 2.11, 2.14, 2.17, 2.2, 2.23, 2.26, 2.29, 2.32, 2.35, 2.38, 2.4, 2.43, 2.46, 2.48, 2.5, 2.53, 2.55, 2.57, 2.6, 2.62, 2.64, 2.66, 2.68, 2.7, 2.71, 2.73, 2.75, 2.77, 2.78, 2.8, 2.81, 2.83, 2.84, 2.85, 2.87, 2.88, 289, 2.9, 2.91, 2.92, 2.93, 2.94, 2.95, 2.96, 2.97, 2.97, 2.98, 2.98, 2.99, 2.99, 3, 3, 3, 3.01, 3.01, 3.01, 3.01, 3.01]
        // PanCorrectionR is the difference in volume required to get the right channel to phase cancel in Cubase
        let PanCorrectionR = [-0.07, -0.14, -0.21, -0.28, -0.35, -0.43, -0.5, -0.58, -0.66, -0.74, -0.82, -0.9, -0.99, -1.07, -1.15, -1.24, -1.33, -1.42, -1.51, -1.61, -1.7, -1.8, -1.9, -1.99, -2.1, -2.2, -2.3, -2.41, -2.52, -2.63, -2.74, -2.86, -2.97, -3.09, -3.21, -3.33, -3.46, -3.59, -3.72, -3.85, -3.99, -4.12, -4.26, -4.41, -4.55, -4.7, -4.85, -5.01, -5.17, -5.33, -5.5, -5.67, -5.85, -6.02, -6.2, -6.39, -6.58, -6.78, -6.99, -7.18, -7.4, -7.62, -7.84, -8.07, -8.31, -8.57, -8.81, -9.08, -9.35, -9.63, -9.92, -10.2, -10.5, -10.9, -11.1, -11.5, -11.9, -12.3, -12.7, -13.12, -13.6, -14, -14.5, -15, -15.6, -16.1, -16.8, -17.5, -18.2, -19.1, -20, -21, -22.2, -23.6, -25.1, -27, -29.6, -33, -39.1, 0]
*/

        let bufferLength = self.getLength(buffer: other)
        
        var otherFrameLength = other.frameLength
        
        var newBuffer = other
    
        if phaseInv {
            other.invertBufferPhase()
        }
                
        // delay in milliseconds
        //let delay_: Double = Double(delay*1000)
        
        if delay != 0 {
            
            if delay < 0 {
                let trimmedSeconds = Double(-1 * delay)
                // print(bufferLength, trimmedSeconds, bufferLength > trimmedSeconds)
                if bufferLength > trimmedSeconds {
                    if let trimmedBuffer = self.deleteBuffers(from: other, ofSeconds: trimmedSeconds) {
                        //print("Deleted time interval \(self.getLength(buffer: trimmedBuffer)) from \(self.getLength(buffer: other))")
                        newBuffer = trimmedBuffer
                        if let oBuff2 = newBuffer.floatChannelData {
                            oBuff = oBuff2
                            otherFrameLength = newBuffer.frameLength
                        }
                    }
                   // other.trimBuffers(by: trimmedSeconds)
                   // print("Trimmed time interval \(self.getLength(buffer: other)) from \(self.getLength(buffer: other))")
                }
            }
            else {
                if let silenceBuffer = self.silenceBuffer(ofLengthInSeconds: Double(delay), format:format) {
                    if let mergedBuffer = self.concatBuffers(prependThis: silenceBuffer, to: other) {
                        //print("Merged silence buffer of length \(self.getLength(buffer: silenceBuffer)) with \(self.getLength(buffer: other)) = \(self.getLength(buffer: mergedBuffer))")
                        newBuffer = mergedBuffer
                        if let oBuff2 = newBuffer.floatChannelData {
                            oBuff = oBuff2
                            otherFrameLength = newBuffer.frameLength
                        }
                    }
                }
                
                /*if let newOther = other.prependBufferWithSilence(of: Double(delay_)) {
                    print("New time interval is \(self.getLength(buffer: newOther))")
                    if let oBuff2 = newOther.floatChannelData {
                        oBuff = oBuff2
                        otherFrameLength = newOther.frameLength
                    }
                }*/
            }
        }
        
        let p = .pi * 0.5 * pan;
        var l = volume * cos(p)
        var r = volume * sin(p)
        /*
        // 2. Find the absolute integer panning value
        let absolutePan = abs((pan * 200) - 100)
        let roundedPan = Int(round(absolutePan))

        var tempPanCorrectionL: Double = 0
        var tempPanCorrectionR: Double = 0
        
        /*
        print("Pan value:")
        print(String(pan))
        print("Absolute pan value:")
        print(String(absolutePan))
        */
        
        // 3. check if the panning is neutral or skewed left or right, in that order
        if absolutePan == 0 {
            tempPanCorrectionL = 0
            tempPanCorrectionR = 0
            //print("Pan polarity: 0, centred")
        } else { // every 'subscript' index is one less (- 1) because absolutePan is (+/-)1 - 100, but the array is 0-indexed
            if absolutePan != (pan * 200) - 100 { // negative pan value means skewed left, which means we use the array values unchanged from Alex's CSV
                
                tempPanCorrectionL = PanCorrectionL[roundedPan - 1]
                tempPanCorrectionR = PanCorrectionR[roundedPan - 1]
                //print("Pan polarity: negative, left ", tempPanCorrectionL, ", ", tempPanCorrectionR)
            } else { // positive pan value means skewed right, which means we have to invert the array values from Alex's CSV by multiplying by -1
                tempPanCorrectionL = PanCorrectionL[roundedPan - 1] * -1
                tempPanCorrectionR = PanCorrectionR[roundedPan - 1] * -1
                //print("Pan polarity: positive, right", tempPanCorrectionL, ", ", tempPanCorrectionR)
            }
        }
        print(tempPanCorrectionL, " ", tempPanCorrectionR)
        // 4. add the values (original +/- or inverted -/+ for left and right, respectively) to the new volume being created
        print("volume ORIGINAL (amplitude)", String(volume), ", volume ORIGINAL (decibels)", String(volume.toDecibels()), "symmetrical? ", String(volume.toDecibels().toAmplitude()))
*/
/*        let volumeL = volume * cos(p)
        //var l = ( (volume + Float(tempPanCorrectionL).toAmplitude()) * cos(p) )
        print("volumeL", String(volumeL))
        let volumeR = volume * sin(p)
        print("volumeR", String(volumeR))
        let lTemp = volumeL.toDecibels() //+ Float(tempPanCorrectionL)
        print("volumeL to decibels plus correction", String(lTemp))
        let rTemp = volumeR.toDecibels() //+ Float(tempPanCorrectionR)
        print("volumeR to decibels plus correction", String(rTemp))
*/
        // print("volumeR to decibels plus correction (amplitude)", String(r))
        // var r = ( (volume + Float(tempPanCorrectionR).toAmplitude()) * sin(p) )
        // print("original volume: ", String(volume.toDecibels()))
        // print("left final volume: ", String(volumeL), ", right final volume: ", String(volumeR))
        /* debug printing
        
        print(String(volume), " + ", String(tempPanCorrectionL), " * cos(", String(p), ") = ", String(volume + Float(tempPanCorrectionL)), " * ", String(cos(p)), " = ", String(l))
        
        print(String(volume), " + ", String(tempPanCorrectionR), " * cos(", String(p), ") = ", String(volume + Float(tempPanCorrectionR)), " * ", String(cos(p)), " = ", String(r))
        
        print(String(Float(tempPanCorrectionR).toDecibels().toAmplitude()))
        */
 
//        var l = volume * pan
//        var r = volume * (1 - pan)
        
        // print(frameCapacity, frameLength, newBuffer.frameLength, newBuffer.frameCapacity)
        guard otherFrameLength <= frameCapacity else {
            return
        }
        
        vDSP_vsma(oBuff[0], 1, &l, buff[0], 1, buff[0], 1, UInt(otherFrameLength))
        vDSP_vsma(oBuff[1], 1, &r, buff[1], 1, buff[1], 1, UInt(otherFrameLength))

        frameLength = frameCapacity
        // print(frameLength)
    }
    
    // delete buffers from the start
    
    func trimBuffers (by seconds: Double) {
        let deletedFrameCapacity = AVAudioFrameCount(format.sampleRate * (seconds/1000.0))
        guard deletedFrameCapacity < frameCapacity, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength - deletedFrameCapacity) else {
            return
        }
        frameLength = buffer.frameCapacity
        let frameSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        if let src = floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(src[channel], src[channel]+Int(deletedFrameCapacity), Int(buffer.frameLength) * frameSize)
            }
            for channel in 0 ..< Int(format.channelCount) {
                memset(src[channel]+Int(buffer.frameLength), 0, Int(deletedFrameCapacity) * frameSize)
            }
        }
    }
    
    func prependBufferWithSilence (of seconds: Double) -> AVAudioPCMBuffer? {
        guard let silenceBuffer = self.silenceBuffer(ofLengthInSeconds: seconds, format:format),
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: silenceBuffer.frameLength+frameLength) else {
            return nil
        }

        buffer.frameLength = buffer.frameCapacity;
        // print(buffer.frameLength, silenceBuffer.frameLength, frameLength, silenceBuffer.frameCapacity, frameCapacity)
        var frameSize = Int(silenceBuffer.format.streamDescription.pointee.mBytesPerFrame)
        if let src = silenceBuffer.floatChannelData,
            let dst = buffer.floatChannelData {
            for channel in 0 ..< Int(buffer.format.channelCount) {
                memcpy(dst[channel], src[channel], Int(silenceBuffer.frameLength) * frameSize)
            }
        }
        
        frameSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        if let src = floatChannelData,
            let dst = buffer.floatChannelData {
            for channel in 0 ..< Int(buffer.format.channelCount) {
                memcpy(dst[channel]+Int(silenceBuffer.frameLength), src[channel], Int(frameLength) * frameSize)
            }
        }
        
        // print(buffer.frameLength, silenceBuffer.frameLength, frameLength)
        // print(getLength(buffer: buffer), getLength(buffer: silenceBuffer), getLength(buffer: self))
        return buffer
    }

    // delete buffers of given buffer
    
    func deleteBuffers (from: AVAudioPCMBuffer, ofSeconds seconds: Double) -> AVAudioPCMBuffer? {
        let deletedFrameCapacity = AVAudioFrameCount(from.format.sampleRate * seconds)
        guard deletedFrameCapacity < from.frameCapacity, let buffer = AVAudioPCMBuffer(pcmFormat: from.format, frameCapacity: from.frameLength - deletedFrameCapacity) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity;
        let frameSize = Int(from.format.streamDescription.pointee.mBytesPerFrame)
        if let src = from.floatChannelData,
            let dst = buffer.floatChannelData {
            for channel in 0 ..< Int(from.format.channelCount) {
                memcpy(dst[channel], src[channel]+Int(deletedFrameCapacity), Int(buffer.frameLength) * frameSize)
            }
        }
        return buffer
    }
    
    // invert phase buffer
    
    func invertBufferPhase () {
        //let invertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        let length: AVAudioFrameCount = frameLength
        let channelCount = Int(format.channelCount)

        // i represents the normal buffer read in reverse
        for i in 0 ..< Int(length) {
            // n is the channel
            for n in 0 ..< channelCount {
                // we write the reverseBuffer via the j index
               // print(from.floatChannelData?[n][i] ?? 00)
                floatChannelData?[n][i] = -1 * (floatChannelData?[n][i] ?? 0.0)
            }
        }
        frameLength = length
    }
    
    // concat buffer
    
    func concatBuffers (prependThis append: AVAudioPCMBuffer, to: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: append.format, frameCapacity: append.frameLength+to.frameLength) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity;
        //print(buffer.frameLength, append.frameLength, to.frameLength, append.frameCapacity, to.frameCapacity)
        var frameSize = Int(append.format.streamDescription.pointee.mBytesPerFrame)
        if let src = append.floatChannelData,
            let dst = buffer.floatChannelData {
            for channel in 0 ..< Int(buffer.format.channelCount) {
                memcpy(dst[channel], src[channel], Int(append.frameLength) * frameSize)
            }
        }
        
        frameSize = Int(to.format.streamDescription.pointee.mBytesPerFrame)
        if let src = to.floatChannelData,
            let dst = buffer.floatChannelData {
            for channel in 0 ..< Int(buffer.format.channelCount) {
                memcpy(dst[channel]+Int(append.frameLength), src[channel], Int(to.frameLength) * frameSize)
            }
        }
        
        //print(buffer.frameLength, append.frameLength, to.frameLength)
        //print(getLength(buffer: buffer), getLength(buffer: append), getLength(buffer: to))
        return buffer
    }
    
    // create silence buffer
    
    func silenceBuffer (ofLengthInSeconds seconds: Double, format: AVAudioFormat) ->AVAudioPCMBuffer? {
        let silenceFrameCapacity = AVAudioFrameCount(format.sampleRate * seconds)
        guard seconds > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: silenceFrameCapacity) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        let frameSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        for channel in 0 ..< Int(buffer.format.channelCount) {
            memset(buffer.floatChannelData?[channel], 0, Int(buffer.frameLength) * frameSize)
        }
        return buffer
    }
    
    // get buffer length
    
    func getLength(buffer: AVAudioPCMBuffer) -> TimeInterval {
      let framecount = Double(buffer.frameLength)
      let samplerate = buffer.format.sampleRate
      return TimeInterval(framecount / samplerate)
    }
    

    // Sets buffer to zero
    func reset() {
        guard let b = floatChannelData else { return }
        let size = Int(UInt32(MemoryLayout<Float>.size) * frameCapacity)
        for c in 0..<Int(format.channelCount) {
            memset(b[c], 0, size)
        }
        frameLength = 0
    }
    func peak() -> Float {
        guard let channels = floatChannelData else {
            return 0
        }
        var peak = Float()
        for c in 0..<Int(format.channelCount) {
            for i in 0..<Int(frameLength) {
                peak = max(peak, fabsf(channels[c][i]))
            }
        }
        return peak
    }
}
