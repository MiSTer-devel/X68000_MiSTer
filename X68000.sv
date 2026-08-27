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
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_SL = 0;
assign VGA_SCALER = 1;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 1;
assign HDMI_BOB_DEINT = 0;

assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
assign LED_USER = (disk_mode_r && no_sasi_loaded) ? fdd_drive_led_state[0] : fdd_active;
assign LED_DISK = (disk_mode_r && no_sasi_loaded) ? {1'b1, fdd_drive_led_state[1]}
                                                   : {1'b1, hdd_active};
 
wire [1:0] ar = status[5:4];

assign AUDIO_MIX = status[3:2];

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXXXXX   XXXX     XXXXX XXXX*XXXXXX

`include "build_id.v" 
parameter CONF_STR = {
	"X68000;UART115200,MIDI;",
	"-;",
	"P1,Floppy Disk;",
	"P1S0,D88XDFDIMHDM,FDD0;",
	"P1R9,Save FDD0 changes to SD;",
	"P1RB,Eject FDD0;",
	"P1-;",
	"P1S1,D88XDFDIMHDM,FDD1;",
	"P1RA,Save FDD1 changes to SD;",
	"P1RC,Eject FDD1;",
	"P1-;",
	"P1-,Use same type in disks;",
	"P1oFG,FDD wait (XDF/DIM),disable,seek,data,seek+data;",
	"SC2,HDF,SASI Hard Disk;",
	"SC4,HDS,SXSI Hard Disk 1;",
	"SC5,HDS,SXSI Hard Disk 2;",
	"SC6,HDS,SXSI Hard Disk 3;",
	"SC7,HDS,SXSI Hard Disk 4;",
	"-;",
	"P3,SRAM;",
	"P3SC3,RAM,SRAM;",
	"P3RD,Load SRAM from SD Card;",
	"P3RE,Save SRAM to SD Card;",
	"P3-;",
	"P3O[68],CPU RAM,DDR3,SDRAM;",
	"P3-;",
	"P3R[75],Inject SXSI driver (+reset);",
	"P3O[76],Load SXSI driver on boot,No,Yes;",
	"P3O[74:71],Visible Memory,Auto,1MB,2MB,3MB,4MB,5MB,6MB,7MB,8MB,9MB,10MB,11MB,12MB;",
	"-;",
	"P4,Audio & Video;",
	"P4-;",
	"P4oQ,OPM Chip,JT51,IKAOPM;",
	"P4O23,Stereo Mix,None,25%,50%,100%;",
	"P4ORS,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P4-;",
	"P4o1,Video Frequency,60fps,Original;",
	"P4O[70:69],Video Mode,Stretch,Native;,;",
	"P4O45,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
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
	"- ;",
	"o57,Joy1 type,2 Button,2 Turbo,MegaDrive 3,Magical 6,Capcom 6,Double-DPad,CyberStick;",
	"oCE,Joy2 type,2 Button,2 Turbo,MegaDrive 3,Magical 6,Capcom 6,Double-DPad,CyberStick;",
	"oB,Joystick swap,No,Yes;",
	"o24,KBD layout,MiSTer,JP Func.,JP Pos.,US Std,US Alt;",
	"-;",
	"o0,CPU speed,Normal,Turbo;",
	"O[67],MIDI Board,Off,On;",
	"R7,NMI Button;",
	"R8,Power Button;",
	"R0,Reset;",
	"- ;",
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
wire clk_vid = clk_ram; // Video uses same 80 MHz clock (no CDC). Timing via polyclock.
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram), // 80 MHz
	.outclk_1(clk_sys), // 40 MHz
	.outclk_2(),         // 80 MHz (unused)
	.locked(pll_locked)
);

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

wire [127:0] status;
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

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy_analog_a, joy_analog_b;

wire  [31:0] sd_lba;
wire   [7:0] sd_rd;
wire   [7:0] sd_wr;

wire  [7:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [7:0] img_mounted;
wire  [7:0] img_readonly;
wire [63:0] img_size;

wire [65:0] ps2_key;
wire [64:0] sysrtc;
wire [21:0] gamma_bus;
wire  [7:0] uart1_mode;
wire [31:0] uart1_speed;

wire [22:0] ddr_addr;
wire [15:0] ddr_din;
wire [15:0] ddr_dout;
wire        ddr_rd;
wire  [1:0] ddr_wr;
wire        ddr_ack;
wire        ddr_ready;

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2400), .PS2WE(1), .VDNUM(8)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({mt32_newmode, mt32_available, 1'b0}),
	.info_req(mt32_info_req),
	.info(mt32_info_disp),

	.sd_lba('{sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
 
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	
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


////////////////////////////  Joysticks  ////////////////////////////////// 

reg  [15:0] joy_in_0;
reg  [15:0] joy_in_1;
reg   [2:0] joy_mode_A;
reg   [2:0] joy_mode_B;

always @(posedge clk_sys) begin
	joy_in_0   <= status[43] ? joystick_1    : joystick_0;
	joy_in_1   <= status[43] ? joystick_0    : joystick_1;
	joy_mode_A <= status[43] ? status[46:44] : status[39:37]; // Joy1 type follows physical joy0; swaps with Joy2 when swap active
	joy_mode_B <= status[43] ? status[39:37] : status[46:44]; // Joy2 type follows physical joy1; swaps with Joy1 when swap active
end

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
		joyrept_0[0] <= (joy_in_0[8] & scan_counter[2]) | (joy_in_0[11] & scan_counter[1]) | joy_in_0[4];
		joyrept_0[1] <= (joy_in_0[9] & scan_counter[2]) | (joy_in_0[10] & scan_counter[1]) | joy_in_0[5];
		
		joyrept_1[0] <= (joy_in_1[8] & scan_counter[2]) | (joy_in_1[11] & scan_counter[1]) | joy_in_1[4];
		joyrept_1[1] <= (joy_in_1[9] & scan_counter[2]) | (joy_in_1[10] & scan_counter[1]) | joy_in_1[5];
	end
end

wire       strA_tristate;
wire       strA;
reg  [5:0] joyA;

wire       strB;
wire       strB_tristate;
reg  [5:0] joyB;

always @(posedge clk_sys) begin
	joyA <=   (joy_mode_A == 3'b000) ?		// default 2-button
				~{joy_in_0[5:4], (joy_in_0[0]|joy_in_0[6]), (joy_in_0[1]|joy_in_0[6]), (joy_in_0[2]|joy_in_0[7]), (joy_in_0[3]|joy_in_0[7])} :

				// Turbo 2-button
				 (joy_mode_A == 3'b001) ?
				~{joyrept_0[1:0], (joy_in_0[0]|joy_in_0[6]), (joy_in_0[1]|joy_in_0[6]), (joy_in_0[2]|joy_in_0[7]), (joy_in_0[3]|joy_in_0[7])} :

				// MegaDrive 3-button - strobe = low
				 ((joy_mode_A == 3'b010) && (strA == 1'b0)) ?
				~{joy_in_0[6], joy_in_0[4], 1'b1, 1'b1, joy_in_0[2], joy_in_0[3]} :
				// strobe - high
				 ((joy_mode_A == 3'b010) && (strA == 1'b1)) ?
				~{joy_in_0[9],  joy_in_0[5], joy_in_0[0], joy_in_0[1], joy_in_0[2], joy_in_0[3]} :

				// CyberStick (XE-1AP protocol)
				(joy_mode_A == 3'b110) ?
				{xe1_trg2, xe1_trg1, xe1_data[3:0]} :

				// Magical 6-button - strobe = low
				 ((joy_mode_A == 3'b011) && (strA == 1'b0)) ?
				~{joy_in_0[9],  joy_in_0[8], joy_in_0[0], joy_in_0[1], joy_in_0[2], joy_in_0[3]} :
				// strobe = high
				 ((joy_mode_A == 3'b011) && (strA == 1'b1)) ?
				~{joy_in_0[5],  joy_in_0[4], joy_in_0[10],  joy_in_0[11], 1'b1, 1'b1} :

				// Capcom 6-button - strobe = low
				 ((joy_mode_A == 3'b100) && (strA == 1'b0)) ?
				~{joy_in_0[5],  joy_in_0[4], joy_in_0[0], joy_in_0[1], joy_in_0[2], joy_in_0[3]} :
				// strobe = high
				 ((joy_mode_A == 3'b100) && (strA == 1'b1)) ?
				~{joy_in_0[6], joy_in_0[10], joy_in_0[7], joy_in_0[8], joy_in_0[9], joy_in_0[11]} :

				// Double-DPad - strobe = low
				 ((joy_mode_A == 3'b101) && (strA == 1'b0)) ?
				~{joy_in_0[6],  joy_in_0[7], joy_in_0[0], joy_in_0[1], joy_in_0[2], joy_in_0[3]} :
				// strobe = high
				 ((joy_mode_A == 3'b101) && (strA == 1'b1)) ?
				~{joy_in_0[6], joy_in_0[7], joy_in_0[4], joy_in_0[9], joy_in_0[5], joy_in_0[8]} :

				6'b111111;

	joyB <=   ((joy_mode_B == 3'b000) || (joy_mode_B == 3'b110)) ?		// default 2-button or CyberStick (only support 1 CyberStick)
				~{joy_in_1[5:4], (joy_in_1[0]|joy_in_1[6]), (joy_in_1[1]|joy_in_1[6]), (joy_in_1[2]|joy_in_1[7]), (joy_in_1[3]|joy_in_1[7])} :

				// Turbo 2-button
				 (joy_mode_B == 3'b001) ?
				~{joyrept_1[1:0], (joy_in_1[0]|joy_in_1[6]), (joy_in_1[1]|joy_in_1[6]), (joy_in_1[2]|joy_in_1[7]), (joy_in_1[3]|joy_in_1[7])} :

				// MegaDrive 3-button - strobe = low
				 ((joy_mode_B == 3'b010) && (strB == 1'b0)) ?
				~{joy_in_1[6], joy_in_1[4], 1'b1, 1'b1, joy_in_1[2], joy_in_1[3]} :
				// strobe - high
				 ((joy_mode_B == 3'b010) && (strB == 1'b1)) ?
				~{joy_in_1[9],  joy_in_1[5], joy_in_1[0], joy_in_1[1], joy_in_1[2], joy_in_1[3]} :

				// Magical 6-button - strobe = low
				 ((joy_mode_B == 3'b011) && (strB == 1'b0)) ?
				~{joy_in_1[9],  joy_in_1[8], joy_in_1[0], joy_in_1[1], joy_in_1[2], joy_in_1[3]} :
				// strobe = high
				 ((joy_mode_B == 3'b011) && (strB == 1'b1)) ?
				~{joy_in_1[5],  joy_in_1[4], joy_in_1[10],  joy_in_1[11], 1'b1, 1'b1} :
				
				// Capcom 6-button - strobe = low
				((joy_mode_B == 3'b100) && (strB == 1'b0)) ?
				~{joy_in_1[5],  joy_in_1[4], joy_in_1[0], joy_in_1[1], joy_in_1[2], joy_in_1[3]} :
				// strobe = high
				((joy_mode_B == 3'b100) && (strB == 1'b1)) ?
				~{joy_in_1[6], joy_in_1[10], joy_in_1[7], joy_in_1[8], joy_in_1[9], joy_in_1[11]}:

				// Double-DPad - strobe = low
				 ((joy_mode_B == 3'b101) && (strB == 1'b0)) ?
				~{joy_in_1[6],  joy_in_1[7], joy_in_1[0], joy_in_1[1], joy_in_1[2], joy_in_1[3]} :
				// strobe = high
				 ((joy_mode_B == 3'b101) && (strB == 1'b1)) ?
				~{joy_in_1[6], joy_in_1[7], joy_in_1[4], joy_in_1[9], joy_in_1[5], joy_in_1[8]} :

				6'b111111;
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

   .joystick_0(joy_in_0),
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

/////////////////  RESET  /////////////////////////

wire [7:0] img_mounted_d;
wire [1:0] fdd_eject_d;
reg [23:0] mount_count[8];
reg [15:0] fdd_eject_count[2];
reg [7:0] disk_present = 0;      // Track which drives have a mounted disk
reg [7:0] post_reset_mount = 0;  // 1-cycle remount pulse for XDF after reset
assign fdd_eject_d[0] = |mount_count[0][23:16] || |fdd_eject_count[0];
assign fdd_eject_d[1] = |mount_count[1][23:16] || |fdd_eject_count[1];
assign img_mounted_d[0] = ~fdd_eject_d[0] && |mount_count[0];
assign img_mounted_d[1] = ~fdd_eject_d[1] && |mount_count[1];
assign img_mounted_d[2] = |mount_count[2];
assign img_mounted_d[3] = |mount_count[3];
assign img_mounted_d[4] = |mount_count[4];
assign img_mounted_d[5] = |mount_count[5];
assign img_mounted_d[6] = |mount_count[6];
assign img_mounted_d[7] = |mount_count[7];

reg reset_n = 0;
reg reset;
always @(posedge clk_sys) begin : rst_block
	reg init_reset_n = 0;
	reg old_rst = 0;
	reg [7:0] old_im = 8'd0;
	reg old_download;
	reg old_reset;
	reg [15:0] reset_delayed;
	reg old_mem_sel;
	reg old_midi_en;
	
	old_download <= ioctl_download;
	old_reset <= reset;
	old_im <= img_mounted;
	if(~old_download & ioctl_download) reset_n <= 1;
	
	post_reset_mount <= 0;
	
	for (logic [3:0] x = 0; x < 4'd8; x=x+1'd1) begin
		if (mount_count[x])
			mount_count[x] <= mount_count[x] - 1'd1;
		if (img_mounted[x]) begin
			mount_count[x] <= 24'hFFFFFF;
			disk_present[x] <= |img_size;
		end
	end
	
	if (old_reset & ~reset) begin
		for (logic [3:0] x = 0; x < 4'd8; x=x+1'd1) begin
			if (disk_present[x])
				mount_count[x] <= 24'h00FFFF;
		end
		post_reset_mount <= disk_present;
	end
	
	if (fdeject[0]) begin
		fdd_eject_count[0]<= 16'hFFFF;
		disk_present[0] <= 0;
	end
	if (fdeject[1]) begin
		fdd_eject_count[1]<= 16'hFFFF;
		disk_present[1] <= 0;
	end
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

	old_mem_sel <= status[68];
	if (old_mem_sel ^ status[68])
		reset_delayed <= 16'hFFFF;

	old_midi_en <= status[67];
	if (old_midi_en ^ status[67])
		reset_delayed <= 16'hFFFF;


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
//Mute hanging notes from the MT32-pi after a core reset
reg        inj_act = 0;
reg        inj_txd = 1;
reg  [6:0] inj_idx;
reg  [3:0] inj_bitn;
reg [10:0] inj_div;
reg [21:0] inj_dly = 0;
wire [7:0] inj_byte = (inj_idx[2:0]==3'd0) ? {4'hB, inj_idx[6:3]} :
                      (inj_idx[2:0]==3'd1) ? 8'h78 :
                      (inj_idx[2:0]==3'd2) ? 8'h00 :
                      (inj_idx[2:0]==3'd3) ? {4'hB, inj_idx[6:3]} :
                      (inj_idx[2:0]==3'd4) ? 8'h7B :
                                             8'h00;
always @(posedge clk_sys) begin : mt32_quiet
	reg old_r;
	old_r <= reset;
	if (reset) begin
		inj_act <= 0;
		inj_txd <= 1;
		inj_dly <= 0;
	end else begin
		if (old_r) inj_dly <= 22'd2000000;
		if (|inj_dly) begin
			inj_dly <= inj_dly - 1'd1;
			if (inj_dly == 22'd1) begin
				inj_act  <= 1;
				inj_idx  <= 0;
				inj_bitn <= 0;
				inj_div  <= 0;
				inj_txd  <= 1;
			end
		end
		if (inj_act) begin
			if (inj_idx[2:0] >= 3'd6) begin
				inj_idx <= inj_idx + 1'd1;
				if (&inj_idx) inj_act <= 0;
			end else begin
				inj_div <= inj_div + 1'd1;
				if (inj_div == 11'd1279) begin
					inj_div <= 0;
					case (inj_bitn)
						4'd0:    inj_txd <= 0;
						4'd9:    inj_txd <= 1;
						default: inj_txd <= inj_byte[inj_bitn-1];
					endcase
					if (inj_bitn == 4'd9) begin
						inj_bitn <= 0;
						inj_idx  <= inj_idx + 1'd1;
						if (&inj_idx) inj_act <= 0;
					end else begin
						inj_bitn <= inj_bitn + 1'd1;
					end
				end
			end
		end else if (!(|inj_dly)) begin
			inj_txd <= 1;
		end
	end
end

mt32pi mt32pi
(
	.*,
	.reset(mt32_reset),
	.midi_tx((inj_act ? inj_txd : UART_TXD) | mt32_mute)
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
wire [3:0] vis_mem = status[74:71];
wire [2:0] kbdtype = status[36:34];
wire sxsi_boot = status[76];
reg  sxsi_boot_pulse = 0;
always @(posedge clk_sys) begin : sxsi_boot_block
	reg old_boot = 1'b0;
	old_boot <= sxsi_boot;
	sxsi_boot_pulse <= 0;
	if (~old_boot & sxsi_boot) sxsi_boot_pulse <= 1'b1;
end
wire [1:0] fddwait = status[48:47];
wire [1:0] vid_mode = status[70:69];

assign CLK_VIDEO = clk_vid;
assign AUDIO_S = 1;

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

reg disk_mode_r = 0;
always @(posedge clk_sys) begin
	if ((img_mounted[0] || img_mounted[1]) && |img_size)
		disk_mode_r <= |ioctl_index[7:6];
end

wire disk_mode = disk_mode_r & (disk_present[0] | disk_present[1]);

ddram ddram_cpu_ram
(
	.clk(clk_sys),
	.rst_n(reset_n & ~reset),
	.addr(ddr_addr),
	.din(ddr_din),
	.rd(ddr_rd),
	.wr(ddr_wr),
	.dout(ddr_dout),
	.ack(ddr_ack),
	.ready(ddr_ready),
	.DDRAM_CLK(DDRAM_CLK),
	.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
	.DDRAM_ADDR(DDRAM_ADDR),
	.DDRAM_DIN(DDRAM_DIN),
	.DDRAM_BE(DDRAM_BE),
	.DDRAM_RD(DDRAM_RD),
	.DDRAM_WE(DDRAM_WE),
	.DDRAM_DOUT(DDRAM_DOUT),
	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
	.DDRAM_BUSY(DDRAM_BUSY)
);

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

	.disk_mode(disk_mode),

	.mist_mounted(img_mounted_d | post_reset_mount),
	.mist_readonly(img_readonly),
	.mist_imgsize(img_size),

	.mist_lba(sd_lba),
	.mist_rd(sd_rd),
	.mist_wr(sd_wr),
	.mist_ack(disk_mode ? {4'b0000, sd_ack[3:0]} : {sd_ack[7:5], sd_ack[4], sd_ack[3:2], |sd_ack[1:0], |sd_ack[1:0]}),

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
	.pFDACTIVE(fdd_drive_activity_raw),
	.pFDEJECTED(fdd_eject_latched),

	.pLed(disk_led),
	.pDip(4'b0000),
	.pPsw({~NMI,~POWER}),
	.pfdwait(fddwait),
	.pSramld(sramld),
	.pSramst(sramst),

	.pkbdtype(kbdtype),

	.pMidi_in(UART_RXD),
	.pMidi_out(UART_TXD),

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
	.vid_mode(vid_mode),
	.dHMode(status[45:44]),
	.dVMode(status[46]),
	.opm_sel(status[58]),
	.pMidi_en(status[67]),
	.use_ddr3(~status[68]),
	.mix_fix(1'b1),
	.ddr_addr(ddr_addr),
	.ddr_din(ddr_din),
	.ddr_dout(ddr_dout),
	.ddr_rd(ddr_rd),
	.ddr_wr(ddr_wr),
	.ddr_ack(ddr_ack),
	.ddr_ready(ddr_ready),
	.sxsi_inject(status[75] | sxsi_boot_pulse),
	.vis_mem(vis_mem)
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
wire [1:0] fdd_drive_activity_raw;
wire [1:0] fdd_drive_activity;
wire [1:0] fdd_eject_latched;
wire [1:0] fdd_drive_led_state;
wire no_sasi_loaded = ~(disk_present[2] | (|disk_present[7:4]));
reg [24:0] fdd_blink_counter = 0;
wire fdd_eject_blink = fdd_blink_counter[24];
always @(posedge clk_sys) begin
	if(reset) fdd_blink_counter <= 0;
	else      fdd_blink_counter <= fdd_blink_counter + 1'd1;
end
assign fdd_drive_led_state[0] = fdd_eject_latched[0] ? fdd_eject_blink : fdd_drive_activity[0];
assign fdd_drive_led_state[1] = fdd_eject_latched[1] ? fdd_eject_blink : fdd_drive_activity[1];
led hdd_led(clk_sys,  sd_ack[2],   hdd_active);
led fdd0_led(clk_sys, fdd_drive_activity_raw[0], fdd_drive_activity[0]);
led fdd1_led(clk_sys, fdd_drive_activity_raw[1], fdd_drive_activity[1]);
//led fdd_led(clk_sys, |sd_ack[1:0], fdd_active);


////////////////////////////  AUDIO  ////////////////////////////////////

reg [15:0] out_l, out_r;
always @(posedge CLK_AUDIO) begin
	out_l <= aud_l + mt32_i2s_l;
	out_r <= aud_r + mt32_i2s_r;
end

assign AUDIO_R = out_r;
assign AUDIO_L = out_l;

////////////////////////////  VIDEO  ////////////////////////////////////

wire vga_de;
wire freak_de;
wire [7:0] vm_r, vm_g, vm_b;
wire vm_hs, vm_vs;
wire [21:0] vm_gamma_bus;
video_freak video_freak
(
	.*,
	.VGA_DE(freak_de),
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[28:27])
);

wire [7:0] r_mt, g_mt, b_mt;

assign {r_mt, g_mt, b_mt} = mt32_lcd ? {{2{mt32_lcd_pix}},red[7:2], {2{mt32_lcd_pix}},green[7:2], {2{mt32_lcd_pix}},blue[7:2]} 
	: {red,green,blue};

video_mixer #(.LINE_LENGTH(800), .HALF_DEPTH(0), .GAMMA(0)) video_mixer
(
	.*,

	.gamma_bus(vm_gamma_bus),
	.VGA_DE(vga_de),
	.VGA_R(vm_r),
	.VGA_G(vm_g),
	.VGA_B(vm_b),
	.VGA_HS(vm_hs),
	.VGA_VS(vm_vs),
	.scandoubler(0),
	.hq2x(0),
	.HSync(HSync),
	.HBlank(HBlank),
	.VSync(VSync),
	.VBlank(VBlank),
	.freeze_sync(),

	.R(r_mt),
	.G(g_mt),
	.B(b_mt)
);

gamma_fast gamma_inst
(
	.clk_vid  (CLK_VIDEO),
	.ce_pix   (CE_PIXEL),
	.gamma_bus(gamma_bus),
	.HSync    (vm_hs),
	.VSync    (vm_vs),
	.HBlank   (1'b0),
	.VBlank   (1'b0),
	.DE       (freak_de),
	.RGB_in   ({vm_r, vm_g, vm_b}),
	.HSync_out(VGA_HS),
	.VSync_out(VGA_VS),
	.HBlank_out(),
	.VBlank_out(),
	.DE_out   (VGA_DE),
	.RGB_out  ({VGA_R, VGA_G, VGA_B})
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
