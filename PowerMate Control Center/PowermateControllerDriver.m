//
//  PowermateControllerDriver.m
//  PowerMate Control Center (USB Version)
//
//  Created by Chris Edstrom on 1/25/21.
//  Updated for USB using IOKit by [Your Name], 2025.
//  Copyright © 2021 Chris Edstrom. All rights reserved.
//

#import "PowermateControllerDriver.h"
#import "Switcher.h"
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>

/// Distributed notification names for knob events and LED commands.
NSString* const kPowermateKnobNotification = @"kPowermateKnobNotification";
NSString* const kPowermateLEDNotification = @"kPowermateLEDNotification";

/// LED command constants.
NSString* const kPowermateLEDOn    = @"kPowermateLEDOn";
NSString* const kPowermateLEDOff   = @"kPowermateLEDOff";
NSString* const kPowermateLEDFlash = @"kPowermateLEDFlash";
NSString* const kPowermateLEDLevel = @"kPowermateLEDLevel";

/// Define knob state mappings.
#define POWERMATE_KNOB_STATES \
    X(kPowermateKnobPress, 0x65) \
    X(kPowermateKnobRelease, 0x66) \
    X(kPowermateKnobCounterClockwise, 0x67) \
    X(kPowermateKnobClockwise, 0x68) \
    X(kPowermateKnobPressedCounterClockwise, 0x69) \
    X(kPowermateKnobPressedClockwise, 0x70) \
    X(kPowermateKnobPressed1Second, 0x72) \
    X(kPowermateKnobPressed2Second, 0x73) \
    X(kPowermateKnobPressed3Second, 0x74) \
    X(kPowermateKnobPressed4Second, 0x75) \
    X(kPowermateKnobPressed5Second, 0x76) \
    X(kPowermateKnobPressed6Second, 0x77)

typedef NS_ENUM(uint8_t, PowermateInputState) {
#define X(name, value) name = value,
    POWERMATE_KNOB_STATES
#undef X
};

@interface PowermateControllerDriver ()
// USB/HID properties.
@property IOHIDManagerRef hidManager;
@property IOHIDDeviceRef device;

// Delegate.
@property (retain) id<PowermateControllerDelegate> delegate;
@end

@implementation PowermateControllerDriver

#pragma mark - Deallocation

- (void)dealloc {
    if (self.hidManager) {
        IOHIDManagerClose(self.hidManager, kIOHIDOptionsTypeNone);
        CFRelease(self.hidManager);
    }
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Mapping Constants

+ (NSString *)nameForState:(PowermateInputState)state {
    static NSMutableDictionary *nameMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nameMap = [NSMutableDictionary dictionary];
#define X(name, value) [nameMap setObject:@#name forKey:@(value)];
        POWERMATE_KNOB_STATES
#undef X
    });
    return [nameMap objectForKey:@(state)];
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // Mark initial connection state as off.
        [self updateConnectionState:NO];
        
        // Create HID Manager.
        self.hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        if (!self.hidManager) {
            NSLog(@"[USB] Failed to create HID Manager");
        } else {
            // Set up a matching dictionary using the PowerMate's USB vendor and product IDs.
            // Vendor: 0x077d, Product: 0x0410.
            NSNumber *vendorId = @(0x077d);
            NSNumber *productId = @(0x0410);
            NSDictionary *matchingDict = @{
                @kIOHIDVendorIDKey: vendorId,
                @kIOHIDProductIDKey: productId
            };
            IOHIDManagerSetDeviceMatching(self.hidManager, (__bridge CFDictionaryRef)matchingDict);
            
            // Register the HID input callback.
            IOHIDManagerRegisterInputValueCallback(self.hidManager, HIDInputValueCallback, (__bridge void *)(self));
            IOHIDManagerScheduleWithRunLoop(self.hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            
            // Open the HID Manager.
            IOReturn result = IOHIDManagerOpen(self.hidManager, kIOHIDOptionsTypeNone);
            if (result != kIOReturnSuccess) {
                NSLog(@"[USB] Failed to open HID Manager: 0x%08x", result);
            }
            
            // Retrieve connected devices.
            CFSetRef deviceSet = IOHIDManagerCopyDevices(self.hidManager);
            if (deviceSet) {
                // Convert the CFSetRef to an NSSet and then to an NSArray.
                NSSet *deviceSetObjC = CFBridgingRelease(deviceSet);
                NSArray *devices = [deviceSetObjC allObjects];
                if ([devices count] > 0) {
                    self.device = (__bridge IOHIDDeviceRef)[devices firstObject];
                    [self updateConnectionState:YES];
                    NSLog(@"[USB] PowerMate device discovered");
                } else {
                    [self updateConnectionState:NO];
                    NSLog(@"[USB] No PowerMate device found");
                }
            }
        }
        
        // Register for LED command notifications.
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(ledNotificationObserver:)
                                                                name:kPowermateLEDNotification
                                                              object:nil];
    }
    return self;
}

// Designated initializer.
- (instancetype)initWithDelegate:(id<PowermateControllerDelegate>)delegate {
    self = [self init];
    if (self) {
        self.delegate = delegate;
        // Notify delegate of the current connection state now that the delegate is set.
        [self updateConnectionState:self.connected];
    }
    return self;
}


#pragma mark - Connection Management

- (void)updateConnectionState:(BOOL)state {
    _connected = state;
    if (self.delegate) {
        [self.delegate controller:self didChangeState:state];
    }
}

#pragma mark - Processing Loop

// Converts a raw HID report value to a high-level knob event and posts a notification.
- (void)process:(PowermateInputState)value {
    NSString *stateName = [[self class] nameForState:value];
    NSLog(@"[USB] Processing state: %@", stateName);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kPowermateKnobNotification object:stateName];
}

#pragma mark - LED Notification Observer

- (void)ledNotificationObserver:(NSNotification *)notification {
    if (![notification.userInfo isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[USB] LED Notification not a dictionary");
        return;
    }
    NSDictionary *message = notification.userInfo;
    NSString *function = message[@"fn"];
    if (!function) {
        NSLog(@"[USB] LED Notification: no function sent");
        return;
    }
    [Switcher switchOnString:function using:@{
        kPowermateLEDOn: ^{
            [self setLedOn];
        },
        kPowermateLEDOff: ^{
            [self setLedOff];
        },
        kPowermateLEDFlash: ^{
            int level = [message[@"level"] intValue];
            if (level == 32) {
                [self quickBlinkLed];
            } else {
                [self blinkLedAtSpeed:level];
            }
        },
        kPowermateLEDLevel: ^{
            float level = [message[@"level"] floatValue];
            [self setLedBrightness:level];
        }
    } withDefault:^{
        NSLog(@"[USB] LED Notification: Unknown command");
    }];
}

#pragma mark - LED State Management

// Sends an output report to set the LED state.
- (void)setLedRawValue:(const uint8_t)brightness {
    NSLog(@"[USB] Setting LED to 0x%x", brightness);
    if (!self.device) {
        NSLog(@"[USB] No device available for LED control");
        return;
    }
    uint8_t reportID = 0;  // Adjust this if your device uses a different report ID.
    uint8_t reportData = brightness;
    IOReturn ret = IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, reportID, &reportData, sizeof(reportData));
    if (ret != kIOReturnSuccess) {
        NSLog(@"[USB] Failed to set LED report: 0x%08x", ret);
    }
}

- (void)setLedBrightness:(float)intensity {
    uint8_t brightness = ((0xbf - 0xa1) * intensity) + 0xa1;
    if (intensity <= 0) {
        brightness = 0x80;
    }
    if (intensity >= 1) {
        brightness = 0xbf;
    }
    NSLog(@"[USB] LED brightness = 0x%x", brightness);
    [self setLedRawValue:brightness];
}

- (void)setLedOn {
    [self setLedRawValue:0x81];
}

- (void)setLedOff {
    [self setLedRawValue:0x80];
}

- (void)quickBlinkLed {
    [self setLedRawValue:0xa0];
}

- (void)blinkLedAtSpeed:(int)speed {
    if (speed > 31) {
        speed = 31;
    }
    [self setLedRawValue:0xdf - speed];
}

#pragma mark - HID Input Callback

// C callback invoked by IOHIDManager when a HID report is received.
static void HIDInputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    PowermateControllerDriver *self = (__bridge PowermateControllerDriver *)context;
    if (!self) return;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex rawValue = IOHIDValueGetIntegerValue(value);
    
    NSLog(@"[USB] HID event received - Usage Page: %u, Usage: %u, Raw Value: %ld", usagePage, usage, rawValue);
    
    PowermateInputState eventState = 0;
    
    // Check if this is a button event (usage page 9, usage 1).
    if (usagePage == 9 && usage == 1) {
        if (rawValue == 1) {
            eventState = kPowermateKnobPress;    // defined as 0x65
        } else if (rawValue == 0) {
            eventState = kPowermateKnobRelease;  // defined as 0x66
        } else {
            NSLog(@"[USB] Unexpected raw value for usage page 9, usage 1: %ld", rawValue);
            return;
        }
    }
    // Check if this is a dial (rotation) event (usage page 1, usage 51).
    else if (usagePage == 1 && usage == 51) {
        if (rawValue > 0) {
            eventState = kPowermateKnobClockwise;          // defined as 0x68
        } else if (rawValue < 0) {
            eventState = kPowermateKnobCounterClockwise;     // defined as 0x67
        } else {
            // If rawValue is 0, nothing to do.
            return;
        }
    }
    else {
        NSLog(@"[USB] Unhandled usage page/usage: %u, %u", usagePage, usage);
        return;
    }
    
    // Process the event with the mapped state.
    [self process:eventState];
}

@end
