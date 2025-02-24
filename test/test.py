# test.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

class VGASignals:
    def __init__(self, dut):
        self.dut = dut
        self.hsync_count = 0
        self.vsync_count = 0
        self.prev_hsync = 0
        self.prev_vsync = 0

    def update(self):
        # Extract HSYNC and VSYNC from uo_out
        curr_hsync = (self.dut.uo_out.value.integer >> 7) & 1
        curr_vsync = (self.dut.uo_out.value.integer >> 3) & 1

        # Count transitions
        if curr_hsync != self.prev_hsync:
            self.hsync_count += 1
        if curr_vsync != self.prev_vsync:
            self.vsync_count += 1

        self.prev_hsync = curr_hsync
        self.prev_vsync = curr_vsync

@cocotb.test()
async def test_vga_basic(dut):
    """Basic VGA signal test"""

    # Create clock
    clock = Clock(dut.clk, 16.67, units="ns")  # 60MHz
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Create signal monitor
    vga = VGASignals(dut)

    # Reset
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Monitor for one frame period
    for _ in range(525 * 800):  # One frame worth of pixels
        await RisingEdge(dut.clk)
        vga.update()

    # Check results
    assert vga.hsync_count > 0, "No HSYNC transitions detected"
    assert vga.vsync_count > 0, "No VSYNC transitions detected"

    dut._log.info(f"HSYNC transitions: {vga.hsync_count}")
    dut._log.info(f"VSYNC transitions: {vga.vsync_count}")
