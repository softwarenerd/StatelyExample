//
//  DoorSimulator.swift
//  StatelyExample
//
//  Created by Brian Lambert on 10/28/16.
//  Copyright © 2016 Softwarenerd. All rights reserved.
//

import Foundation
import Stately

// Types aliases.
typealias DoorStatusUpdated = (String, Int) -> Void

// DoorSimulator class.
class DoorSimulator {
    // States.
    private var stateClosed: State!
    private var stateOpened: State!
    private var stateClosing: State!
    private var stateOpening: State!
    
    // Events.
    private var eventClose: Event!
    private var eventOpen: Event!
    private var eventSensorClosed: Event!
    private var eventSensorOpened: Event!
    
    // Door control state machine.
    private var stateMachine: StateMachine?
    
    // Door opened percent.
    private var doorOpenedPercent = 0
    
    // The door motor timer.
    private var timerDoorMotor: Timer?
    
    // The auto close timer.
    private var timerAutoClose: Timer?
    
    // The door status updated callback.
    private let doorStatusUpdated: DoorStatusUpdated?
    
    // Gets a value which indicates whether the door is broken.
    public var isBroken: Bool {
        get {
            return stateMachine == nil
        }
    }
    
    /// Class initializer.
    /// - Parameters:
    ///   - doorStatusUpdated: Called when the door status is updated.
    init(doorStatusUpdated doorStatusUpdatedIn: DoorStatusUpdated?) {
        // Save the door
        doorStatusUpdated = doorStatusUpdatedIn
        
        // Initialize the state machine.
        do {
            // Initialize the closed state.
            stateClosed = try State(name: "Closed") { [weak self] (object: AnyObject?) -> StateChange? in
                // Update door status.
                self?.updateDoor(doorStatus: "Closed", startMotor: false)
                
                // Don't change state.
                return nil
            }
            
            // Initialize the opened state.
            stateOpened = try State(name: "Opened") { [weak self] (object: AnyObject?) -> StateChange? in
                // Update door status.
                self?.updateDoor(doorStatus: "Opened", startMotor: false)
                
                // Don't change state.
                return nil
            }
            
            // Initialize the closing state.
            stateClosing = try State(name: "Closing") { [weak self] (object: AnyObject?) -> StateChange? in
                // Update door status and start moving the door.
                self?.updateDoor(doorStatus: "Closing", startMotor: true)
                
                // Don't change state.
                return nil
            }
            
            // Initialize the opening state.
            stateOpening = try State(name: "Opening") { [weak self] (object: AnyObject?) -> StateChange? in
                // Update door status and start moving the door.
                self?.updateDoor(doorStatus: "Opening", startMotor: true)
                
                // Don't change state.
                return nil
            }
            
            // Initialize the close event. Note that it's OK to fire the close event from the closing or closed states,
            // which results in the state machine staying in those states.
            eventClose        = try Event(name: "Close",  transitions: [(fromState: stateOpened,  toState: stateClosing),
                                                                        (fromState: stateOpening, toState: stateClosing),
                                                                        (fromState: stateClosed,  toState: stateClosed),
                                                                        (fromState: stateClosing, toState: stateClosing)])
            
            // Initialize the open event. Note that it's OK to fire the open event from the opening or opened states,
            // which results in the state machine staying in those states.
            eventOpen         = try Event(name: "Open",   transitions: [(fromState: stateClosed,  toState: stateOpening),
                                                                        (fromState: stateClosing, toState: stateOpening),
                                                                        (fromState: stateOpened,  toState: stateOpened),
                                                                        (fromState: stateOpening, toState: stateOpening)])
            
            // Initialize the sensor closed event. This event transitions the door from the closing state to the closed state.
            eventSensorClosed = try Event(name: "SensorClosed", transitions: [(fromState: stateClosing, toState: stateClosed)])
            
            // Initialize the sensor opened event. This event transitions the door from the opening state to the openeded state.
            eventSensorOpened = try Event(name: "SensorOpened", transitions: [(fromState: stateOpening, toState: stateOpened)])
            
            // Initialize the state machine with states, events, and the default state.
            stateMachine = try StateMachine(name: "DoorControl",
                                            defaultState: stateClosed,
                                            states: [stateClosed, stateOpened, stateClosing, stateOpening],
                                            events: [eventClose, eventOpen, eventSensorClosed, eventSensorOpened])
        } catch {
            // When something goes wrong, set state machine to nil.
            stateMachine = nil
        }
    }
    
    // Opens the door.
    public func open() -> Bool {
        do {
            try stateMachine?.FireEvent(event: eventOpen)
            return true
        } catch {
            return false
        }
    }
    
    // Opens the door.
    public func close() -> Bool {
        do {
            try stateMachine?.FireEvent(event: eventClose)
            return true
        } catch {
            return false
        }
    }
    
    // Updates the door.
    private func updateDoor(doorStatus: String, startMotor: Bool) {
        if startMotor && self.timerDoorMotor == nil {
            self.timerDoorMotor = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { (_: Timer) in
                var done = true
                if self.stateMachine?.currentState == self.stateOpening {
                    if self.doorOpenedPercent < 100 {
                        self.doorOpenedPercent += 1
                        done =  false
                    } else {
                        do {
                            try self.stateMachine?.FireEvent(event: self.eventSensorOpened)
                        } catch {
                        }
                    }
                } else if self.stateMachine?.currentState == self.stateClosing {
                    if self.doorOpenedPercent > 0 {
                        self.doorOpenedPercent -= 1
                        done =  false
                    } else {
                        do {
                            try self.stateMachine?.FireEvent(event: self.eventSensorClosed)
                        } catch {
                        }
                    }
                } else {
                }
                
                if done {
                    self.timerDoorMotor?.invalidate()
                    self.timerDoorMotor = nil
                }
                
                self.doorStatusUpdated?(doorStatus, self.doorOpenedPercent)
            }
        }
    }
}
