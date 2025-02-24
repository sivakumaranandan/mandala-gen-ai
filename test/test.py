import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.regression import TestFactory

async def init_test(dut):
    """Initialize the DUT and start clock"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1
    
    # Wait 10 clock cycles
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

@cocotb.test()
async def test_vga_sync_signals(dut):
    """Test VGA sync signal generation"""
    await init_test(dut)

    # Monitor for one line of video
    hsync_seen = False
    vsync_seen = False
    
    # Check for 800 clock cycles (one line)
    for _ in range(800):
        await RisingEdge(dut.clk)
        if dut.uo_out.value.integer & 0x80:  # Check HSYNC
            hsync_seen = True
        if dut.uo_out.value.integer & 0x10:  # Check VSYNC
            vsync_seen = True

    assert hsync_seen, "HSYNC not detected"
    dut._log.info("HSYNC detected successfully")

@cocotb.test()
async def test_reset_behavior(dut):
    """Test reset behavior"""
    # Start with reset active
    dut.rst_n.value = 0
    
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    # Wait a few clock cycles
    await ClockCycles(dut.clk, 5)
    
    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Check that outputs are active
    assert dut.uo_out.value != 0, "No output activity after reset"

@cocotb.test()
async def test_color_output(dut):
    """Test color output signals"""
    await init_test(dut)
    
    # Wait for active video region
    await ClockCycles(dut.clk, 100)
    
    # Sample a few color values
    colors = []
    for _ in range(10):
        await ClockCycles(dut.clk, 10)
        colors.append(dut.uo_out.value.integer & 0x0F)  # Lower 4 bits are color
    
    # Verify that we see some color variation
    assert len(set(colors)) > 1, "No color variation detected"

# Test configuration
if cocotb.SIM_NAME:
    factory = TestFactory(test_vga_sync_signals)
    factory.generate_tests()

# For running the test directly
if __name__ == "__main__":
    import os
    from cocotb_test.simulator import run
    
    tests_dir = os.path.abspath(os.path.dirname(__file__))
    rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', 'src'))
    
    verilog_sources = [
        os.path.join(rtl_dir, "tt_um_vga_example.v"),
    ]
    
    run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel="tt_um_vga_example",
        module="test_vga",
        sim_build="sim_build",
        waves=True,
        timescale="1ns/1ps",
        plus_args=["+TIMEOUT=100000"]  # Increase timeout
    )
