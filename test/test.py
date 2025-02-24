import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.regression import TestFactory
import os

# Set X resolution globally
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

async def init_test(dut):
    """Initialize the DUT and start clock"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1
    
    # Wait for clock to stabilize
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for initialization
    await ClockCycles(dut.clk, 100)

@cocotb.test()
async def test_vga_sync_signals(dut):
    """Test VGA sync signal generation"""
    await init_test(dut)

    # Wait for active video region
    await ClockCycles(dut.clk, 800)

    # Monitor for several lines of video
    hsync_seen = False
    vsync_seen = False
    
    # Check for multiple lines
    for _ in range(2400):  # 3 lines worth of cycles
        await RisingEdge(dut.clk)
        try:
            current_output = int(dut.uo_out.value)
            if current_output & 0x80:  # Check HSYNC
                hsync_seen = True
            if current_output & 0x10:  # Check VSYNC
                vsync_seen = True
        except ValueError:
            # Handle X values by treating them as 0
            continue

    assert hsync_seen, "HSYNC not detected"
    assert vsync_seen, "VSYNC not detected"
    dut._log.info("Sync signals detected successfully")

@cocotb.test()
async def test_reset_behavior(dut):
    """Test reset behavior"""
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Initial reset
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)

    # Release reset and wait for active video
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 800)  # Wait for one line

    # Sample multiple points to check for activity
    activity_detected = False
    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        try:
            current_output = int(dut.uo_out.value)
            if current_output != 0:
                activity_detected = True
                break
        except ValueError:
            continue
    
    assert activity_detected, "No output activity after reset"
    dut._log.info("Reset behavior verified successfully")

@cocotb.test()
async def test_color_output(dut):
    """Test color output signals"""
    await init_test(dut)
    
    # Wait for active video region
    await ClockCycles(dut.clk, 800)
    
    # Sample color values over time
    colors = []
    for _ in range(50):
        await ClockCycles(dut.clk, 10)
        try:
            color = int(dut.uo_out.value) & 0x0F  # Lower 4 bits are color
            colors.append(color)
        except ValueError:
            colors.append(0)  # Treat X values as 0
    
    # Verify color variation
    unique_colors = set(colors)
    assert len(unique_colors) > 1, f"No color variation detected. Colors seen: {unique_colors}"
    dut._log.info(f"Color variation verified. Unique colors: {unique_colors}")

@cocotb.test()
async def test_video_timing(dut):
    """Test video timing parameters"""
    await init_test(dut)
    
    # Monitor timing for one complete frame
    line_count = 0
    try:
        prev_hsync = (int(dut.uo_out.value) >> 7) & 1
    except ValueError:
        prev_hsync = 0
    
    for _ in range(525 * 800):  # One frame worth of cycles
        await RisingEdge(dut.clk)
        try:
            curr_hsync = (int(dut.uo_out.value) >> 7) & 1
            
            # Count line transitions
            if prev_hsync == 0 and curr_hsync == 1:
                line_count += 1
                
            prev_hsync = curr_hsync
        except ValueError:
            continue
    
    assert line_count > 0, "No horizontal sync transitions detected"
    dut._log.info(f"Video timing verified. Lines counted: {line_count}")

def value_to_int(value):
    """Safely convert a value to integer, handling X values"""
    try:
        return int(value)
    except ValueError:
        return 0

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
        plus_args=["+TIMEOUT=1000000"],  # Increased timeout
        extra_env={'COCOTB_RESOLVE_X': 'ZEROS'}  # Set X resolution
    )
