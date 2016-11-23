//
//  GarageDoorViewController.swift
//  StatelyExample
//
//  Created by Brian Lambert on 10/13/16.
//  See the LICENSE.md file in the project root for license information.
//

import Foundation
import Cocoa
import AppKit
import Stately

// GarageDoorViewController class.
class GarageDoorViewController: NSViewController {
    // The garage door.
    private var garageDoor: GarageDoor!

    // Outlets.
    @IBOutlet private weak var labelGarageDoorStatus: NSTextField!
    @IBOutlet private weak var progressIndicatorGarageDoor: NSProgressIndicator!

    // Called when the view loads.
    override func viewDidLoad() {
        // Allocate and initialize the garage door.
        garageDoor = GarageDoor(garageDoorStatusUpdated: { (garageDoorStatus: String, garageDoorOpenedPercent: Int) in
            // Update UI on the main thread.
            DispatchQueue.main.async {
                self.labelGarageDoorStatus.stringValue = garageDoorStatus
                self.progressIndicatorGarageDoor.doubleValue = Double(garageDoorOpenedPercent)
            }
        })
        
        // Call the base class's method.
        super.viewDidLoad()
    }
        
    // The door button action.
    @IBAction private func buttonDoorAction(_ sender: NSButton) {
        if !garageDoor.buttonPushed() {
            NSBeep()
        }
    }
}

