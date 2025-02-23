# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_vga_basic(dut):
    """Basic test for VGA controller"""
    
    # Start clock
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Wait for a few cycles and check if signals are changing
    old_hsync = dut.uo_out.value
    await ClockCycles(dut.clk, 100)
    new_hsync = dut.uo_out.value

    # Check if output is changing (indicating active scanning)
    assert old_hsync != new_hsync, "VGA signals not changing"

    dut._log.info("Test completed")
