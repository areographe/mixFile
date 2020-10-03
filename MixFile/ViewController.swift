//
//  ViewController.swift
//  MixFile
//
//  Created by David O'Neill on 5/7/18.
//  Copyright © 2018 cinematicstrings. All rights reserved.
//
//  LM 8JUL
//  Edited to add new microphone angle ("OH")
//  TODO: add delay and phase options/3

import Cocoa
import AVFoundation

// Order important, first one will dictate format for the mix down // LM 8JUL unsuree if this still applies, have changed order anyway
let positions = ["Close", "OH", "Main", "Room"]


class ViewController: NSViewController, NSWindowDelegate {


    var seacrhResults = [String: [URL]]()

    lazy var chooseSrcButton = NSButton(title: "Choose source", target: self, action: #selector(selectSourceFolder))
    let sourceField = NSTextField()

    lazy var chooseDstButton = NSButton(title: "Choose destination", target: self, action: #selector(selectDstFolder))
    let destField: NSTextField = {
        let textField = NSTextField()
        textField.placeholderString = "Same as source"
        return textField
    }()

    let instrumentCodelabel = Label(text: "Instrument code")
    let instrumentCodeTextField = NSTextField()

    lazy var processButton = NSButton(title: "Process", target: self, action: #selector(processButtonAction))

    lazy var faders: [Fader] = {
        var faders = positions.map{Fader(title: $0)}
        let master = Fader(title: "Master")
        faders.append(master)
        return faders
    }()

    @objc func processButtonAction() {
        do {
            try process()
        } catch {
            print(error)
            alert(error.localizedDescription)
        }
    }

    var testAudioPlayer: AVAudioPlayer?

    @objc func process() throws {

        guard let srcDir = getValidURL(path: sourceField.stringValue) else {
            return alert("Source invalid")
        }
        let dstPath = destField.stringValue != "" ? destField.stringValue : sourceField.stringValue
        guard let dstDir = getValidURL(path: dstPath) else {
            return alert("Destination invalid")
        }
        let instrumentCode = instrumentCodeTextField.stringValue
        if instrumentCode == "" {
            return alert("Instrument code invalid")
        }
        guard let primaryPosition = positions.first else {
            return alert("No positons!")
        }

        let fileManager = FileManager.default

        let filenames = try fileManager.contentsOfDirectory(atPath: srcDir.path)
        let primaryUrls = filenames.filter{ fileName in
            let lcFileName = fileName.lowercased()
            let fileUrl = srcDir.appendingPathComponent(fileName)
            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: fileUrl.path, isDirectory: &isDir)
            return exists && !isDir.boolValue &&
                lcFileName.contains(instrumentCode.lowercased()) &&
                lcFileName.contains(primaryPosition.lowercased())

            }.map{
                srcDir.appendingPathComponent($0)
        }

        if primaryUrls.count == 0 {
            alert("No matches found for \(instrumentCode)")
            return
        }

        let findMatch = { (primary: URL, position: String) -> URL? in
            let primaryFileName = primary.lastPathComponent
            let matchName = primaryFileName.replacingOccurrences(of: primaryPosition, with: position)
            let match = srcDir.appendingPathComponent(matchName)
            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: match.path, isDirectory: &isDir)
            return exists && !isDir.boolValue ? match : nil
        }

        var peak = Float()
        var peakName = ""
        var count = 0

//        testAudioPlayer?.stop()
//        testAudioPlayer = nil
        outerLoop: for primaryUrl in primaryUrls {
            var mixUrls = [primaryUrl]
            for i in 1..<positions.count {
                if let secondaryUrl = findMatch(primaryUrl, positions[i]) {
                    mixUrls.append(secondaryUrl)
                } else {
                    continue outerLoop
                }
            }
            let mixName = primaryUrl.lastPathComponent.replacingOccurrences(of: primaryPosition, with: "Mix")

            count += 1
            let _peak = try mixDown(urls: mixUrls, to: dstDir.appendingPathComponent(mixName))
            if _peak > peak {
                peak = _peak
                peakName = mixName
            }
//            if testAudioPlayer == nil {
//                do {
//                    let audioPlayer = try AVAudioPlayer(contentsOf: dstDir.appendingPathComponent(mixName))
//                    audioPlayer.play()
//                    testAudioPlayer = audioPlayer
//
//                } catch {
//                    print(error)
//                }
//            }
        }


        alert("Process complete! \(count) files created, peak audio level is in \(peakName) at \(peak.toDecibels())dB")
    }



    func mixDown(urls: [URL], to dst: URL) throws -> Float {

        let firstFile = try AVAudioFile(forReading: urls.first!)
        let processingFormat = firstFile.processingFormat
        let fileFormat = firstFile.fileFormat
        let audioReaders = try urls.map{ try ExtAudioReader(url: $0, processingFormat: processingFormat) }
        //let framesPerRead = AVAudioFrameCount(firstFile.length)
        let framesPerRead = try UInt32(urls.reduce(0, { (result, url) -> Int64 in
            let audioFile = try AVAudioFile(forReading: url)
            return max(result, audioFile.length)
        }))
        let dstAudioFile = try AVAudioFile(forWriting: dst, settings: fileFormat.settings)        
        let maxDelay = Double(faders.reduce(0, { max($0, $1.delayAmountms) }))
        let frameCapacity = framesPerRead + UInt32(maxDelay * fileFormat.sampleRate)
      //  print(frameCapacity, Double(frameCapacity)/fileFormat.sampleRate)
        guard
            let writeBuffer = AVAudioPCMBuffer(pcmFormat: dstAudioFile.processingFormat, frameCapacity: frameCapacity),
            let readBuffer = AVAudioPCMBuffer(pcmFormat: dstAudioFile.processingFormat, frameCapacity: frameCapacity) else {
                fatalError()
        }
//        let dstAudioReader = try ExtAudioReader(url: dst, processingFormat: dstAudioFile.processingFormat)
//        print(dst)
        var peak = Float()
        while true {
            var framesRead = false
            writeBuffer.reset()
            let masterVolume = faders.last!.volume
            let masterPan = faders.last!.pan
            for i in 0..<positions.count {
                let audioFile = audioReaders[i]
                let volume = faders[i].volume * masterVolume
                print("\n", faders[i].title, " = ", String(faders[i].volume), " * ", String(masterVolume))
                let pan = faders[i].pan
                let delayF = faders[i].delayAmountms
                let phase = faders[i].phaseInvertYN
                try audioFile.read(into: readBuffer)
                // print("Audio file with duration \(audioFile.duration) and delay \(delayF) with phase inversion \(phase) is getting mixed")
                if readBuffer.frameLength != 0 {
                    framesRead = true
                    writeBuffer.mixIn(other: readBuffer, volume: volume, pan: pan * masterPan * 2, delay: delayF, phaseInv: phase);
                    print("mixIn: ", faders[i].title, " ( volume: ", String(volume), ", pan: ", String(pan * masterPan * 2), " )");
                }
            }

            if framesRead {
                let p = writeBuffer.peak()
                peak = max(peak, p)
                try dstAudioFile.write(from: writeBuffer)
            } else {
                break
            }
        }
        return peak
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        guard let window = NSApplication.shared.windows.first else { return }

        window.delegate = self

        for fader in faders {
            view.addSubview(fader)
        }

        view.addSubview(chooseSrcButton)
        view.addSubview(sourceField)
        view.addSubview(chooseDstButton)
        view.addSubview(destField)
//        view.addSubview(outputTrimLabel)
//        view.addSubview(outputTrimTextField)
        view.addSubview(instrumentCodelabel)
        view.addSubview(instrumentCodeTextField)
        view.addSubview(processButton)

        layout()

    }
    func windowDidResize(_ notification: Notification) {
        layout()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(self)
        return true
    }


    func layout() {
        let elementHeight = CGFloat(40)
        let margin = CGFloat(10)

        let b = view.bounds
        // LM 8JUL adjusted width divisor from 3 to 2.5
        let (fadersRect, textRect) = b.divided(atDistance: b.width / 2.5, from: .minXEdge)
        var faderRect = fadersRect
        faderRect.size.width /= CGFloat(faders.count)

        // TODO: Manual sorting bad :/ // LM 8JUL was this already fixed? Seems like it is? I've changed the array item order anyway
        for fader in faders {
            fader.volumeSlider.isHidden = false
            fader.frame = faderRect
            faderRect = faderRect.offsetBy(dx: faderRect.size.width, dy: 0)
            fader.needsLayout = true
        }


        let leftElemWidth = CGFloat(150)
        let leftFrame = {(y: CGFloat) in
            return CGRect(x: textRect.origin.x + margin,
                          y: y,
                          width: leftElemWidth,
                          height: elementHeight)
        }
        let rightFrame = {(y: CGFloat) in
            return CGRect(x: textRect.origin.x + leftElemWidth + margin * 2,
                          y: y,
                          width: textRect.width - leftElemWidth - margin * 3,
                          height: elementHeight)
        }



        chooseSrcButton.frame = leftFrame(textRect.origin.y + textRect.height - margin - elementHeight)
        sourceField.frame = rightFrame(chooseSrcButton.frame.origin.y)

        chooseDstButton.frame = leftFrame(chooseSrcButton.frame.minY - margin - elementHeight)
        destField.frame = rightFrame(chooseDstButton.frame.origin.y)

        instrumentCodelabel.frame = leftFrame(chooseDstButton.frame.minY - margin - elementHeight)
        instrumentCodeTextField.frame = rightFrame(instrumentCodelabel.frame.origin.y)

//        outputTrimLabel.frame = leftFrame(instrumentCodelabel.frame.minY - margin - elementHeight)
//        outputTrimTextField.frame = rightFrame(outputTrimLabel.frame.origin.y)

        processButton.frame = leftFrame(instrumentCodelabel.frame.minY - margin - elementHeight)
    }

    @objc func selectSourceFolder(){
        pickDirectory{ url in self.sourceField.stringValue = url.path }
    }
    @objc func selectDstFolder(){
        pickDirectory{ url in self.destField.stringValue = url.path }
    }

    func alert(_ message: String) {
        let a = NSAlert()
        a.messageText = message
        a.alertStyle = .warning
        a.runModal()
    }

    private func pickDirectory(completionHandler: @escaping (URL) -> Void) {
        guard let window = NSApplication.shared.windows.first else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window){ (response) in
            if response == .OK,
                let first = panel.urls.first {
                completionHandler(first)
            }
        }
    }
    func getValidURL(path: String?) -> URL? {
        guard let path = path, path != "" else { return nil }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue ? URL(fileURLWithPath: path) : nil
    }
}
extension Float {
    func toAmplitude() -> Float {
        return self > -120 ? pow(10, (0.05 * self)) : 0;
    }
    func toDecibels() -> Float {
        return self > 0 ? 20.0 * log10(self) : -Float.greatestFiniteMagnitude
    }
}





extension NSError {
    static func withOSStatus(status: OSStatus) -> Error {
        return NSError(domain: kCFErrorDomainOSStatus as String, code: Int(status), userInfo: nil)
    }
}

