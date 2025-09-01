//============================================================================
//  X68000
//
//  Port to MiSTer
//  Copyright (C) 2017,2020 Alexey Melnikov
//  Copyright (C) 2020 Puu
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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

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

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
assign LED_USER  = fdd_active;
assign LED_DISK  = {1'b1, hdd_active};
 
wire [1:0] ar = status[5:4];

assign AUDIO_MIX = status[3:2];

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXX*XXXXXX

`include "build_id.v" 
parameter CONF_STR = {
	"X68000;UART115200,MIDI;",
	"-;",
	"P1,Floppy Disk;",
	"P1S0,D88,FDD0;",
	"P1R9,Save FDD0 changes to SD;",
	"P1RB,Eject FDD0;",
	"P1-;",
	"P1S1,D88,FDD1;",
	"P1RA,Save FDD1 changes to SD;",
	"P1RC,Eject FDD1;",
	"SC2,HDF,SASI Hard Disk;",
	"-;",
	"P3,SRAM;",
	"P3SC3,RAM,SRAM;",
	"P3RD,Load SRAM from SD Card;",
	"P3RE,Save SRAM to SD Card;",
	"-;",
	"P4,Audio & Video;",
	"P4-;",
	"P4O23,Stereo Mix,None,25%,50%,100%;",
//	"d0P4OM,Vertical Crop,Disabled,216p(5x);",
	"d0P4ONQ,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P4ORS,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P4-;",
	"P4o1,Video Frequency,60fps,Original;",
	"P4O45,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
//	"P4OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"h1P5,MT32-pi;",
	"h1P5-;",
	"h1P5OI,Use MT32-pi,Yes,No;",
	"h1P5o9A,Show Info,No,Yes,LCD-On(non-FB),LCD-Auto(non-FB);",
	"h1P5-;",
	"h1P5-,Default Config:;",
	"h1P5OJ,Synth,Munt,FluidSynth;",
	"h1P5OKL,Munt ROM,MT-32 v1,MT-32 v2,CM-32L;",
	"h1P5OTV,SoundFont,0,1,2,3,4,5,6,7;",
	"h1P5-;",
	"h1P5r8,Reset Hanging Notes;",
	"-;",
	"o57,Controller,2 Button,2 Turbo,MegaDrive 3,Magical 6,Capcom 6,Double-DPad,CyberStick;",
//	"o24,KBD layout,JP Func.,JP Pos.,US Std,US Alt,Zuiki X68KZ;",													// To be added soon
	"o23,KBD layout,JP Func.,JP Pos.,US Std,US Alt;",
	"-;",
	"o0,CPU speed,Normal,Turbo;",
	"R7,NMI Button;",
	"R8,Power Button;",
	"R0,Reset;",
	"-;",
	"J,Button 1,Button 2,Run,Select,Button 3,Button 4,Button 5,Button 6;",
	"jn,A,B,Run,Select,X,Y,L,R;",
	"jp,A,B,Run,Select,X,Y,L,R;",
	"I,",
	"MT32-pi: SoundFont #0,",
	"MT32-pi: SoundFont #1,",
	"MT32-pi: SoundFont #2,",
	"MT32-pi: SoundFont #3,",
	"MT32-pi: SoundFont #4,",
	"MT32-pi: SoundFont #5,",
	"MT32-pi: SoundFont #6,",
	"MT32-pi: SoundFont #7,",
	"MT32-pi: MT-32 v1,",
	"MT32-pi: MT-32 v2,",
	"MT32-pi: CM-32L,",
	"MT32-pi: Unknown mode;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_ram, clk_sys;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram), // 80mhz
	.outclk_1(clk_sys), // 40mhz
	.locked(pll_locked)
);

wire clk_vid = clk_ram;

// Video oscillators
// 40.00000 - CPU/Main Oscillator
// 69.55199 - Video clock
// 38.86363 - Also attached to video circuits

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

wire [63:0] status;
wire  [1:0] buttons;

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

wire  [31:0] sd_lba;
wire   [3:0] sd_rd;
wire   [3:0] sd_wr;

wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire  [3:0] img_readonly;
wire [63:0] img_size;

wire [65:0] ps2_key;
wire [64:0] sysrtc;
wire forced_scandoubler;
wire [21:0] gamma_bus;
wire  [7:0] uart1_mode;
wire [31:0] uart1_speed;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy_analog_a, joy_analog_b;

wire        strA_tristate;
wire        strA;
wire  [5:0] joyA = (status[39:37] == 3'b000) ?		// default 2-button
						~{joystick_0[5:4], (joystick_0[0]|joystick_0[6]), (joystick_0[1]|joystick_0[6]), (joystick_0[2]|joystick_0[7]), (joystick_0[3]|joystick_0[7])} :

						// Turbo 2-button
						 (status[39:37] == 3'b001) ?
						~{joyrept_0[1:0], (joystick_0[0]|joystick_0[6]), (joystick_0[1]|joystick_0[6]), (joystick_0[2]|joystick_0[7]), (joystick_0[3]|joystick_0[7])} :

						// MegaDrive 3-button - strobe = low
						 ((status[39:37] == 3'b010) && (strA == 1'b0)) ?
						~{joystick_0[6], joystick_0[4], 1'b1, 1'b1, joystick_0[2], joystick_0[3]} :
						// strobe - high
						 ((status[39:37] == 3'b010) && (strA == 1'b1)) ?
						~{joystick_0[9],  joystick_0[5], joystick_0[0], joystick_0[1], joystick_0[2], joystick_0[3]} :

						// CyberStick (XE-1AP protocol)
						(status[39:37] == 3'b110) ?
						{xe1_trg2, xe1_trg1, xe1_data[3:0]} :

						// Magical 6-button - strobe = low
						 ((status[39:37] == 3'b011) && (strA == 1'b0)) ?
						~{joystick_0[9],  joystick_0[8], joystick_0[0], joystick_0[1], joystick_0[2], joystick_0[3]} :
						// strobe = high
						 ((status[39:37] == 3'b011) && (strA == 1'b1)) ?
						~{joystick_0[5],  joystick_0[4], joystick_0[10],  joystick_0[11], 1'b1, 1'b1} :

						// Capcom 6-button - strobe = low
						 ((status[39:37] == 3'b100) && (strA == 1'b0)) ?
						~{joystick_0[5],  joystick_0[4], joystick_0[0], joystick_0[1], joystick_0[2], joystick_0[3]} :
						// strobe = high
						 ((status[39:37] == 3'b100) && (strA == 1'b1)) ?
						~{joystick_0[6], joystick_0[10], joystick_0[7], joystick_0[8], joystick_0[9], joystick_0[11]} :

						// Double-DPad - strobe = low
						 ((status[39:37] == 3'b101) && (strA == 1'b0)) ?
						~{joystick_0[6],  joystick_0[7], joystick_0[0], joystick_0[1], joystick_0[2], joystick_0[3]} :
						// strobe = high
						 ((status[39:37] == 3'b101) && (strA == 1'b1)) ?
						~{joystick_0[6], joystick_0[7], joystick_0[4], joystick_0[9], joystick_0[5], joystick_0[8]} :

						6'b111111;

wire        strB;
wire        strB_tristate;
wire  [5:0] joyB = ((status[39:37] == 3'b000) || (status[38:36] == 3'b110)) ?		// default 2-button or CyberStick (only support 1 CyberStick)
						~{joystick_1[5:4], (joystick_1[0]|joystick_1[6]), (joystick_1[1]|joystick_1[6]), (joystick_1[2]|joystick_1[7]), (joystick_1[3]|joystick_1[7])} :

						// Turbo 2-button
						 (status[39:37] == 3'b001) ?
						~{joyrept_1[1:0], (joystick_1[0]|joystick_1[6]), (joystick_1[1]|joystick_1[6]), (joystick_1[2]|joystick_1[7]), (joystick_1[3]|joystick_1[7])} :

						// MegaDrive 3-button - strobe = low
						 ((status[39:37] == 3'b010) && (strB == 1'b0)) ?
						~{joystick_1[6], joystick_1[4], 1'b1, 1'b1, joystick_1[2], joystick_1[3]} :
						// strobe - high
						 ((status[39:37] == 3'b010) && (strB == 1'b1)) ?
						~{joystick_1[9],  joystick_1[5], joystick_1[0], joystick_1[1], joystick_1[2], joystick_1[3]} :

						// Magical 6-button - strobe = low
						 ((status[39:37] == 3'b011) && (strA == 1'b0)) ?
						~{joystick_1[9],  joystick_1[8], joystick_1[0], joystick_1[1], joystick_1[2], joystick_1[3]} :
						// strobe = high
						 ((status[39:37] == 3'b011) && (strA == 1'b1)) ?
						~{joystick_1[5],  joystick_1[4], joystick_1[10],  joystick_1[11], 1'b1, 1'b1} :
						
						// Capcom 6-button - strobe = low
						((status[39:37] == 3'b100) && (strB == 1'b0)) ?
						~{joystick_1[5],  joystick_1[4], joystick_1[0], joystick_1[1], joystick_1[2], joystick_1[3]} :
						// strobe = high
						((status[39:37] == 3'b100) && (strB == 1'b1)) ?
						~{joystick_1[6], joystick_1[10], joystick_1[7], joystick_1[8], joystick_1[9], joystick_1[11]}:

						// Double-DPad - strobe = low
						 ((status[39:37] == 3'b101) && (strB == 1'b0)) ?
						~{joystick_1[6],  joystick_1[7], joystick_1[0], joystick_1[1], joystick_1[2], joystick_1[3]} :
						// strobe = high
						 ((status[39:37] == 3'b101) && (strB == 1'b1)) ?
						~{joystick_1[6], joystick_1[7], joystick_1[4], joystick_1[9], joystick_1[5], joystick_1[8]} :

						6'b111111;


////////////////////////////  Joystick values  ////////////////////////////////// 

reg [3:0] scan_counter = 0;
reg [1:0] joyrept_0;
reg [1:0] joyrept_1;


always @(posedge clk_sys) begin
	reg VBlank_ff;

	// turbo-repeat based on VBLANK
	VBlank_ff <= VBlank;
	if ((VBlank_ff == 1'b0) && (VBlank == 1'b1)) begin
		scan_counter <= scan_counter + 1'd1;

		// repeat counters
		joyrept_0[0] <= (joystick_0[8] & scan_counter[2]) | (joystick_0[11] & scan_counter[1]) | joystick_0[4];
		joyrept_0[1] <= (joystick_0[9] & scan_counter[2]) | (joystick_0[10] & scan_counter[1]) | joystick_0[5];
		
		joyrept_1[0] <= (joystick_1[8] & scan_counter[2]) | (joystick_1[11] & scan_counter[1]) | joystick_1[4];
		joyrept_1[1] <= (joystick_1[9] & scan_counter[2]) | (joystick_1[10] & scan_counter[1]) | joystick_1[5];

	end
end

wire xe1_trg1;
wire xe1_trg2;
wire xe1_runbtn;
wire xe1_selbtn;
wire [3:0] xe1_data;


XE1AP #(40) XE1AP		// for CyberStick - 40 clock cycles per microsecond (40MHz)
(
	.reset(reset),
	.clk_sys(clk_sys),

   .joystick_0(joystick_0),
   .joystick_l_analog_0(joy_analog_a),
   .joystick_r_analog_0(joy_analog_b),
	
	.orientation(0),			// throttle on left side, stick on right side
   .req(strA),					// signal requesting response from XE-1AP (on return to high)
									// pin 8 on original 9-pin connector 
   .lo_hi(xe1_trg2),			// pin 6 on original 9-pin connector
   .ack(xe1_trg1),			// pin 7 on original 9-pin connector
   .data(xe1_data),			// Data[3] = pin 4 on original 9-pin connector
									// Data[2] = pin 3 on original 9-pin connector
									// Data[1] = pin 2 on original 9-pin connector
									// Data[0] = pin 1 on original 9-pin connector
   .run_btn(xe1_runbtn),	// need to send back for the XHE-3 PC Engine attachment (not in use here)
   .select_btn(xe1_selbtn)	// need to send back for the XHE-3 PC Engine attachment (not in use here)

);

////////////////////////////  End Joystick  ////////////////////////////////// 


hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2400), .PS2WE(1), .VDNUM(4)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({mt32_newmode, mt32_available, en216p}),
	.info_req(mt32_info_req),
	.info(mt32_info_disp),

	.sd_lba('{sd_lba,sd_lba,sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
 
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ldr_wr),
	
	// .uart_mode(uart1_mode),
	// .uart_speed(uart1_speed),

//	.new_vmode(status[4]), // Use for option to avoid 24khz

	.ps2_kbd_clk_out(ps2_kbd_clk_out),
	.ps2_kbd_data_out(ps2_kbd_data_out),
	.ps2_kbd_clk_in(ps2_kbd_clk_in),
	.ps2_kbd_data_in(ps2_kbd_data_in),
	.ps2_mouse_clk_out(ps2_mouse_clk_out),
	.ps2_mouse_data_out(ps2_mouse_data_out),
	.ps2_mouse_clk_in(ps2_mouse_clk_in),
	.ps2_mouse_data_in(ps2_mouse_data_in),

	.ps2_key(ps2_key),
	
	.RTC(sysrtc),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_l_analog_0(joy_analog_a),
	.joystick_r_analog_0(joy_analog_b)
);

/////////////////  RESET  /////////////////////////

wire [3:0] img_mounted_d;
wire [1:0] fdd_eject_d;
reg [23:0] mount_count[4];
reg [15:0] fdd_eject_count[2];
assign fdd_eject_d[0] = |mount_count[0][23:16] || |fdd_eject_count[0];
assign fdd_eject_d[1] = |mount_count[1][23:16] || |fdd_eject_count[1];
assign img_mounted_d[0] = ~fdd_eject_d[0] && |mount_count[0];
assign img_mounted_d[1] = ~fdd_eject_d[1] && |mount_count[1];
assign img_mounted_d[2] = |mount_count[2];
assign img_mounted_d[3] = |mount_count[3];

reg reset_n = 0;
reg reset;
always @(posedge clk_sys) begin : rst_block
	reg init_reset_n = 0;
	reg old_rst = 0;
	reg [3:0] old_im = 4'd0;
	reg old_download;
	reg [15:0] reset_delayed;
	
	old_download <= ioctl_download;
	old_im <= img_mounted;
	if(~old_download & ioctl_download) reset_n <= 1;
	
	for (logic [2:0] x = 0; x < 3'd4; x=x+1'd1) begin
		if (mount_count[x])
			mount_count[x] <= mount_count[x] - 1'd1;
		if (img_mounted[x])
			mount_count[x] <= 24'hFFFFFF;
	end
	if (fdeject[0])
		fdd_eject_count[0]<= 16'hFFFF;
	if (fdeject[1])
		fdd_eject_count[1]<= 16'hFFFF;
	if (fdd_eject_count[0])
		fdd_eject_count[0] <= fdd_eject_count[0] - 1'd1;
	if (fdd_eject_count[1])
		fdd_eject_count[1] <= fdd_eject_count[1] - 1'd1;

	reset <= buttons[1] | status[0] | RESET | ~init_reset_n | |reset_delayed;

	if (reset_delayed)
		reset_delayed <= reset_delayed - 1'd1;
	if (~old_im[2] && img_mounted[2]) begin
		reset_delayed <= 16'hFFFF;
	end


	old_rst <= status[0];
	if(old_rst & ~status[0]) init_reset_n <= 1;
end

////////////////////////////  MT32pi  ////////////////////////////////// 
wire        mt32_reset    = status[40] | reset;
wire        mt32_disable  = status[18];
wire        mt32_mode_req = status[19];
wire  [1:0] mt32_rom_req  = status[21:20];
wire  [7:0] mt32_sf_req   = status[31:29];
wire  [1:0] mt32_info     = status[42:41];

wire [15:0] mt32_i2s_r, mt32_i2s_l;
wire  [7:0] mt32_mode, mt32_rom, mt32_sf;
wire        mt32_lcd_en, mt32_lcd_pix, mt32_lcd_update;
wire        midi_rx;

wire mt32_newmode;
wire mt32_available;
//wire mt32_use  = mt32_available & ~mt32_disable;
wire mt32_mute = mt32_available &  mt32_disable;

mt32pi mt32pi
(
	.*,
	.reset(mt32_reset),
	.midi_tx(midi_txd | mt32_mute)
);

reg mt32_info_req;
reg [3:0] mt32_info_disp;
always @(posedge clk_sys) begin
	reg old_mode;

	old_mode <= mt32_newmode;
	mt32_info_req <= (old_mode ^ mt32_newmode) && (mt32_info == 1);
	
	mt32_info_disp <= (mt32_mode == 'hA2) ? (4'd1 + mt32_sf[2:0]) :
                     (mt32_mode == 'hA1 && mt32_rom == 0) ?  4'd9 :
                     (mt32_mode == 'hA1 && mt32_rom == 1) ?  4'd10 :
                     (mt32_mode == 'hA1 && mt32_rom == 2) ?  4'd11 : 4'd12;
end

reg mt32_lcd_on;
always @(posedge CLK_VIDEO) begin
	int to;
	reg old_update;

	old_update <= mt32_lcd_update;
	if(to) to <= to - 1;

	if(mt32_info == 2) mt32_lcd_on <= 1;
	else if(mt32_info != 3) mt32_lcd_on <= 0;
	else begin
		if(!to) mt32_lcd_on <= 0;
		if(old_update ^ mt32_lcd_update) begin
			mt32_lcd_on <= 1;
			to <= 90000000 * 2;
		end
	end
end

wire mt32_lcd = mt32_lcd_on & mt32_lcd_en;

///////////////////////////////////////////////////
wire [15:0] aud_r, aud_l, pcm_r, pcm_l, ym_r, ym_l;

wire NMI = status[7];
wire POWER = status[8];
wire [1:0] fdsync = status[10:9];
wire [1:0] fdeject = status[12:11];
wire sramld	= status[13];
wire sramst = status[14];
wire [1:0] kbdtype = status[35:34];

assign CLK_VIDEO = clk_vid;
assign AUDIO_S = 1;

//puu
wire midi_txd;
wire midi_rxd=1;

wire disk_led;

wire [7:0] red, green, blue;
wire HBlank, VBlank, HSync, VSync, ce_pix, vid_de;

wire snd_clockmode;
reg sys_ce;
reg mpu_cep;
reg mpu_cen;
reg snd_ce;
reg [1:0] opm_ce = 0;

always @(posedge clk_sys) begin
	reg [4:0] div_opm;
	reg [1:0] div_sys;
	reg [3:0] div_snd;
	reg [3:0] div_snd2;
	reg turbo = 0;

	div_sys <= div_sys + 1'd1;
	div_snd <= div_snd + 1'd1;
	div_snd2 <= div_snd2 + 1'd1;
	div_opm <= div_opm + 1'd1;

	if (div_snd2 == 9) div_snd2 <= 0;
	if (div_snd == 4)  div_snd <= 0;
	if (div_opm == 19) div_opm <= 0;

	opm_ce[0] <= div_snd2 == 9;
	opm_ce[1] <= div_opm == 19;

	sys_ce <= &div_sys;

	if(&div_sys) turbo <= status[32];
	mpu_cep <= turbo ?  div_sys[0] : ( div_sys[1] & div_sys[0]);
	mpu_cen <= turbo ? ~div_sys[0] : (~div_sys[1] & div_sys[0]);

	snd_ce  <= snd_clockmode ? (div_snd2 == 9) : (div_snd == 4);
end

X68K_top X68K_top
(
	.ramclk     (clk_ram),
	.sysclk     (clk_sys),
	.vidclk     (clk_vid),
	.fdcclk     (clk_sys),
	.sndclk     (clk_sys),
	
	.sys_ce     (sys_ce),
	.mpu_cep    (mpu_cep),
	.mpu_cen    (mpu_cen),
	.snd_ce     (snd_ce),
	.opm_ce     (opm_ce),
	
	.cm_out     (snd_clockmode),

	.plllock    (pll_locked),

	.sysrtc     (sysrtc),

	.pMemCke(SDRAM_CKE),
	.pMemCs_n(SDRAM_nCS),
	.pMemRas_n(SDRAM_nRAS),
	.pMemCas_n(SDRAM_nCAS),
	.pMemWe_n(SDRAM_nWE),
	.pMemUdq(SDRAM_DQMH),
	.pMemLdq(SDRAM_DQML),
	.pMemBa1(SDRAM_BA[1]),
	.pMemBa0(SDRAM_BA[0]),
	.pMemAdr(SDRAM_A),
	.pMemDat(SDRAM_DQ),

	.ldr_addr(ioctl_addr[19:0]),
	.ldr_wdat(ioctl_dout),
	.ldr_aen(ioctl_download & ~ldr_done),
	.ldr_wr(ldr_wr),
	.ldr_ack(ldr_ack),
	.ldr_done(ldr_done),
	.vid_hz(~status[33]),

	.pPs2Clkin(ps2_kbd_clk_out),
	.pPs2Clkout(ps2_kbd_clk_in),
	.pPs2Datin(ps2_kbd_data_out),
	.pPs2Datout(ps2_kbd_data_in),

	.pPmsClkin(ps2_mouse_clk_out),
	.pPmsClkout(ps2_mouse_clk_in),
	.pPmsDatin(ps2_mouse_data_out),
	.pPmsDatout(ps2_mouse_data_in),

	.mist_mounted(img_mounted_d),
	.mist_readonly(img_readonly),
	.mist_imgsize(img_size),

	.mist_lba(sd_lba),
	.mist_rd(sd_rd),
	.mist_wr(sd_wr),
	.mist_ack({sd_ack[3:2], |sd_ack[1:0], |sd_ack[1:0]}),

	.mist_buffaddr(sd_buff_addr),
	.mist_buffdout(sd_buff_dout),
	.mist_buffdin(sd_buff_din),
	.mist_buffwr(sd_buff_wr),

	.pStrA(strA_tristate),		// tri-state logic is used on this signal, but SignalTap can't deal with this.
	.pJoySelA(strA),				// non-tristate version of the line
	.pJoyA(joyA),
	.pStrB(strB_tristate),
	.pJoySelB(strB),
	.pJoyB(joyB),

	.pFDSYNC(fdsync),
	.pFDEJECT(fdd_eject_d),
	.pFDMOTOR(fdd_active),

	.pLed(disk_led),
	.pDip(4'b0000),
	.pPsw({~NMI,~POWER}),
	.pSramld(sramld),
	.pSramst(sramst),

	.pkbdtype(kbdtype),

	//puu
	.pMidi_in(midi_rxd),
	.pMidi_out(midi_txd),

	//.pMidi_in(UART_RXD),
	//.pMidi_out(UART_TXD),

	.pVideoR(red),
	.pVideoG(green),
	.pVideoB(blue),
	.pVideoHS(HSync),
	.pVideoVS(VSync),
	.pVideoHB(HBlank),
	.pVideoVB(VBlank),
	.pVideoEN(vid_de),
	.pVideoClk(ce_pix),
	.pVideoF1(VGA_F1),

	.pSndL(aud_r),
	.pSndR(aud_l),
	
	.pSndYML(ym_l),
	.pSndYMR(ym_r),
	.pSndPCML(pcm_l),
	.pSNDPCMR(pcm_r),

	.rstn(reset_n & ~reset),
	.dHMode(status[45:44]),
	.dVMode(status[46])
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

wire hdd_active;
wire fdd_active;
led hdd_led(clk_sys,  sd_ack[2],   hdd_active);
//led fdd_led(clk_sys, |sd_ack[1:0], fdd_active);


////////////////////////////  AUDIO  ////////////////////////////////////
wire [17:0] mix_r, mix_l;
reg [15:0] out_l, out_r;

localparam [3:0] comp_f1 = 4;
localparam [3:0] comp_a1 = 2;
localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b1 = comp_x1 * comp_a1;

localparam [3:0] comp_f2 = 8;
localparam [3:0] comp_a2 = 4;
localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b2 = comp_x2 * comp_a2;

function [15:0] compr; input [15:0] inp;
	reg [15:0] v, v1, v2;
	begin
		v  = inp[15] ? (~inp) + 1'd1 : inp;
		v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
		v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
		v  = status[21] ? v2 : v1;
		compr = inp[15] ? ~(v-1'd1) : v;
	end
endfunction 

reg [15:0] cmp_l, cmp_r;

always @(posedge CLK_AUDIO) begin
	reg signed [17:0] tmp_l, tmp_r;

	out_l <= aud_l + mt32_i2s_l;
	out_r <= aud_r + mt32_i2s_r;
	
	// tmp_l <= $signed(pcm_l[15:1]) + $signed(ym_l[15:1]) + $signed(mt32_i2s_l);
	// tmp_r <= $signed(pcm_r[15:1]) + $signed(ym_r[15:1]) + $signed(mt32_i2s_r);
		
	// tmp_l <= aud_l + mt32_i2s_l;
	// tmp_r <= aud_r + mt32_i2s_r;
	

	// tmp_l <= {pcm_l, {2{pcm_l[0]}}} + ym_l + (mt32_mute ? 17'd0 : {mt32_i2s_l[15],mt32_i2s_l});
	// tmp_r <= {pcm_r, {2{pcm_r[0]}}} + ym_r + (mt32_mute ? 17'd0 : {mt32_i2s_r[15],mt32_i2s_r});

	// // clamp the output
	// out_l <= (^tmp_l[17:16]) ? {tmp_l[17], {15{tmp_l[16]}}} : tmp_l[17:2];
	// out_r <= (^tmp_r[17:16]) ? {tmp_r[17], {15{tmp_r[16]}}} : tmp_r[17:2];

	// cmp_l <= compr(tmp_l);
	// cmp_r <= compr(tmp_r);
end


assign AUDIO_R = out_r;
assign AUDIO_L = out_l;

////////////////////////////  VIDEO  ////////////////////////////////////

assign VGA_SL = sl[1:0];

wire       vcrop_en = status[22];
wire [3:0] vcopt    = status[26:23];
reg  [4:0] voff;
reg en216p = 0;

always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[28:27])
);

wire [2:0] scale = status[17:15];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

wire [7:0] r_mt, g_mt, b_mt;

assign {r_mt, g_mt, b_mt} = mt32_lcd ? {{2{mt32_lcd_pix}},red[7:2], {2{mt32_lcd_pix}},green[7:2], {2{mt32_lcd_pix}},blue[7:2]} 
	: {red,green,blue};

video_mixer #(.LINE_LENGTH(800), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,

	.VGA_DE(vga_de),
	.hq2x(scale==1),
	.HSync(HSync),
	.HBlank(HBlank),
	.VSync(VSync),
	.VBlank(VBlank),
	.freeze_sync(),

	.R(r_mt),
	.G(g_mt),
	.B(b_mt)
);


endmodule

module led
(
	input      clk,
	input      in,
	output reg out
);

integer counter = 0;
always @(posedge clk) begin
	if(!counter) out <= 0;
	else begin
		counter <= counter - 1'b1;
		out <= 1;
	end
	
	if(in) counter <= 4500000;
end

endmodule
