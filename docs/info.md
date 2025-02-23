<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This VGA display project generates dynamic visual patterns using a combination of geometric calculations and color manipulation. Here's a detailed breakdown of its operation:

### Core Components
1. **VGA Signal Generation**
   - Generates standard 640x480 VGA timing signals
   - Produces horizontal sync (hsync) and vertical sync (vsync)
   - Creates active display window signals

2. **Pattern Generation**
   - Calculates distance from screen center (radius)
   - Creates concentric circular regions
   - Uses pattern counter for animation effects
   - Implements angle-based pattern variations

3. **Color Generation**
   - Uses 16-bit Linear Feedback Shift Register (LFSR)
   - Produces pseudo-random color patterns
   - Creates smooth transitions between colors
   - Generates 6-bit color output (2-bits each for R,G,B)

### Signal Flow
1. Clock input drives the VGA sync generator
2. Pixel coordinates (x,y) are calculated
3. Distance from center determines pattern region
4. LFSR generates color variations
5. Final color output combines pattern and color data

### Visual Effects
- Creates kaleidoscope-like patterns
- Displays concentric circular regions
- Shows dynamic color transitions
- Produces smooth animations

### Technical Details
- Resolution: 640x480 pixels
- Color depth: 6-bit (64 colors)
- Refresh rate: Standard VGA timing
- Clock frequency: 25MHz
- Reset: Active-low asynchronous reset

### Implementation Notes
- All calculations are performed in real-time
- Uses efficient hardware multipliers for radius calculation
- Implements synchronous design principles
- Includes proper reset handling

## How to test

This VGA display module generates a dynamic mandala pattern with rotating colors. Here's how to test the implementation:

### Test Setup
1. Connect your board to power
2. Connect the VGA cable between your board and monitor
3. Ensure monitor supports 640x480 @ 60Hz resolution

### Basic Functionality Test
1. Power on the system
2. Verify the monitor displays a centered mandala pattern
3. Check for the following indicators:
   - Concentric circular patterns
   - Rotating colors
   - Smooth animation between frames
   - No screen tearing or artifacts

### Expected Behavior
- Center of screen shows a circular mandala pattern
- Pattern rotates smoothly with changing colors
- Three distinct circular regions should be visible
- Colors should shift based on the LFSR pattern
- Display should remain stable without flickering

Explain how to use your project

## External hardware

### Prerequisites
- TinyTapeout development board or compatible FPGA board
- VGA monitor/display
- VGA cable
- Power supply

