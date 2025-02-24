import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.binary import BinaryValue

# VGA timing parameters
H_DISPLAY = 640
H_FRONT = 16
H_SYNC = 96
H_BACK = 48
H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK

V_DISPLAY = 480
V_FRONT = 10
V_SYNC = 2
V_BACK = 33
V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK

class VGAMonitor:
    def __init__(self, dut):
        self.dut = dut
        self.hsync_transitions = 0
        self.vsync_transitions = 0
        self.frame_count = 0
        self.pixel_count = 0
        self.prev_hsync = 0
        self.prev_vsync = 0
        self.last_hsync_time = 0
        self.last_vsync_time = 0

    async def monitor_signals(self):
        clock_period = 16.67  # ns (60MHz clock)
        
        while True:
            await RisingEdge(self.dut.clk)
            
            # Get current time
            current_time = cocotb.utils.get_sim_time(units='ns')

            # Monitor HSYNC
            curr_hsync = self.dut.uo_out.value.integer >> 7 & 0x1
            if curr_hsync != self.prev_hsync:
                self.hsync_transitions += 1
                if self.last_hsync_time != 0:
                    hsync_period = current_time - self.last_hsync_time
                    expected_period = H_TOTAL * clock_period
                    if abs(hsync_period - expected_period) > clock_period:
                        self.dut._log.warning(
                            f"HSYNC period error: {hsync_period:.2f}ns (expected {expected_period:.2f}ns)")
                self.last_hsync_time = current_time
                self.pixel_count = 0
            else:
                self.pixel_count += 1
            self.prev_hsync = curr_hsync

            # Monitor VSYNC
            curr_vsync = self.dut.uo_out.value.integer >> 3 & 0x1
            if curr_vsync != self.prev_vsync:
                self.vsync_transitions += 1
                if curr_vsync == 1:
                    self.frame_count += 1
                    self.dut._log.info(f"Frame {self.frame_count} completed at {current_time:.2f}ns")
                if self.last_vsync_time != 0:
                    vsync_period = current_time - self.last_vsync_time
                    expected_period = V_TOTAL * H_TOTAL * clock_period
                    if abs(vsync_period - expected_period) > clock_period * 2:
                        self.dut._log.warning(
                            f"VSYNC period error: {vsync_period:.2f}ns (expected {expected_period:.2f}ns)")
                self.last_vsync_time = current_time
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

    # Reset sequence
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut._log.info("Reset released")
    
    # Wait for signals to stabilize
    await ClockCycles(dut.clk, 100)

    # Wait for multiple frames
    await ClockCycles(dut.clk, H_TOTAL * V_TOTAL * 3)

    # Check timing
    expected_hsync_transitions = 2 * V_TOTAL
    assert abs(monitor.hsync_transitions - expected_hsync_transitions) <= 10, \
        f"HSYNC transitions incorrect: got {monitor.hsync_transitions}, expected ~{expected_hsync_transitions}"

    assert monitor.vsync_transitions >= 4, \
        f"VSYNC transitions incorrect: got {monitor.vsync_transitions}, expected >= 4"

    assert monitor.pixel_count <= H_TOTAL, \
        f"Pixel count per line exceeded: {monitor.pixel_count}"

    # Log results
    dut._log.info("Test completed successfully:")
    dut._log.info(f"  HSYNC transitions: {monitor.hsync_transitions}")
    dut._log.info(f"  VSYNC transitions: {monitor.vsync_transitions}")
    dut._log.info(f"  Frames completed: {monitor.frame_count}")
