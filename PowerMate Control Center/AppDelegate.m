//
//  AppDelegate.m
//  PowerMate Control Center
//
//  Created by Chris Edstrom on 1/25/21.
//  Updated for USB HID by [Your Name], 2025.
//  Copyright © 2021 Chris Edstrom. All rights reserved.
//

#import "AppDelegate.h"
#import "PowermateControllerDriver.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (retain) PowermateControllerDriver *driver;
@property (retain) NSStatusItem *menuItem;
@property (retain) NSMenuItem *connectionStateMenuItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Hide the dock icon by setting the activation policy to accessory.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    // Create a square status item in the menu bar.
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    self.menuItem = [statusBar statusItemWithLength:NSSquareStatusItemLength];
    
    // Set the initial icon for a disconnected state.
    self.menuItem.button.title = @"⭕";
    
    // Create the menu for the status item.
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Powermate Driver"];
    self.connectionStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Disconnected" action:nil keyEquivalent:@""];
    [menu addItem:self.connectionStateMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
    
    self.menuItem.menu = menu;
    
    // Initialize the Powermate controller driver using USB HID.
    self.driver = [[PowermateControllerDriver alloc] initWithDelegate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if (self.driver) {
        [self.driver setLedOff];
    }
}

// Quit action called from the menu.
- (void)quit:(id)sender {
    [NSApp terminate:sender];
}

#pragma mark - PowermateControllerDelegate

- (void)controller:(PowermateControllerDriver *)driver didChangeState:(BOOL)connected {
    if (connected) {
        self.connectionStateMenuItem.title = @"Connected";
        self.menuItem.button.title = @"🎛️";
    } else {
        self.connectionStateMenuItem.title = @"Disconnected";
        self.menuItem.button.title = @"⭕";
    }
}

@end
