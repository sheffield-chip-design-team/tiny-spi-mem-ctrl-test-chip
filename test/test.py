# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_spi_read_top(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    dut.ram.mem[0].value = 0xA5
    dut.ram.mem[1].value = 0x5A

    ui_in = 0
    ui_in |= 0 << 0  # test_mode = 0 (SPI)
    ui_in |= 1 << 1    # start pulse
    ui_in |= 1 << 2    # last
    ui_in |= 0x0 << 4  # addr high nibble

    dut.ui_in.value = ui_in
    await ClockCycles(dut.clk, 1)
    
    dut.ui_in.value = 0

    timeout_counter = 0
    
    for _ in range(1000):
        timeout_counter += 1
        if int(dut.uio_out.value) & (1 << 6):
            break
        await RisingEdge(dut.clk)

    if timeout_counter >= 1000:
        raise TimeoutError("Timeout waiting for SPI read to complete")
    
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 0xA5
