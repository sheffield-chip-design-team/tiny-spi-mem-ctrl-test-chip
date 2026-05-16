![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# SPI RAM Reader + VGA Timing (Tiny Tapeout)

- [Project datasheet](docs/info.md)

## Overview

This design reads bytes from an external SPI RAM (23LC512-style read command `0x03`) and exposes the data either directly on `uo_out` (SPI mode) or as a 6‑bit RGB value alongside VGA timing signals (VGA mode). The VGA timing core generates 640x480 @ 60 Hz sync signals.

## Top module

- `tt_um_enjimneering_spi_mem`

## Modes

- **SPI mode** (`ui_in[0]=0`): `uo_out` shows the received SPI byte. A one‑cycle `ui_in[1]` pulse starts a read, `ui_in[2]` asserts `last`, and `ui_in[7:4]` select the high address nibble.
- **VGA mode** (`ui_in[0]=1`): `uo_out` outputs `{HS, B0, G0, R0, VS, B1, G1, R1}` with 2‑bit RGB. Fetched SPI bytes are latched into `pixel_col` and displayed as color.

## IO summary

- `uio_out[0]`: `SPI_CS_N`
- `uio_out[1]`: `SPI_SCK`
- `uio_out[2]`: `SPI_MOSI`
- `uio_in[3]`: `SPI_MISO`
- `uio_out[7:5]`: `{SPI_BUSY, SPI_VALID, SPI_LAST}`

See `info.yaml` for the full pin list.

## Simulation

Run the cocotb test:

```sh
cd test
make -B
```
