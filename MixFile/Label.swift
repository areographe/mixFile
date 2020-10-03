//
//  Label.swift
//  MixFile
//
//  Created by David O'Neill on 5/9/18.
//  Copyright © 2018 cinematicstrings. All rights reserved.
//

import Cocoa

class Label: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    convenience init(text: String) {
        self.init(frame: .zero)
        stringValue = text
    }
    func setup() {
        isBezeled = false
        drawsBackground = false
        isEditable = false
        isSelectable = false
    }
}
