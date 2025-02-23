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

Explain how to use your project

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
