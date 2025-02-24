# vga_test.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.binary import BinaryValue

# VGA Constants
H_VISIBLE = 640
H_FRONT_PORCH = 16
H_SYNC = 96
H_BACK_PORCH = 48
H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH

V_VISIBLE = 480
V_FRONT_PORCH = 10
V_SYNC = 2
V_BACK_PORCH = 33
V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH

class VGAMonitor:
    def __init__(self, dut):
        self.dut = dut
        self.hsync_transitions = 0
        self.vsync_transitions = 0
        self.prev_hsync = 0
        self.prev_vsync = 0
        self.active_pixels = 0
        self.frame_count = 0

    async def monitor_signals(self):
        while True:
            await RisingEdge(self.dut.clk)
            
            # Monitor HSYNC transitions
            curr_hsync = self.dut.uo_out.value.integer >> 7 & 0x1
            if curr_hsync != self.prev_hsync:
                self.hsync_transitions += 1
            self.prev_hsync = curr_hsync

            # Monitor VSYNC transitions
            curr_vsync = self.dut.uo_out.value.integer >> 3 & 0x1
            if curr_vsync != self.prev_vsync:
                self.vsync_transitions += 1
                if curr_vsync == 1:  # Rising edge of VSYNC
                    self.frame_count += 1
            self.prev_vsync = curr_vsync

            # Monitor active pixels
            if self.is_active_pixel():
                self.active_pixels += 1

    def is_active_pixel(self):
        rgb = self.dut.uo_out.value.integer & 0x77
        return rgb != 0

@cocotb.test()
async def test_vga_timing(dut):
    """Test VGA timing specifications"""

    # Initialize clock (60MHz)
    clock = Clock(dut.clk, 16.67, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Create VGA monitor
    monitor = VGAMonitor(dut)
    cocotb.start_soon(monitor.monitor_signals())

    # Reset sequence
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Wait for one complete frame
    await ClockCycles(dut.clk, H_TOTAL * V_TOTAL)

    # Check HSYNC timing
    expected_hsync_transitions = 2 * V_TOTAL  # Two transitions per line
    assert abs(monitor.hsync_transitions - expected_hsync_transitions) <= 2, \
        f"HSYNC transitions incorrect. Expected ~{expected_hsync_transitions}, got {monitor.hsync_transitions}"

    # Check VSYNC timing
    expected_vsync_transitions = 2  # Two transitions per frame
    assert monitor.vsync_transitions >= expected_vsync_transitions, \
        f"VSYNC transitions incorrect. Expected at least {expected_vsync_transitions}, got {monitor.vsync_transitions}"

@cocotb.test()
async def test_pattern_generation(dut):
    """Test pattern and color generation"""

    clock = Clock(dut.clk, 16.67, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Monitor color changes
    colors_seen = set()
    monitor = VGAMonitor(dut)

    # Sample multiple frames
    for _ in range(3):
        await ClockCycles(dut.clk, H_TOTAL * V_TOTAL)
        colors = dut.uo_out.value.integer & 0x77
        colors_seen.add(colors)

    # Verify pattern generation
    assert len(colors_seen) > 1, "Pattern should generate multiple colors"
    assert monitor.active_pixels > 0, "No active pixels detected"

@cocotb.test()
async def test_radius_patterns(dut):
    """Test radius-based pattern generation"""

    clock = Clock(dut.clk, 16.67, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Wait to reach center of screen
    await ClockCycles(dut.clk, (V_TOTAL * H_TOTAL) // 2)

    # Sample center pixels
    center_colors = []
    for _ in range(10):
        await ClockCycles(dut.clk, 1)
        center_colors.append(dut.uo_out.value.integer & 0x77)

    # Sample edge pixels
    edge_colors = []
    await ClockCycles(dut.clk, H_TOTAL * 10)  # Move to edge
    for _ in range(10):
        await ClockCycles(dut.clk, 1)
        edge_colors.append(dut.uo_out.value.integer & 0x77)

    # Verify different patterns at center vs edge
    assert center_colors != edge_colors, "Center and edge patterns should differ"
