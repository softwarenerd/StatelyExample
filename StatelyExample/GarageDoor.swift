//
//  GarageDoor.swift
//  StatelyExample
//
//  Created by Brian Lambert on 10/28/16.
//  See the LICENSE.md file in the project root for license information.
//

import Foundation
import Stately

// Garage door status updated block.
typealias GarageDoorStatusUpdated = (_ garageDoorStatus: String, _ garageDoorOpenedPercent: Int) -> Void

// GarageDoor class.
class GarageDoor {
    // Speed with which the door moves.
    private let speed = 0.03
    
    // Some strings we use multiple times.
    private let doorClosing = "Door Closing"
    private let doorOpening = "Door Opening"
    private let stopped = "Stopped"
    
    // States for closing the door.
    private var stateClosed: State!
    private var stateClosing: State!
    private var stateClosingStopped: State!

    // States for opening the door.
    private var stateOpened: State!
    private var stateOpening: State!
    private var stateOpeningStopped: State!

    // Events.
    private var eventButtonPushed: Event!
    private var eventSensorClosed: Event!
    private var eventSensorOpened: Event!
    
    // State machine.
    private var stateMachine: StateMachine!
    
    // The timer that is used to simulate garage door movement.
    private var timerGarageDoorMovement: Timer?
    
    // Garage door door opened percent.
    private var garageDoorOpenedPercent = 0
    
    // The garage door status updated block.
    private let garageDoorStatusUpdated: GarageDoorStatusUpdated
    
    /// Class initializer.
    /// - Parameters:
    ///   - doorStatusUpdated: Called whenever the door status is updated.
    init(garageDoorStatusUpdated garageDoorStatusUpdatedIn: @escaping GarageDoorStatusUpdated) {
        // Set the garage door status updated block.
        garageDoorStatusUpdated = garageDoorStatusUpdatedIn
        
        // Initialize the state machine.
        do {
            // Initialize the closed state.
            stateClosed = try State(name: "Closed") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }

                // Update garage door status.
                strongSelf.garageDoorStatusUpdated("Door Closed", strongSelf.garageDoorOpenedPercent)
                
                // Return, leaving state unchanged.
                return nil
            }

            // Initialize the closing state.
            stateClosing = try State(name: "Closing") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }
                
                // Update garage door status.
                strongSelf.garageDoorStatusUpdated(strongSelf.doorClosing, strongSelf.garageDoorOpenedPercent)

                // Start closing the garage door.
                strongSelf.startClosingGarageDoor()
                
                // Return, leaving state unchanged.
                return nil
            }
            
            // Initialize the closing stopped state.
            stateClosingStopped = try State(name: "ClosingStopped") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }
                
                // Stop garage door movement.
                strongSelf.stopGarageDoorMovement()
                
                // Update garage door status.
                strongSelf.garageDoorStatusUpdated(strongSelf.stopped, strongSelf.garageDoorOpenedPercent)
                
                // Return, leaving state unchanged.
                return nil
            }

            // Initialize the opened state.
            stateOpened = try State(name: "Opened") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }

                // Update garage door status.
                strongSelf.garageDoorStatusUpdated("Door Opened", strongSelf.garageDoorOpenedPercent)
                
                // Return, leaving state unchanged.
                return nil
            }
            
            // Initialize the opening state.
            stateOpening = try State(name: "Opening") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }

                // Update garage door status.
                strongSelf.garageDoorStatusUpdated(strongSelf.doorOpening, strongSelf.garageDoorOpenedPercent)

                // Start opening the garage door.
                strongSelf.startOpeningGarageDoor()
                
                // Return, leaving state unchanged.
                return nil
            }
            
            // Initialize the opening stopped state.
            stateOpeningStopped = try State(name: "OpeningStopped") { [weak self] (object: AnyObject?) -> StateChange? in
                // Ensure we're still allocated.
                guard let strongSelf = self else {
                    return nil
                }

                // Stop garage door movement.
                strongSelf.stopGarageDoorMovement()

                // Update garage door status.
                strongSelf.garageDoorStatusUpdated(strongSelf.stopped, strongSelf.garageDoorOpenedPercent)

                // Return, leaving state unchanged.
                return nil
            }

            // Initialize the button pushed event.
            eventButtonPushed = try Event(name: "ButtonPushed", transitions: [(fromState: stateClosed,         toState: stateOpening),
                                                                              (fromState: stateOpening,        toState: stateOpeningStopped),
                                                                              (fromState: stateOpeningStopped, toState: stateClosing),
                                                                              (fromState: stateOpened,         toState: stateClosing),
                                                                              (fromState: stateClosing,        toState: stateClosingStopped),
                                                                              (fromState: stateClosingStopped, toState: stateOpening)])
            
            // Initialize the sensor closed event. This event transitions the door from the closing state to the closed state.
            eventSensorClosed = try Event(name: "SensorClosed", transitions: [(fromState: stateClosing, toState: stateClosed)])
            
            // Initialize the sensor opened event. This event transitions the door from the opening state to the openeded state.
            eventSensorOpened = try Event(name: "SensorOpened", transitions: [(fromState: stateOpening, toState: stateOpened)])
            
            // Initialize the state machine with states, events, and the default state.
            stateMachine = try StateMachine(name: "GarageDoorStateMachine",
                                            defaultState: stateClosed,
                                            states: [stateClosed, stateClosing, stateClosingStopped, stateOpened, stateOpening, stateOpeningStopped],
                                            events: [eventButtonPushed, eventSensorClosed, eventSensorOpened])
        } catch {
            // When something goes wrong, set state machine to nil.
            stateMachine = nil
        }
    }
    
    // Button pushed.
    public func buttonPushed() -> Bool {
        // Return false to indicate that the door is broken, if the state machine is nil.
        if stateMachine == nil {
            return false
        }
        
        // Fire the button pushed event.
        do {
            try stateMachine?.fireEvent(event: eventButtonPushed)
            return true
        } catch {
            // Break the door.
            doorBroken()
            
            // Return false to indicate that the door is broken.
            return false
        }        
    }
    
    // Starts opening the garage door.
    private func startOpeningGarageDoor() {
        // Schedule the timer that is used to simulate movement.
        timerGarageDoorMovement = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] (_: Timer) in
            // Ensure we're still allocated.
            guard let strongSelf = self else {
                return
            }
            
            // Move the garage door until it's opened.
            if strongSelf.garageDoorOpenedPercent < 100 {
                // Open the door more.
                strongSelf.garageDoorOpenedPercent += 1
                
                // Update garage door status.
                strongSelf.garageDoorStatusUpdated("Door Opening", strongSelf.garageDoorOpenedPercent)
            } else {
                // Stop garage door movement.
                strongSelf.stopGarageDoorMovement()

                // Fire the sensor opened event.
                do {
                    try strongSelf.stateMachine?.fireEvent(event: strongSelf.eventSensorOpened)
                } catch {
                    strongSelf.doorBroken()
                }
            }
        }
    }
    
    // Starts closing the garage door.
    private func startClosingGarageDoor() {
        // Schedule the timer that is used to simulate movement.
        timerGarageDoorMovement = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] (_: Timer) in
            // Ensure we're still allocated.
            guard let strongSelf = self else {
                return
            }
            
            // Move the garage door until it's closed.
            if strongSelf.garageDoorOpenedPercent > 0 {
                // Close the door more.
                strongSelf.garageDoorOpenedPercent -= 1
                
                // Update garage door status.
                strongSelf.garageDoorStatusUpdated(strongSelf.doorClosing, strongSelf.garageDoorOpenedPercent)
            } else {
                // Stop garage door movement.
                strongSelf.stopGarageDoorMovement()

                // Fire the sensor closed event.
                do {
                    try strongSelf.stateMachine?.fireEvent(event: strongSelf.eventSensorClosed)
                } catch {
                    strongSelf.doorBroken()
                }
            }
        }
    }

    // Stops garage door movement.
    private func stopGarageDoorMovement() {
        timerGarageDoorMovement?.invalidate()
        timerGarageDoorMovement = nil
    }

    // Breaks the door. Should never be called.
    private func doorBroken() {
        // Release the state machine.
        stateMachine = nil
        
        // Update garage door status.
        garageDoorStatusUpdated("Door Broken", garageDoorOpenedPercent)
    }
}
