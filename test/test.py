# vga_test.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

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
