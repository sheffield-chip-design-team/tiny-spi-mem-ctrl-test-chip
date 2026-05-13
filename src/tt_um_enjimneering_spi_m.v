/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_enjimneering_spi_m (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // -----------------------------------------------------------------------------
  // Internal Signals
  // --------------------------------------------------------------------------
    
    // SPI Master Controller
    reg [15:0] addr;               // address to read from
    wire       start;              // pulse to start transaction
    wire       last;               // asserted when this is the last byte to read in sequential mode
    wire       busy;               // set while transactions are in progress
    wire       valid;              // 1 for one clk when data_out is valid
    wire [7:0] data_out;           // received byte
    wire       spi_cs_n;
    wire       spi_sck;
    wire       spi_mosi;

    // VGA Controller
    wire       vga_hsync;          // VGA horizontal sync
    wire       vga_vsync;          // VGA vertical sync  
    wire       display_on;         // high when the current pixel is within the visible display area  
    wire       vga_frame_end;      // high for one clk at the end of each frame
    wire [9:0] vha_screen_hpos;    // horizontal pixel position (0-639)
    wire [9:0] vga_screen_vpos;    // vertical pixel position (0-479)

    // VGA Pixel Color (RR GG BB)
    wire [5:0] pixel_color;          // 6-bit pixel color from 64-color palette (2 bits each for R, G, B)

    // output wire assignments
    reg [7:0] uo_out_r;

// -----------------------------------------------------------------------------
// SPI Fetch with VGA Display
// --------------------------------------------------------------------------
  
  spi_mem_ctrl_core u_spi_mem_ctrl_core (
    .clk         (clk),
    .rst_n       (rst_n | ui_in[7]), // This should probably be tech depenednt reset logic, but for now we can use an input to trigger reset
    
    // Control signals 
    .start       (start),
    .last        (last),
    .addr        (addr),
    .busy        (busy),
    .valid       (valid),
    .data_out    (data_out),

    // SPI signals
    .cs_n        (spi_cs_n), // connect to CS_N
    .sck         (spi_sck),  // connect to SCK
    .mosi        (spi_mosi), // connect to MOSI
    .miso        (uio_in[3])   // connect to MISO
  );

  vga_sync u_vga_sync (
    .clk            (clk),
    .rst            (~rst_n),
    .hsync          (vga_hsync),
    .vsync          (vga_vsync),
    .display_on     (display_on),
    .screen_hpos    (vha_screen_hpos),
    .screen_vpos    (vga_screen_vpos),
    .frame_end      (vga_frame_end)
  );

// --------------------------------------------------------------------------
// Address Control 
// --------------------------------------------------------------------------

  // Fetch Controller
  always @(posedge clk) begin
    if (~rst_n) begin
      addr <= 16'h0000;
    end else if (vga_frame_end) begin
      addr <= addr + 16'h0001;
    end
  end

// --------------------------------------------------------------------------
// IO Assignmenets
// --------------------------------------------------------------------------

  // SPI control signals
  assign start = vga_frame_end & ui_in[1]; // Start SPI transaction at the end of each frame
  assign last  = ui_in[0];                 // Controllable read one byte (no sequential reads)

  assign uio_out[0] = spi_cs_n;
  assign uio_out[1] = spi_sck;
  assign uio_out[2] = spi_mosi;
  assign uio_out[4] = busy;
  assign uio_out[5] = valid;
  assign uio_out[6] = data_out[0];
  assign uio_out[7] = data_out[1];

  assign uio_oe = 8'b11110111;

  // VGA Pixel Color assignments
  assign pixel_color = data_out[5:0]; // connect pixel color to data_out

  // register outputs for glich prevention
  always @(posedge clk) begin
    uo_out_r[0] <= display_on & pixel_color[5]; // R1
    uo_out_r[4] <= display_on & pixel_color[4]; // R2
    uo_out_r[1] <= display_on & pixel_color[3]; // G1
    uo_out_r[5] <= display_on & pixel_color[2]; // G2
    uo_out_r[2] <= display_on & pixel_color[1]; // B1
    uo_out_r[6] <= display_on & pixel_color[0]; // G2
    uo_out_r[3] <= vga_vsync;
    uo_out_r[7] <= vga_hsync;
  end

  assign uo_out = uo_out_r;
  wire unused_inputs = &{ena, ui_in[6:2], uio_in[7:4], uio_in[2:0], data_out[7:2], vha_screen_hpos, vga_screen_vpos, 1'b0};

endmodule
