import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_vga_basic(dut):
    # Start the clock
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())

    # Reset the design
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1

    # Wait 10 clock cycles
    await ClockCycles(dut.clk, 10)

    # Release reset
    dut.rst_n.value = 1

    # Wait for a full frame
    # For 640x480@60Hz, one frame is approximately 800*525 clock cycles
    await ClockCycles(dut.clk, 800*525)

    # Check that hsync and vsync are being generated
    hsync_transitions = 0
    vsync_transitions = 0
    prev_hsync = dut.uo_out.value.integer >> 7 & 1
    prev_vsync = dut.uo_out.value.integer >> 4 & 1

    # Monitor sync signals for a while
    for _ in range(1000):
        await RisingEdge(dut.clk)
        curr_hsync = dut.uo_out.value.integer >> 7 & 1
        curr_vsync = dut.uo_out.value.integer >> 4 & 1
        
        if curr_hsync != prev_hsync:
            hsync_transitions += 1
        if curr_vsync != prev_vsync:
            vsync_transitions += 1
            
        prev_hsync = curr_hsync
        prev_vsync = curr_vsync

    # Verify that we're seeing sync pulses
    assert hsync_transitions > 0, "No horizontal sync transitions detected"
    assert vsync_transitions > 0, "No vertical sync transitions detected"

@cocotb.test()
async def test_color_changes(dut):
    # Start the clock
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Monitor color output changes over multiple frames
    prev_colors = dut.uo_out.value.integer & 0x0F
    color_changes = 0

    # Watch for color changes over several frames
    for _ in range(800*525*3):  # 3 frames
        await RisingEdge(dut.clk)
        curr_colors = dut.uo_out.value.integer & 0x0F
        
        if curr_colors != prev_colors:
            color_changes += 1
            
        prev_colors = curr_colors

    # Verify that colors are changing
    assert color_changes > 0, "No color changes detected"

# Add this to your test.py if you want to run the tests directly
if __name__ == "__main__":
    import os
    import sys
    from cocotb_test.simulator import run
    
    run(
        verilog_sources=["tt_um_vga_example.v"],
        toplevel="tt_um_vga_example",
        module="test",
        waves=True
    )
