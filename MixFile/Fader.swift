//
//  Fader.swift
//  MixFile
//
//  Created by David O'Neill on 5/9/18.
//  Copyright © 2018 cinematicstrings. All rights reserved.
//

import Cocoa
import AVFoundation

class Fader: NSView, NSTextFieldDelegate {

    lazy var volumeSlider: NSSlider = {
        let slider = NSSlider(value: 1, minValue: 0, maxValue: 16, target: self, action: #selector(volumeSliderAction(slider:)))
        slider.isVertical = true
        self.addSubview(slider)
        return slider
    }()
    lazy var panSlider: NSSlider = {
        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: self, action: #selector(panSliderAction(slider:)))
        self.addSubview(slider)
        return slider
    }()
    var title: String {
        get { return titleField.stringValue }
        set { titleField.stringValue = newValue }
    }

    public lazy var titleField: Label = {
        let textField = Label()
        textField.alignment = .center
        self.addSubview(textField)
        return textField
    }()
    public lazy var panField: NSTextField = {
        let textField = NSTextField()
        textField.alignment = .center
        textField.floatValue = 0
        textField.delegate = self
        textField.refusesFirstResponder = true
        self.addSubview(textField)
        return textField
    }()
    public lazy var dbField: NSTextField = {
        let textField = NSTextField()
        textField.alignment = .center
        textField.floatValue = 0
        textField.delegate = self
        textField.refusesFirstResponder = true
        self.addSubview(textField)
        return textField
    }()
    // LM 9JUL adding checkbox for phase inversion
    public lazy var phaseInvertButton: NSButton = {
        let button = NSButton(title: "Φ", target:self, action: #selector(processPhaseInvert(button:)))
        button.setButtonType(.switch)
        button.isEnabled = title != "Master"
        // button.alignment = .center
        if title != "Master" {
            self.addSubview(button)
        }
        return button
    }()

    // LM 16JUL adding textbox for delay
    public lazy var delayField: NSTextField = {
        let textField = NSTextField()
        textField.alignment = .center
        textField.floatValue = 0
        textField.delegate = self
        textField.refusesFirstResponder = true
        self.addSubview(textField)
        return textField
    }()

    // ---

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        pan = 0.5
        volume = 1
    }
    public convenience init(title: String) {
        self.init()
        self.title = title
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: NSRect {
        get { return super.frame }
        set {
            super.frame = newValue
            
            /* LM 17JUL notes:
             textHeight is used in every component's frame
             The overall plan should be:
             __component__  | __height__
             panField           20
             panSlider          20
             delayField         20*
             phaseInvertButton      20*
             volumeSlider       (all remaining)
             dbField            20
             titleField         20
            */
            
            let textHeight = CGFloat(20)
            let margin = CGFloat(10)

            var y = CGFloat(0)
            titleField.frame = CGRect(x: 0,
                                      y: 0,
                                      width: bounds.width,
                                      height: textHeight)

            y = titleField.frame.maxY
            dbField.frame = CGRect(x: 0,
                                   y: y,
                                   width: bounds.width,
                                   height: textHeight)

            y = dbField.frame.maxY + margin
            volumeSlider.frame = CGRect(x: 0,
                                        y: y,
                                        width: bounds.width,
                                        height: bounds.height - dbField.frame.maxY - margin * 2 - textHeight * 4) // LM 17JUL Changed from '...textHeight * 2)' to accommodate new compomenents
            
            // LM 17JUL add in the phaseInvertButton
            y = bounds.height - margin - textHeight * 4
            phaseInvertButton.frame = CGRect(x: 0,
                                    y: y,
                                    width: bounds.width,
                                    height: textHeight)

            // LM 17JUL add in the delayField
            y = bounds.height - margin - textHeight * 3
            delayField.frame = CGRect(x: 0,
                                             y: y,
                                             width: bounds.width,
                                             height: textHeight)
            
            y = bounds.height - margin - textHeight * 2
            panSlider.frame = CGRect(x: 0,
                                     y: y,
                                     width: bounds.width,
                                     height: textHeight)

            y = bounds.height - textHeight - margin
            panField.frame = CGRect(x: 0,
                                    y: y,
                                    width: bounds.width,
                                    height: textHeight)

        }
    }

    @objc func volumeSliderAction(slider: NSSlider) {
        volume = slider.floatValue
    }
    @objc func panSliderAction(slider: NSSlider) {
        pan = slider.floatValue
    }
    
    @objc func processPhaseInvert(button: NSButton){
        // print("Phase change: ", button.intValue)
        phaseInvertYN = button.intValue != 0
        // print("Phase change: ", phaseInvertYN)
    }

    var volume: Float = 1{
        didSet {
            let maxValue = volumeSlider.isHidden ? .greatestFiniteMagnitude  : Float(volumeSlider.maxValue)
            let value = min(max(0, volume), maxValue)
            dbField.stringValue = value > 0 ? String(value.toDecibels()) : "~"
            print(titleField.stringValue, ": ", String(value), ".toDecibels() = ", String(value.toDecibels()))
            volumeSlider.floatValue = value
        }
    }

    var pan: Float = 0.5 {
        didSet {
            let value = min(max(0, pan), 1)
            panField.floatValue = value * 200 - 100
            panSlider.floatValue = value
        }
    }

    var phaseInvertYN: Bool = false
    
    var delayAmountms: Float = 0
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if (commandSelector == #selector(NSResponder.insertNewline(_:))) {
            if control == dbField {
                volume = dbField.floatValue.toAmplitude()
            }
            else if control == delayField {
                
                delayAmountms = delayField.floatValue / 1000
                // print(delayAmountms)
            } else {
                pan = (Float(panField.floatValue) + 100) / 200
                // print("func control ", pan)
            }
            return true
        }
        return false
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        guard let object = obj.object as? NSControl else { return }
        
        if object == dbField {
            volume = dbField.floatValue.toAmplitude()
        }
        else if object == panField {
            pan = (Float(panField.floatValue) + 100) / 200
            // print("func controlTextDidEndEditing ", pan)
        } else if object == delayField {
            delayAmountms = delayField.floatValue / 1000
            // print(delayAmountms)
        }
        
    }

}
