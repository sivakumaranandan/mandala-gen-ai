import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
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
        self.debug_count = 0

    def get_signal_value(self, signal, bit_position):
        """Safely extract bit value handling X states"""
        try:
            value = signal.value
            if value.is_resolvable:
                return (value.integer >> bit_position) & 0x1
            return self.prev_hsync if bit_position == 7 else self.prev_vsync
        except ValueError:
            return self.prev_hsync if bit_position == 7 else self.prev_vsync

    async def monitor_signals(self):
        await Timer(1, units='ns')  # Small initial delay
        while True:
            await RisingEdge(dut.clk)
            
            if self.debug_count < 10:
                self.dut._log.debug(f"uo_out value: {self.dut.uo_out.value}")
                self.debug_count += 1

            # Monitor HSYNC transitions
            curr_hsync = self.get_signal_value(self.dut.uo_out, 7)
            if curr_hsync != self.prev_hsync:
                self.hsync_transitions += 1
                self.dut._log.debug(f"HSYNC transition detected: {self.hsync_transitions}")
            self.prev_hsync = curr_hsync

            # Monitor VSYNC transitions
            curr_vsync = self.get_signal_value(self.dut.uo_out, 3)
            if curr_vsync != self.prev_vsync:
                self.vsync_transitions += 1
                if curr_vsync == 1:  # Rising edge of VSYNC
                    self.frame_count += 1
                    self.dut._log.info(f"Frame completed: {self.frame_count}")
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
    monitor_task = cocotb.start_soon(monitor.monitor_signals())

    # Reset sequence with longer stabilization
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for signals to stabilize after reset
    await ClockCycles(dut.clk, 100)

    # Wait for multiple frames to ensure proper counting
    await ClockCycles(dut.clk, H_TOTAL * V_TOTAL * 2)

    # Log current state
    dut._log.info(f"Current HSYNC transitions: {monitor.hsync_transitions}")
    dut._log.info(f"Current VSYNC transitions: {monitor.vsync_transitions}")
    dut._log.info(f"Current frame count: {monitor.frame_count}")

    # Check HSYNC timing with more tolerance
    expected_hsync_transitions = 2 * V_TOTAL  # Two transitions per line
    tolerance = 10  # Allow for some timing variation
    assert abs(monitor.hsync_transitions - expected_hsync_transitions) <= tolerance, \
        f"HSYNC transitions incorrect. Expected ~{expected_hsync_transitions} (±{tolerance}), got {monitor.hsync_transitions}"

    # Check VSYNC timing
    expected_vsync_transitions = 2  # Two transitions per frame
    assert monitor.vsync_transitions >= expected_vsync_transitions, \
        f"VSYNC transitions incorrect. Expected at least {expected_vsync_transitions}, got {monitor.vsync_transitions}"

    # Additional debug information
    dut._log.info("Test completed successfully")
    dut._log.info(f"Final HSYNC transitions: {monitor.hsync_transitions}")
    dut._log.info(f"Final VSYNC transitions: {monitor.vsync_transitions}")
    dut._log.info(f"Final frame count: {monitor.frame_count}")
