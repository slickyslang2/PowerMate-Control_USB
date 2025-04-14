# Powermate Control Center (USB Version)

This application is an adapted driver originally created in Bluetooth but adapted to work with USB for macOS Sequoia 15.1 and lower macOS's.

This version has been specially adapted to integrate with [Hammerspoon](https://www.hammerspoon.org/) for control of Adobe Premiere Pro, allowing you to navigate the timeline with a physically with the wheel.  

**Credit:**  

The original driver was created by Chris Edstrom, and you can find the original repository at [cedstrom/powermate-osx](https://github.com/cedstrom/powermate-osx?tab=readme-ov-file). This version was adapted by slickyslang (2025) to work with a USB Powermate device and to provide additional functionality for Adobe Premiere Pro.

## What Does This Do?

This app runs as a menu bar application on macOS and communicates with the Griffin Powermate (USB version) by sending and receiving distributed notifications (`NSDistributedNotificationCenter`). A corresponding Hammerspoon configuration listens to these notifications and performs context-sensitive actions when Adobe Premiere Pro is the frontmost application:

- **Knob Press:**
  - A single press (if no second press occurs within 0.3 seconds) toggles play/pause in Premiere (simulates a spacebar press).
  - Two rapid presses toggle **Fast Mode** on/off.
- **Knob Rotation:**
  - In **Slow Mode**:
    - Clockwise rotation sends asynchronous Right arrow presses.
    - Counterclockwise rotation sends asynchronous Left arrow presses.
    - The number of presses is determined by the device’s `rawValue` (rawValue=1 → 5 presses; rawValue≥2 → 10 presses).
  - In **Fast Mode**:
    - Clockwise rotation sends asynchronous Shift+Down arrow presses.
    - Counterclockwise rotation sends asynchronous Shift+Up arrow presses.
    - (5 or 10 presses as determined by `rawValue`.)
- All keystrokes are sent only when Adobe Premiere Pro (bundle ID `"com.adobe.PremierePro.25"`) is the frontmost application. When Premiere loses focus, any pending keystroke sequences cancel automatically.
  
## What Is This Useful For?

I use this app to navigate the timeline in Adobe Premiere Pro quickly:
- **Slow Mode** helps perform fine-grained adjustments by sending a small number of arrow key presses.
- **Fast Mode** (toggled via a quick double-press of the knob) sends modified arrow keys (Shift+Up/Down) for larger jumps between clips.
- A single press (if not toggling fast mode) also toggles play/pause in Premiere.
  
With Hammerspoon’s powerful automation, you can further customize these actions or extend the driver’s functionality to other applications.

## Requirements

- macOS (modern versions with IOKit support)
- Griffin Powermate device (USB version)

- [Hammerspoon](https://www.hammerspoon.org/) installed on your Mac
- [ForceTouchMapper Spoon](https://www.hammerspoon.org/Spoons/ForceTouchMapper.html#apps) for additional Hammerspoon functionality
  - **Installation:** Download the ForceTouchMapper spoon from the link above, then double-click the downloaded file to install it into Hammerspoon.

-Drop the contents of knob.lua into your Hammerspoon init.lua and reload the config. (clone & compile) and then run PowerMate Control_USB.app.
The menu bar item should change from ⭕ to 🎛️. This is to indicate you have a connection

Jump into Premier pro and scroll the timeline. 

If you want to add more applications or ad and adjust hot keys then just use ChatGPT write some simple code for the Knob.lua (hammerspoon config file) just open the config file in Hammerspoon and paste new code there. Save and then click reopen Config. 

## Getting Started
