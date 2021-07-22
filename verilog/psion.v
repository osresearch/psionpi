/*
 * Psion 5MX Display driver and Raspberry PI SPI TFT device
 *
 */
`default_nettype none
//`include "util.v"
`include "uart.v"
`include "spram.v"
`include "spi_display.v"

//`define UART_DISPLAY


module lfsr32(
        input clk,
        input reset,
        output [31:0] out
);
	parameter RESET_STATE = 32'h1;
        reg [31:0] out = RESET_STATE;

        always @(posedge clk)
                if (reset)
                        out <= 1;
                else
                if (out[0])
                        out <= (out >> 1) ^ 32'hD0000001;
                else
                        out <= (out >> 1);
endmodule


module psion_display(
	input clk,
	input reset,

	// physical
	output clk_out,
	output row_out,
	output frame_out,
	output [3:0] data_out,
	output enable_out,

	// frame buffer
	output [7:0] x_out,
	output [7:0] y_out,
	input [3:0] pixel_in
);
	parameter DIVIDER = 5;
	parameter WIDTH = 640 / 4;
	parameter HEIGHT = 240;

	// Divide the input clock into output clock pulses
	// the output clock pulse is twice as long 
	reg [2:0] divider = 0;
	wire rising_edge = divider == 3'b000;
	wire falling_edge = divider == DIVIDER/2;
	always @(posedge clk)
	begin
		if (divider == DIVIDER)
			divider <= 0;
		else
			divider <= divider + 1;
	end;

	reg clk_out = 0;
	assign enable_out = !reset;

	reg [3:0] data_out = 0;

	reg [7:0] x = 0; // up to 640/4 == 160, only need 8 bits
	reg [7:0] y = 0; // up to 240; need 8 bits
	assign x_out = x;
	assign y_out = y;

	// assert the frame output the entire time the first
	// row is being sent to match the data sheet
	reg frame_out = 0;
	reg row_out = 0;

	always @(posedge clk)
	if (reset) begin
		x <= 0;
		y <= 0;
		row_out <= 0;
		frame_out <= 0;
		data_out <= 0;
		clk_out <= 0;
	end else
	if (falling_edge)
	begin
		// hold all the bits
		clk_out <= 0;
	end else
	if (rising_edge)
	begin
		if (frame_out)
		begin
			// drop the row output,
			// then drop the frame output next clock
			if (row_out)
				row_out <= 0;
			else
				frame_out <= 0;
		end else
		if (row_out)
		begin
			row_out <= 0;
		end else

		if (x == WIDTH-1)
		begin
			// end of the row
			x <= 0;
			row_out <= 1;
			if (y == HEIGHT - 1)
			begin
				frame_out <= 1;
				y <= 0;
			end else begin
				y <= y + 1;
			end
		end else begin
			clk_out <= 1;
			x <= x + 1;
			data_out <= ~pixel_in;
		end
	end
endmodule


module top(
	output serial_txd,
	input serial_rxd,
	output spi_cs,
	output led_r,
	output led_g,
	output led_b,

	// SPI display input from Pi
	input gpio_45,
	input gpio_47,
	input gpio_46,
	input gpio_2,

	// LCD display module
	output gpio_23,
	output gpio_25,
	output gpio_26,
	output gpio_27,
	output gpio_32,
	output gpio_35,
	output gpio_31
);
	assign spi_cs = 1; // it is necessary to turn off the SPI flash chip
	reg reset = 0;
	wire clk_48mhz;
	SB_HFOSC inthosc(.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk_48mhz));

	// 24 MHz system clock
	reg clk = 0;
	always @(posedge clk_48mhz)
		clk = !clk;

	// Psion physical interface
	wire psion_frame = gpio_23;
	wire [3:0] psion_data = { gpio_25, gpio_26, gpio_27, gpio_32 };
	//wire [3:0] psion_data = { gpio_32, gpio_27, gpio_26, gpio_25 };
	wire psion_clk = gpio_35;
	wire psion_row = gpio_31;
	wire psion_enable; // not used yet

	// Raspberry PI SPI TFT display interface
	wire spi_tft_cs = gpio_45;
	wire spi_tft_dc = gpio_47;
	wire spi_tft_di = gpio_46;
	wire spi_tft_clk = gpio_2;

	// fill all block rams with the frame buffer for now
	// dual port block ram for the frame buffer
	// 512 * 240 / 8 == 15360 bytes

`define PANEL_WIDTH 640
`define PANEL_HEIGHT 240

	// frame buffer reads by the psion output device
	wire [15:0] read_addr;
	wire [15:0] read_data;
	wire read_valid;

	// frame buffer writes by the spi input device
	reg [3:0] write_enable = 4'b0000;
	reg [15:0] write_addr = 0;
	reg [15:0] write_data = 0;
	reg [15:0] write_mask = 16'hFFFF;

	// allocate all of the single port block ram
	spram_1m fb0(
		.clk(clk),
		.wren(write_enable),
		.write_addr(write_addr),
		.write_data(write_data),
		.read_addr(read_addr),
		.read_data(read_data),
		.read_valid(read_valid)
	);

	// generate a 3 MHz/12 MHz serial clock from the 48 MHz clock
	// this is the 3 Mb/s maximum supported by the FTDI chip
	reg [3:0] baud_clk;
	always @(posedge clk_48mhz) baud_clk <= baud_clk + 1;

	wire [7:0] uart_rxd;
	wire uart_rxd_strobe;
	wire [7:0] uart_txd;
	wire uart_txd_strobe;

	uart_rx rxd(
		.mclk(clk),
		.reset(reset),
		.baud_x4(baud_clk[1]), // 48 MHz / 4 == 12 Mhz
		.serial(serial_rxd),
		.data(uart_rxd),
		.data_strobe(uart_rxd_strobe)
	);

	uart_tx txd(
		.mclk(clk),
		.reset(reset),
		.baud_x1(baud_clk[3]), // 48 MHz / 16 == 3 Mhz
		.serial(serial_txd),
		.data(uart_txd),
		.data_strobe(uart_txd_strobe)
	);

`ifdef UART_DISPLAY
	reg [5:0] addr_x = 0; // 0 - 63
	reg [7:0] addr_y = 0; // 0 - 239

	always @(posedge clk)
		if (!uart_rxd_strobe)
		begin
			//write_enable <= 0;
			uart_txd_strobe <= 0;
		end else
		begin
/*
			write_enable <= 1;
			write_data <= uart_rxd;
			write_addr <= { addr_y, addr_x };
*/
			fb[{addr_y, addr_x}] <= uart_rxd;

			// echo it
			uart_txd <= uart_rxd;
			uart_txd_strobe <= 1;

			if (addr_x == `PANEL_HEIGHT / 8 - 1)
			begin
				addr_x <= 0;
				if (addr_y == `PANEL_HEIGHT-1)
					addr_y <= 0;
				else
					addr_y <= addr_y + 1;
			end else begin
				addr_x <= addr_x + 1;
			end
		end
`else
	// SPI display from the Raspberry Pi
	wire spi_tft_strobe;
	wire [15:0] spi_tft_pixels;
	wire [15:0] spi_tft_x;
	wire [15:0] spi_tft_y;

	spi_display spi_display0(
		//.clk(clk),

		.uart_data(uart_txd),
		//.uart_strobe(uart_txd_strobe),

		// physical interface
		.spi_cs(spi_tft_cs),
		.spi_dc(spi_tft_dc),
		.spi_di(spi_tft_di),
		.spi_clk(spi_tft_clk),

		// incoming data in spi_clk domain
		.pixels(spi_tft_pixels),
		.strobe(spi_tft_strobe),
		.x(spi_tft_x),
		.y(spi_tft_y)
	);

	// convert from spi_clk to clk domain
	reg tft_flag = 0;
	reg [15:0] tft_x0;
	reg [15:0] tft_y0;
	reg [15:0] tft_pixels0;
	reg [15:0] tft_x;
	reg [15:0] tft_y;
	reg [15:0] tft_pixels;

	// turn the strobe into a bit flipping flag
	always @(posedge spi_tft_clk)
	if (spi_tft_strobe)
	begin
		tft_flag <= ~tft_flag;
		tft_x0 <= spi_tft_x;
		tft_y0 <= spi_tft_y;
		tft_pixels0 <= spi_tft_pixels;
	end

	// watch for a bit flip flag and copy the values
	reg last_tft_flag = 0;
	reg tft_strobe = 0;
	always @(posedge clk)
	if (tft_flag == last_tft_flag)
	begin
		tft_strobe <= 0;
	end else begin
		last_tft_flag <= ~last_tft_flag;
		tft_strobe <= 1;
		tft_x <= tft_x0;
		tft_y <= tft_y0;
		tft_pixels <= tft_pixels0;
	end


	// there is probably a better way to average them
	wire [5:0] tft_r = { tft_pixels[15:11], 1'b0 };
	wire [5:0] tft_g = tft_pixels[10:5];
	wire [5:0] tft_b = { tft_pixels[4:0], 1'b0 };
	wire [3:0] tft_gray = (tft_r[5:2] | tft_b[5:2] | tft_r[5:2]);

	reg led_g;
	always @(posedge clk)
	if (tft_strobe
	&& tft_y < `PANEL_HEIGHT
	&& tft_x < `PANEL_WIDTH
	) begin
		// new grayscale pixel in our clock domain!
		// schedule a write to the nibble for this pixel
		write_enable <= 4'b0001 << tft_x[1:0];
		write_addr <= {tft_y[7:0], tft_x[9:2]};
		write_data <= { 12'h000, tft_gray } << (4*tft_x[1:0]);
		led_g <= 0;
	end else begin
		led_g <= 1;
		write_enable <= 0;
	end

`endif

	wire [7:0] fb_x; // 0 - 160 (640/4), but we store a 1024 pitch
	wire [7:0] fb_y; // 0 - 239
	reg [3:0] fb_byte;
	assign read_addr = { fb_y[7:0], fb_x[7:0] };

	// data comes out of the block ram 16 bits at a time,
	// so grab the high bits for our four pixels
	// but only when read_valid is set
	always @(posedge clk)
	begin
		if (read_valid)
			fb_byte <= {
				read_data[ 3],
				read_data[ 7],
				read_data[11],
				read_data[15]
			};
	end

	psion_display psion_lcd(
		.reset(reset),
		.clk(clk),
		// physical interface
		.data_out(psion_data),
		.clk_out(psion_clk),
		.frame_out(psion_frame),
		.row_out(psion_row),
		.enable_out(psion_enable),
		// framebuffer interface
		.x_out(fb_x),
		.y_out(fb_y),
		.pixel_in(fb_byte)
	);


	// debugging output on the up5k rgb led port
	assign led_r = !psion_frame;
	//assign led_g = !uart_rxd_strobe;
	assign led_b = 1; //spi_tft_cs;

endmodule
