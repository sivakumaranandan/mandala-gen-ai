import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
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
        self.frame_count = 0

    def get_signal_value(self, signal, bit_position):
        """Safely extract bit value handling X states"""
        try:
            # Try to get value directly
            return (signal.value.integer >> bit_position) & 0x1
        except ValueError:
            # Handle X value by returning previous state
            return 0

    async def monitor_signals(self):
        while True:
            await RisingEdge(self.dut.clk)
            
            # Safely monitor HSYNC transitions
            curr_hsync = self.get_signal_value(self.dut.uo_out, 7)
            if curr_hsync != self.prev_hsync:
                self.hsync_transitions += 1
            self.prev_hsync = curr_hsync

            # Safely monitor VSYNC transitions
            curr_vsync = self.get_signal_value(self.dut.uo_out, 3)
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

    # Create VGA monitor
    monitor = VGAMonitor(dut)
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Start monitoring
    cocotb.start_soon(monitor.monitor_signals())

    # Reset sequence
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for signals to stabilize after reset
    await ClockCycles(dut.clk, 20)

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

    dut._log.info(f"HSYNC transitions: {monitor.hsync_transitions}")
    dut._log.info(f"VSYNC transitions: {monitor.vsync_transitions}")
    dut._log.info(f"Frames counted: {monitor.frame_count}")
