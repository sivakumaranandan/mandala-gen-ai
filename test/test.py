# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb.binary import BinaryValue

# VGA Constants for 640x480@60Hz
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

@cocotb.test()
async def test_vga_signals(dut):
    """Comprehensive test for VGA controller"""
    
    # Start clock (25MHz)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Test HSYNC
    async def check_hsync():
        old_hsync = dut.uo_out[7].value
        hsync_changes = 0
        for _ in range(H_TOTAL):  # Wait for one horizontal line
            await RisingEdge(dut.clk)
            new_hsync = dut.uo_out[7].value
            if old_hsync != new_hsync:
                hsync_changes += 1
            old_hsync = new_hsync
        assert hsync_changes >= 2, f"HSYNC should change at least twice per line, got {hsync_changes} changes"

    # Test VSYNC
    async def check_vsync():
        old_vsync = dut.uo_out[4].value
        vsync_changes = 0
        for _ in range(V_TOTAL * H_TOTAL):  # Wait for one frame
            await RisingEdge(dut.clk)
            new_vsync = dut.uo_out[4].value
            if old_vsync != new_vsync:
                vsync_changes += 1
            old_vsync = new_vsync
        assert vsync_changes >= 2, f"VSYNC should change at least twice per frame, got {vsync_changes} changes"

    # Test RGB signals
    async def check_rgb():
        rgb_active = False
        for _ in range(H_TOTAL):
            await RisingEdge(dut.clk)
            # Check if any RGB signals are active
            r = (dut.uo_out[0].value or dut.uo_out[3].value)
            g = (dut.uo_out[1].value or dut.uo_out[2].value)
            b = (dut.uo_out[5].value or dut.uo_out[6].value)
            if r or g or b:
                rgb_active = True
        assert rgb_active, "No RGB activity detected during visible region"

    # Run all checks
    await check_hsync()
    dut._log.info("HSYNC test passed")
    
    await check_vsync()
    dut._log.info("VSYNC test passed")
    
    await check_rgb()
    dut._log.info("RGB test passed")

    # Additional timing checks
    async def check_timing():
        hsync_active = 0
        vsync_active = 0
        for _ in range(H_TOTAL * 2):  # Check over two lines
            await RisingEdge(dut.clk)
            if dut.uo_out[7].value == 0:  # Active low HSYNC
                hsync_active += 1
            if dut.uo_out[4].value == 0:  # Active low VSYNC
                vsync_active += 1
        
        assert H_SYNC-5 <= hsync_active <= H_SYNC+5, f"HSYNC timing out of spec: {hsync_active} cycles"

    await check_timing()
    dut._log.info("Timing test passed")
    dut._log.info("All VGA tests completed successfully")

