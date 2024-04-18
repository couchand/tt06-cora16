`default_nettype none `timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  wire spi_miso, spi_select, spi_clk, spi_mosi;
  assign uio_in[3] = spi_miso;
  assign spi_select = uio_out[1];
  assign spi_clk = uio_out[2];
  assign spi_mosi = uio_out[0];

  wire busy, halt, trap;
  assign busy = uio_out[5];
  assign halt = uio_out[6];
  assign trap = uio_out[7];

  tt_um_couchand_16bit_cpu user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  reg enable_ops, enable_fib_memo, enable_fib_framed, enable_fib_recursive;

  wire spi_select_ops = spi_select & enable_ops;
  wire spi_select_fib_memo = spi_select & enable_fib_memo;
  wire spi_select_fib_framed = spi_select & enable_fib_framed;
  wire spi_select_fib_recursive = spi_select & enable_fib_recursive;

  assign spi_miso = enable_ops ? spi_miso_ops
    : enable_fib_memo ? spi_miso_fib_memo
    : enable_fib_framed ? spi_miso_fib_framed
    : enable_fib_recursive ? spi_miso_fib_recursive
    : 0;

  reg debug_clk;
  reg [23:0] debug_addr;

  wire [31:0] debug_data_ops;
  wire spi_miso_ops;
  sim_spi_ram #(
    .INIT_FILE("ops.mem")
  ) spi_ram_ops (
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_select(spi_select_ops),
    .spi_miso(spi_miso_ops),
    .debug_clk(debug_clk),
    .debug_addr(debug_addr),
    .debug_data(debug_data_ops)
  );

  wire [31:0] debug_data_fib_memo;
  wire spi_miso_fib_memo;
  sim_spi_ram #(
    .INIT_FILE("fib_memo.mem")
  ) spi_ram_fib_memo (
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_select(spi_select_fib_memo),
    .spi_miso(spi_miso_fib_memo),
    .debug_clk(debug_clk),
    .debug_addr(debug_addr),
    .debug_data(debug_data_fib_memo)
  );

  wire [31:0] debug_data_fib_framed;
  wire spi_miso_fib_framed;
  sim_spi_ram #(
    .INIT_FILE("fib_framed.mem")
  ) spi_ram_fib_framed (
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_select(spi_select_fib_framed),
    .spi_miso(spi_miso_fib_framed),
    .debug_clk(debug_clk),
    .debug_addr(debug_addr),
    .debug_data(debug_data_fib_framed)
  );

  wire [31:0] debug_data_fib_recursive;
  wire spi_miso_fib_recursive;
  sim_spi_ram #(
    .INIT_FILE("fib_recursive.mem")
  ) spi_ram_fib_recursive (
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_select(spi_select_fib_recursive),
    .spi_miso(spi_miso_fib_recursive),
    .debug_clk(debug_clk),
    .debug_addr(debug_addr),
    .debug_data(debug_data_fib_recursive)
  );

endmodule
