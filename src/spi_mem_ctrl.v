// =======================================================================
// Module:      SPI Mem Ctrl
// Project:     Tetra-SoC, by SHaRC
// Description: Reads N bytes from 23LC512-style SPI RAM.
//              Uses sequential mode 0x03 + 16-bit address.
// =======================================================================

module spi_mem_ctrl (
  input  wire        clk,
  input  wire        rst_n,

  // Control signals from regs
  input  wire [15:0] addr,       // address in external RAM
  input  wire        start,      // pulse to start transaction 
  input  wire        last,       // asserted when this is the last byte to read in sequential mode

  // Status back to regs
  output reg         busy,       // set while transactions are in progress
  output reg         valid,      // 1 for one clk when data_out is valid
  output reg  [7:0]  data_out,   // received byte

  // SPI signals
  output reg         cs_n,       // active-low chip select
  output reg         sck,        // SPI clock (mode 0)
  output reg         mosi,       // master-out
  input  wire        miso        // master-in
);

  // States
  localparam ST_IDLE  = 2'd0;
  localparam ST_SEND  = 2'd1;
  localparam ST_RECV  = 2'd2;
  localparam ST_DONE  = 2'd3;

  reg [1:0]  state;
  reg        phase;            // 0: SCK low phase, 1: SCK high phase

  reg [23:0] shift_out;        // 0x03 + addr[15:0]
    reg [6:0]  shift_in;         // incoming byte (top bit formed with MISO)
  reg [4:0]  bit_count;        // fits 24 or 8

  (*keep*) wire clk_shifter = clk;
  (*keep*) wire clk_spi = clk;

  // control fsm
  always @(posedge clk_shifter) begin
      if (!rst_n) begin
          state     <= ST_IDLE;
          phase     <= 1'b0;
          cs_n      <= 1'b1;
          busy      <= 1'b0;
          valid     <= 1'b0;
          data_out  <= 8'h00;
          shift_out <= 24'h000000;
          shift_in  <= 7'h00;
          bit_count <= 5'd0;
      end else begin
          // default
          valid <= 1'b0;
          case (state)
              // -------------------------------------
              ST_IDLE: begin
                  busy  <= 1'b0;
                  cs_n  <= 1'b1;
                  phase <= 1'b0;
                  if (start) begin
                      // latch command + address
                      shift_out <= {8'h03, addr};
                      bit_count <= 5'd24;
                      shift_in  <= 7'h00;
                      cs_n      <= 1'b0;
                      busy      <= 1'b1;
                      state     <= ST_SEND;
                  end
              end
              // ------------------------------------------------------
              // Send 24 bits: command + address, MSB first
              // phase 0: SCK low, drive MOSI
              // phase 1: SCK high, then shift
              // ------------------------------------------------------
              ST_SEND: begin
                  if (phase == 1'b0) begin
                      // low phase
                      phase <= 1'b1;
                  end else begin
                      phase <= 1'b0;
                      shift_out <= {shift_out[22:0], 1'b0};
                      if (bit_count == 5'd1) begin
                          // last bit just sent
                          bit_count <= 5'd8; // prepare to receive 8 bits
                          state     <= ST_RECV;
                      end else begin
                          bit_count <= bit_count - 5'd1;
                      end
                  end
              end
              // ------------------------------------------------------
              // Receive 8 bits on MISO
              // phase 0: SCK low
              // phase 1: SCK high, sample MISO
              // ------------------------------------------------------
              ST_RECV: begin
                  if (phase == 1'b0) begin
                      phase <= 1'b1;
                  end else begin
                      phase <= 1'b0;
                      // sample MISO at rising edge
                      shift_in <= {shift_in[5:0], miso};
                      if (bit_count == 5'd1) begin
                          data_out <= {shift_in[6:0], miso};
                          state    <= ST_DONE;
                      end else begin
                          bit_count <= bit_count - 5'd1;
                      end
                  end
              end
              // ------------------------------------------------------
              ST_DONE: begin  
                  if (last) begin
                    cs_n  <= 1'b1;     // drive cs high to end transaction
                    busy  <= 1'b0;
                    valid  <= 1'b1;    // one-cycle pulse
                    state <= ST_IDLE;
                  end else begin
                    // prepare to receive next byte in sequential mode
                    bit_count <= 5'd8;
                    valid     <= 1'b1;       // one-cycle pulse for this byte
                    shift_out <= 24'h000000; // command + address already sent, just need to keep clocking
                    shift_in  <= 7'h00;
                    cs_n      <= 1'b0;       // keep cs low for sequential read
                    busy      <= 1'b1;
                    state     <= ST_RECV;
                  end
              end
              default: state <= ST_IDLE;
          endcase
      end
  end

  // drive sck and mosi based on state and phase
  always @(posedge clk_spi) begin
    if (!rst_n) begin
      sck       <= 1'b0;
      mosi      <= 1'b0;
    end else begin
      case (state)
          // ------------------------------------------------------
          ST_IDLE: begin
            sck   <= 1'b0;
          end
          // ------------------------------------------------------
          // Send 24 bits: command + address, MSB first
          // phase 0: SCK low, drive MOSI
          // phase 1: SCK high, then shift
          // ------------------------------------------------------
          ST_SEND: begin
            if (phase == 1'b0) begin
              // low phase
              sck  <= 1'b0;
              mosi <= shift_out[23];
            end else begin
              // high phase
              sck  <= 1'b1;
            end
          end
          // ------------------------------------------------------
          // Receive 8 bits on MISO
          // phase 0: SCK low
          // phase 1: SCK high, sample MISO
          // ------------------------------------------------------
          ST_RECV: begin
              if (phase == 1'b0) begin
                  sck   <= 1'b0;
                  mosi  <= 1'b0;  // don't care
              end else begin
                  sck   <= 1'b1;
              end
          end
          // ------------------------------------------------------
          ST_DONE: begin
              sck   <= 1'b0;
          end
        endcase
    end
end

endmodule