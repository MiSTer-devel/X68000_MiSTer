//============================================================================
//  X68000
//
//  Port to MiSTer
//  Copyright (C) 2017,2020 Alexey Melnikov
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;

assign UART_RTS = UART_CTS;
assign UART_DTR = UART_DSR;

assign USER_OUT  = '1;

assign AUDIO_MIX = 0;
assign VGA_SL    = 0;
assign VGA_F1    = 0;

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;

assign LED_USER  = ioctl_download & ~ldr_done;
assign LED_DISK  = {1'b1, sd_act};
assign LED_POWER = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
parameter CONF_STR = {
	"X68000;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"-;",
	"T6,Reset;",
	"J,Fire 1,Fire 2;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_ram, clk_sys, clk_fdd, clk_vid;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram),
	.outclk_1(clk_sys),
	.outclk_2(clk_fdd),
	.outclk_3(clk_vid),
	.locked(pll_locked)
);

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_ram),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [15:0] joystick_0, joystick_1;

wire  [5:0] joyA = ~{joystick_0[5:4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
wire  [5:0] joyB = ~{joystick_1[5:4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;
wire        ps2_mouse_clk_out;
wire        ps2_mouse_data_out;
wire        ps2_mouse_clk_in;
wire        ps2_mouse_data_in;

wire [65:0] ps2_key;

hps_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(600), .PS2WE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	
	.TIMESTAMP(TIMESTAMP),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ldr_wr),

	.ps2_kbd_clk_out(ps2_kbd_clk_out),
	.ps2_kbd_data_out(ps2_kbd_data_out),
	.ps2_kbd_clk_in(ps2_kbd_clk_in),
	.ps2_kbd_data_in(ps2_kbd_data_in),
	.ps2_mouse_clk_out(ps2_mouse_clk_out),
	.ps2_mouse_data_out(ps2_mouse_data_out),
	.ps2_mouse_clk_in(ps2_mouse_clk_in),
	.ps2_mouse_data_in(ps2_mouse_data_in),

	.ps2_key(ps2_key),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

/////////////////  RESET  /////////////////////////

reg reset_n = 0;
always @(posedge clk_sys) begin
	reg old_download;
	
	old_download <= ioctl_download;
	if(~old_download & ioctl_download) reset_n <= 1;
end

wire reset = buttons[1] | status[6];
///////////////////////////////////////////////////

reg  setup = 0;

wire pressed    = (ps2_key[15:8] != 8'hf0);
wire extended   = (~pressed ? (ps2_key[23:16] == 8'he0) : (ps2_key[15:8] == 8'he0));
wire [8:0] code = ps2_key[63:24] ? 9'd0 : {extended, ps2_key[7:0]}; // filter out PRNSCR and PAUSE
always @(posedge clk_sys) begin
	reg old_state;
	reg next_setup = 0;
	old_state <= ps2_key[64];

	if(ps2_key[65]) setup <= next_setup;

	if(old_state != ps2_key[64]) begin
		casex(code)
			'h078: if(pressed) next_setup <= ~setup; // F11
		endcase
	end
end

///////////////////////////////////////////////////

wire [4:0] video_r, video_g, video_b;
wire video_hs, video_vs;

assign VGA_R = {video_r, video_r[4:2]};
assign VGA_G = {video_g, video_g[4:2]};
assign VGA_B = {video_b, video_b[4:2]};
assign CLK_VIDEO = clk_vid;

assign AUDIO_S = 1;

wire disk_led;

X68K_top X68K_top
(
	.ramclk(clk_ram),
	.sysclk(clk_sys),
	.vidclk(clk_vid),
	.fdcclk(clk_fdd),
	.plllock(pll_locked),

	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),

	.kb_clkin(ps2_kbd_clk_out),
	.kb_clkout(ps2_kbd_clk_in),
	.kb_datin(ps2_kbd_data_out),
	.kb_datout(ps2_kbd_data_in),

	.ms_clkin(ps2_mouse_clk_out),
	.ms_clkout(ps2_mouse_clk_in),
	.ms_datin(ps2_mouse_data_out),
	.ms_datout(ps2_mouse_data_in),

	.pJoyA(joyA),
	.pJoyB(joyB),

	.ldr_addr(ioctl_addr[19:0]),
	.ldr_wdat(ioctl_dout),
	.ldr_aen(ioctl_download & ~ldr_done),
	.ldr_wr(ldr_wr),
	.ldr_ack(ldr_ack),
	.ldr_done(ldr_done),

	.sdc_miso(SD_MISO),
	.sdc_mosi(SD_MOSI),
	.sdc_sclk(SD_SCK),
	.sdc_cs(SD_CS),

	.pFd_INDEXn(1),
	.pFd_TRK00n(1),
	.pFd_WPTn(1),
	.pFd_RDATAn(1),
	.pFd_DSKCHG(1),

	.LED(disk_led),

	.setup(setup),

	.VGA_R(video_r),
	.VGA_G(video_g),
	.VGA_B(video_b),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_DE(VGA_DE),
	.VGA_CE(CE_PIXEL),

	.sndL(AUDIO_L),
	.sndR(AUDIO_R),

	.pswn(0),
	.rstn(reset_n & ~reset)
);

wire ldr_ack;
reg ldr_wr = 0;
reg ldr_done = 0;
always @(posedge clk_sys) begin
	reg old_ack, old_download;

	old_download <= ioctl_download;
	old_ack <= ldr_ack;

	if(~old_ack & ldr_ack & ldr_wr) ldr_wr <= 0;
	if(ioctl_wr & ~ldr_done) ldr_wr <= 1;

	if(old_download & ~ioctl_download) ldr_done <= 1;
end


//////////////////   SD LED   ///////////////////
reg sd_act;

always @(posedge clk_sys) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= SD_MOSI;
	old_miso <= SD_MISO;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ SD_MOSI) || (old_miso ^ SD_MISO)) timeout <= 0;
end

endmodule
