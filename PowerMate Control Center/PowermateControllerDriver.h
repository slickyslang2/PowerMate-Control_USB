//
//  PowermateControllerDriver.h
//  PowerMate Control Center (USB Version)
//
//  Created by Chris Edstrom on 1/25/21.
//  Updated for USB using IOKit by [Your Name], 2025.
//  Copyright © 2021 Chris Edstrom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

// Distributed Notification Names for knob events and LED commands.
extern NSString* const kPowermateKnobNotification;
extern NSString* const kPowermateLEDNotification;

// LED control command names.
extern NSString* const kPowermateLEDOn;
extern NSString* const kPowermateLEDOff;
extern NSString* const kPowermateLEDFlash;
extern NSString* const kPowermateLEDLevel;

@class PowermateControllerDriver;

@protocol PowermateControllerDelegate <NSObject>

// Informs the delegate when the connection state changes.
- (void)controller:(PowermateControllerDriver *)driver didChangeState:(BOOL)connected;

@end

@interface PowermateControllerDriver : NSObject

@property (assign, readonly) BOOL connected;
@property (atomic, retain) NSString* errorReason;

- (instancetype)initWithDelegate:(id<PowermateControllerDelegate>)delegate;

// LED control methods.
- (void)setLedBrightness:(float)intensity;
- (void)setLedOn;
- (void)setLedOff;
- (void)quickBlinkLed;
- (void)blinkLedAtSpeed:(int)speed;

@end

NS_ASSUME_NONNULL_END
