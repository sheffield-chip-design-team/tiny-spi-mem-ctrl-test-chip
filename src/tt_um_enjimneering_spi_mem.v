/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_enjimneering_spi_mem (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // --------------------------------------------------------------------------------------
  // Internal signals
  // --------------------------------------------------------------------------------------

    // SPI Memory Controller 
    wire [15:0] addr;              // address to read from
    wire        start;             // pulse to start transaction
    wire        last;              // asserted when this is the last byte to read in sequential mode
    wire       busy;               // set while transactions are in progress
    wire       valid;              // 1 for one clk when data_out is valid
    wire [7:0] data_out;           // received byte

    wire       spi_cs_n;           
    wire       spi_sck;
    wire       spi_mosi;
    wire       spi_miso;
    
    // VGA signals
    wire       hsync;
    wire       vsync;

    wire [9:0] pix_x;
    wire [9:0] pix_y;

    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;

    wire [7:0] vga_out;
    wire [7:0] spi_data_out;

    reg [15:0] vga_addr;           // address to read from
    wire       frame_end;          // pulse at the end of each frame
    reg [5:0]  pixel_col;          // 2 bits per color

    // Test mode control
    wire       test_mode;          // when 0, output SPI data on IOs, when 1 on the VGA signals
    reg [7:0]  uo_out_reg;


  // --------------------------------------------------------------------------------------
  // Test logic 
  // --------------------------------------------------------------------------------------

    assign test_mode = ui_in[0];

    assign start = (test_mode == 0)
       ? ui_in[1]
       : (pix_x == 0 && pix_y == 0);

    assign last = (test_mode == 0)
      ? ui_in[2]
      : frame_end;

    assign addr = (test_mode == 0)
      ? {ui_in[7:4], 12'h00}
      : vga_addr;

    // assign uo_out = (test_mode == 0)
    //   ? vga_out
    //   : spi_data_out;

  // --------------------------------------------------------------------------------------
  // SPI signals
  // --------------------------------------------------------------------------------------

    // VGA Fetch Controller - keep track of the last fetched address 
    always @(posedge clk) begin
      if (~rst_n) begin
        vga_addr <= 16'h0000;
      end if (valid) begin
        vga_addr <= vga_addr + 16'h0001;
      end
    end

  // --------------------------------------------------------------------------------------
  // SPI memory controller instance
  // --------------------------------------------------------------------------------------

    spi_mem_ctrl u_spi_mem_ctrl (
      .clk         (clk),
      .rst_n       (rst_n & ~ui_in[3]), 

      // Control signals 
      .start       (start),
      .last        (last),
      .addr        (addr),
      .busy        (busy),
      .valid       (valid),
      .data_out    (spi_data_out),

      // SPI signals
      .cs_n        (spi_cs_n), 
      .sck         (spi_sck), 
      .mosi        (spi_mosi), 
      .miso        (spi_miso)  
    );

  // --------------------------------------------------------------------------------------
  // VGA sync generator  
  // --------------------------------------------------------------------------------------

    vga_sync u_vga_sync (
      .clk            (clk),
      .rst            (~rst_n & ~ui_in[4]), 
      .hsync          (hsync),
      .vsync          (vsync),
      .display_on     (),
      .screen_hpos    (pix_x),
      .screen_vpos    (pix_y),
      .frame_end      (frame_end)
    );

  // --------------------------------------------------------------------------------------
  // Color Control 
  // --------------------------------------------------------------------------------------

    always @(posedge clk) begin
      if (~rst_n) begin 
        pixel_col <= 0;
      end
      else if (valid) begin
        pixel_col <= data_out[5:0];
      end
    end

  // --------------------------------------------------------------------------------------
  // Output Assignments  
  // --------------------------------------------------------------------------------------

    assign uio_oe[7:0]  = 8'b11110111; // drive SPI signals, but not MISO
    
    // SPI IO signals
    assign uio_out[0]   = spi_cs_n;
    assign uio_out[1]   = spi_sck;
    assign uio_out[2]   = spi_mosi;
    assign spi_miso     = uio_in[3];
    
    // data status bits
    assign uio_out[4:3] = data_out[7:6];

    // Status signals for testing
    assign uio_out[7:5] = {busy, valid, last}; // SPI status signals for testing

    // VGA output
    assign {R,G,B}      = pixel_col;
    assign vga_out      = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    always @(posedge clk) begin
     uo_out_reg <= (test_mode == 0)
       ? spi_data_out
       : vga_out;
    end

    assign uo_out = uo_out_reg;
    wire unused_inputs  = &{uio_in[7:4], uio_in[2:0]};
endmodule
