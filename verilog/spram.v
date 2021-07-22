`ifndef _dpram_v_
`define _dpram_v_

/** \file
 * Single Ported RAM wrapper.
 *
 * The up5k has 1024 Kb of single ported block RAM.
 * This is can't read/write simultaneously, so it is necessary to
 * mux the read/write pins.
 *
 * The four `wren` bits allow each nibble to be written individually
 */

module spram_256k(
	input clk,
	input reset = 0,
	input cs = 1,
	input [3:0] wren,
	input [13:0] addr,
	input [15:0] write_data,
	output [15:0] read_data,
	output read_valid
);
	// only mark the read data valid if no writes are in progress
	assign read_valid = wren == 0;

	SB_SPRAM256KA ram(
		.DATAOUT(read_data),
		.DATAIN(write_data),
		.ADDRESS(addr),

		// select writes to either top or bottom byte
		.MASKWREN(wren),
		.WREN(wren != 0),

		.CHIPSELECT(cs && !reset),
		.CLOCK(clk),

		// if we cared about power, maybe we would adjust these
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1)
	);
endmodule


module spram_1m(
	input clk,
	input reset = 0,
	input cs = 1,
	input [15:0] write_addr,
	input [15:0] write_data,
	input [3:0] wren,
	input [15:0] read_addr,
	output [15:0] read_data,
	output read_valid
);
	assign read_valid = wren == 0;
	wire [15:0] addr = read_valid ? read_addr : write_addr;

	wire [15:0] read_data_00;
	wire [15:0] read_data_01;
	wire [15:0] read_data_10;
	wire [15:0] read_data_11;
	wire cs00 = addr[15:14] == 2'b00;
	wire cs01 = addr[15:14] == 2'b01;
	wire cs10 = addr[15:14] == 2'b10;
	wire cs11 = addr[15:14] == 2'b11;

	assign read_data = 
		cs00 ? read_data_00 :
		cs01 ? read_data_01 :
		cs10 ? read_data_10 :
		cs11 ? read_data_11 :
		16'hF0F0;

	spram_256k spram00(
		.clk(clk),
		.reset(reset),
		.cs(cs),
		.addr(addr[13:0]),
		.write_data(write_data),
		.wren(cs00 ? wren : 4'b0000),
		.read_data(read_data_00)
	);
	spram_256k spram01(
		.clk(clk),
		.reset(reset),
		.cs(cs),
		.addr(addr[13:0]),
		.write_data(write_data),
		.wren(cs01 ? wren : 4'b0000),
		.read_data(read_data_01)
	);
	spram_256k spram10(
		.clk(clk),
		.reset(reset),
		.cs(cs),
		.addr(addr[13:0]),
		.write_data(write_data),
		.wren(cs10 ? wren : 4'b0000),
		.read_data(read_data_10)
	);
	spram_256k spram11(
		.clk(clk),
		.reset(reset),
		.cs(cs),
		.addr(addr[13:0]),
		.write_data(write_data),
		.wren(cs11 ? wren : 4'b0000),
		.read_data(read_data_11)
	);

endmodule
`endif
