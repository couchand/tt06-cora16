/*
 * Copyright (c) 2024 Andrew Dona-Couch
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module cpu (
    input  wire       clk,
    input  wire       rst_n,

    output wire       spi_mosi,
    output wire       spi_select,
    output wire       spi_clk,
    input  wire       spi_miso,

    input  wire       step,
    output wire       busy,
    output wire       halt,
    output wire       trap,

    input  wire [7:0] data_in,
    output reg [7:0] data_out
);

  reg [15:0] pc;
  reg [15:0] inst;
  reg [15:0] accum;

  wire [15:0] rhs;
  wire inst_nop, inst_load, inst_add, inst_branch, inst_out_lo;
  wire source_imm, source_ram;
  wire decoding = (state == ST_INST_EXEC0) | (state == ST_INST_EXEC1);
  decoder inst_decoder(
    .en(decoding),
    .inst(inst),
    .data(data_in),
    .rhs(rhs),
    .inst_nop(inst_nop),
    .inst_load(inst_load),
    .inst_add(inst_add),
    .inst_branch(inst_branch),
    .inst_out_lo(inst_out_lo),
    .source_imm(source_imm),
    .source_ram(source_ram)
  );

  reg [8:0] state;

  localparam ST_INIT = 0;
  localparam ST_HALT = 1;
  localparam ST_TRAP = 2;
  localparam ST_LOAD_INST0 = 3;
  localparam ST_LOAD_INST1 = 4;
  localparam ST_INST_EXEC0 = 5;
  localparam ST_INST_EXEC1 = 6;

  assign busy = state != ST_INIT & state != ST_HALT & state != ST_TRAP;
  assign halt = state == ST_HALT;
  assign trap = state == ST_TRAP;

  wire [15:0] ram_addr = (state == ST_LOAD_INST0) ? pc
    : ((state == ST_INST_EXEC0) & source_ram) ? rhs
    : 0;
  wire ram_start_read = (state == ST_LOAD_INST0) ? 1
    : ((state == ST_INST_EXEC0) & source_ram) ? 1
    : 0;
  reg [15:0] ram_data_in;
  reg ram_start_write;
  wire [15:0] ram_data_out;
  wire ram_busy;

  spi_ram_controller #(
    .DATA_WIDTH_BYTES(2),
    .ADDR_BITS(16)
  ) spi_ram (
    .clk(clk),
    .rstn(rst_n),
    .spi_miso(spi_miso),
    .spi_select(spi_select),
    .spi_clk_out(spi_clk),
    .spi_mosi(spi_mosi),
    .addr_in(ram_addr),
    .data_in(ram_data_in),
    .start_read(ram_start_read),
    .start_write(ram_start_write),
    .data_out(ram_data_out),
    .busy(ram_busy)
  );

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= ST_INIT;
      pc <= 0;
      inst <= 0;
      accum <= 0;
      ram_data_in <= 0;
      ram_start_write <= 0;
      data_out <= 0;
    end else if (~halt & ~trap) begin
      if (state == ST_INIT) begin
        if (step) begin
          state <= ST_LOAD_INST0;
        end
      end else if (state == ST_LOAD_INST0) begin
        state <= ST_LOAD_INST1;
      end else if (state == ST_LOAD_INST1) begin
        if (!ram_busy) begin
          inst <= ram_data_out;
          state <= ST_INST_EXEC0;
        end
      end else if (state == ST_INST_EXEC0) begin
        if (inst_nop) begin
          pc <= pc + 1;
          state <= ST_INIT;
        end else if (inst_load) begin
          if (source_imm) begin
            accum <= rhs;
            pc <= pc + 2;
            state <= ST_INIT;
          end else if (source_ram) begin
            state <= ST_INST_EXEC1;
          end
        end else if (inst_add) begin
          if (source_imm) begin
            accum <= accum + rhs;
            pc <= pc + 2;
            state <= ST_INIT;
          end else if (source_ram) begin
            state <= ST_INST_EXEC1;
          end
        end else if (inst_branch) begin
          pc <= pc + 2 + rhs;
          state <= ST_INIT;
        end else if (inst_out_lo) begin
          pc <= pc + 1;
          state <= ST_INIT;
          data_out <= accum[7:0];
        end else begin
          state <= ST_TRAP;
        end
      end else if (state == ST_INST_EXEC1) begin
        if (!ram_busy) begin
          if (inst_load) begin
            accum <= ram_data_out;
            pc <= pc + 2;
            state <= ST_INIT;
          end else if (inst_add) begin
            accum <= accum + ram_data_out;
            pc <= pc + 2;
            state <= ST_INIT;
          end else begin
            state <= ST_TRAP;
          end
        end
      end else begin
        state <= ST_TRAP;
      end
    end
  end

endmodule
