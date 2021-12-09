// Mister video sync for x68000 by Jamie Blanks

module mister_sync
(
	input               gclk,
	input               rstn,
	input  [15:0]       LRAMDAT,

	input  [1:0]        HMODE,
	input  [1:0]        VMODE,
	
	input               HRL,    // dock clock divider
	input               hfreq,  // Horizontal frequency: 0 = 15khz 1 = 31khz
	input  [7:0]        htotal, // Total Horizontal Dots divided by 8
	input  [7:0]        hsynl,  // End position of hsync divided by 8
	input  [7:0]        hvbgn,  // Hblank begin divided by 8
	input  [7:0]        hvend,  // Hblank end divided by 8
	input  [9:0]        vtotal, // Total Vertical lines
	input  [9:0]        vsynl,  // End Position of vsync
	input  [9:0]        vvbgn,  // Vblank begin
	input  [9:0]        vvend,  // Vblank end
	input  [7:0]        hadj,   // Horizontal Adjust
	input               v60hz,  // Forces 60hz video
	input  [9:0]        rintl, // Interrupt roster

	output  [1:0]       out_HMODE,
	output  [1:0]       out_VMODE,
	
	output              out_hfreq,  // Horizontal frequency: 0 = 15khz 1 = 31khz
	output  [7:0]       out_htotal, // Total Horizontal Dots times 8
	output  [7:0]       out_hsynl,  // End position of hsync times 8
	output  [7:0]       out_hvbgn,  // Hblank begin times 8 (minus 5?)
	output  [7:0]       out_hvend,  // Hblank end times 8 (minus 5?)
	output  [9:0]       out_vtotal, // Total Vertical lines
	output  [9:0]       out_vsynl,  // End Position of vsync
	output  [9:0]       out_vvbgn,  // Vblank begin
	output  [9:0]       out_vvend,  // Vblank end
	output  [9:0]       out_rintl,

	output logic        pix_ce, // This is the pixel CE
	output              LRAMSEL,
	output [9:0]        LRAMADR,
	output [5:0]        RFOUT,
	output [5:0]        GFOUT,
	output [5:0]        BFOUT,
	output              HSYNC,
	output              VSYNC,
	output  logic       VRTC,   // VBlank out
	output  logic       HRTC,   // Hblank out
	output              VIDEN,  // Video DE
	output              HCOMP,  // Signals the start of a new line
	output              VCOMP,  // Signals the start of a new frame
	output              VPSTART,
	output              f1,
	output              vid_osc
);
	logic [9:0] VCOUNT;
	logic [7:0] HUCOUNT;

	logic       HCOMPw;
	logic       VCOMPw;
	logic       HCOMPb;
	logic       VCOMPb;
	logic       LSEL;
	logic       HCOMPl;
	logic       VCOMPl;
	logic       Idat;
	logic [4:0] Rdat;
	logic [4:0] Gdat;
	logic [4:0] Bdat;
	logic [2:0] dotpu_cnt;
	logic [7:0] hvcount;
	logic [9:0] vvcount;
	logic polyclock;
	logic field;
	logic d_line;
	integer polyclock_cnt, mod_inc;

	wire interlaced = (VMODE[0] == 1'b1 && ~hfreq);

	wire hfreq_ovr = interlaced ? 1'b1 : hfreq; //1'b1;
	wire [1:0] HMODE_ovr = HMODE;//2'b10;
	//wire [1:0] VMODE_ovr = VMODE;
	wire [7:0] htotal_ovr = htotal;//8'd137;
	wire [9:0] vtotal_ovr = ~interlaced ? vtotal : {vtotal[8:0], 1'b1};
	wire [9:0] vsynl_ovr  = vsynl;
	wire [9:0] vvbgn_ovr  = ~interlaced ? vvbgn : {vvbgn[8:0], 1'b1};
	wire [9:0] vvend_ovr  = ~interlaced ? vvend : {vvend[8:0], 1'b1};
	wire [9:0] rintl_ovr  = ~interlaced ? rintl : {rintl[8:0], 1'b1};

	assign out_HMODE    = HMODE;
	assign out_VMODE    = VMODE;
	assign out_hfreq    = hfreq_ovr;
	assign out_htotal   = htotal;
	assign out_hsynl    = hsynl;
	assign out_hvbgn    = hvbgn;
	assign out_hvend    = hvend;
	assign out_vtotal   = vtotal_ovr;
	assign out_vsynl    = vsynl;
	assign out_vvbgn    = vvbgn_ovr;
	assign out_vvend    = vvend_ovr;
	assign out_rintl    = rintl_ovr;

	assign HSYNC = HUCOUNT < hsynl;
	assign VSYNC = VCOUNT < vsynl_ovr;

	assign VIDEN = ~(VRTC || HRTC);
	wire [7:0] htotal_m = htotal_ovr;
	wire [9:0] vtotal_m = vtotal_ovr;
	// 69.55199 - Video clock
	// 38.86363 - Also attached to video circuits
	//                       69.55199       38.86363   80
	// 15KHz - 55.46Hz
	// 256x256 = 6.25MHz                    6          12
	// 512x256 = 10MHz                      4          8
	// 512x512 = 19.75MHz                   2          4

	// 31Khz -  61.46Hz
	// 256x256 = 7MHz         10                       12
	// 512x256 = 11.25MHz     6                        8
	// 512x512 = 21.75MHz     3                        4
	// 768x512 = 30.25MHz     2                        3
	// HRL 0: Dividing ratio 1/2, 1/3, 1/6 
	//     1:1/2, 1/4, 1/8
	// If hfreq is off and 512 mode is on, the monitor is interlaced mode
	// 50.350 crystals are also present on some models to emulate vga
	// They are selected with a HRES of 2'b11
	// Vertical mode if 1 when hfreq is 0, will interlace
	// Vertical mode if 0 when hfreq is 1, will doublescan
	// otherwise, vertical mode just draws lines.
	assign LRAMADR[2:0] = dotpu_cnt;
	assign LRAMADR[9:3] = hvcount[6:0];

	assign Rdat = LRAMDAT[10:6];
	assign Gdat = LRAMDAT[15:11];
	assign Bdat = LRAMDAT[5:1];
	assign Idat = LRAMDAT[0];

	// Rising edge of visible area
	assign HCOMPb = (HCOMPw && ~HCOMPl);
	assign VCOMPb = (VCOMPw && ~VCOMPl);
	

	always_comb begin
		case ({HRL, hfreq_ovr, HMODE_ovr})
			4'h0: mod_inc = v60hz ? 211205 : 205848; // HRL:0 HF:0 H:256
			4'h1: mod_inc = v60hz ? 105603 : 102924; // HRL:0 HF:0 H:512
			4'h2: mod_inc = v60hz ? 211205 : 205848; // HRL:0 HF:0 H:768
			4'h3: mod_inc = 158888; // HRL:0 HF:0 H:###
			4'h4: mod_inc = v60hz ? 79862 : 86266;  // HRL:0 HF:1 H:256
			4'h5: mod_inc = v60hz ? 39931 : 43133;  // HRL:0 HF:1 H:512
			4'h6: mod_inc = v60hz ? 26621 : 28755;  // HRL:0 HF:1 H:768
			4'h7: mod_inc = 39722;  // HRL:0 HF:1 H:###
			4'h8: mod_inc = v60hz ? 211205 : 205848; // HRL:1 HF:0 H:256
			4'h9: mod_inc = v60hz ? 105603 : 102924; // HRL:1 HF:0 H:512
			4'hA: mod_inc = v60hz ? 211205 : 205848; // HRL:1 HF:0 H:768
			4'hB: mod_inc = 158888; // HRL:1 HF:0 H:###
			4'hC: mod_inc = v60hz ? 106483 : 115022; // HRL:1 HF:1 H:256
			4'hD: mod_inc = v60hz ? 53241 : 57511;  // HRL:1 HF:1 H:512
			4'hE: mod_inc = v60hz ? 26621 : 28755;  // HRL:1 HF:1 H:768
			4'hF: mod_inc = 39722;  // HRL:1 HF:1 H:###
			default: mod_inc = 28755;
		endcase
	end

	assign pix_ce = polyclock;
	assign f1 = 1'b0;//(VMODE_ovr[0] && ~hfreq_ovr) ? field : 1'd0;
	assign vid_osc = pix_ce;

	always_ff @(posedge gclk) begin // 80mhz is 12.5ns per tick
		polyclock <= 0;
		polyclock_cnt <= polyclock_cnt + 12500;
		if (polyclock_cnt >= mod_inc) begin
			polyclock <= 1;
			polyclock_cnt <= (polyclock_cnt - mod_inc) + 12500;
		end

		if(~rstn) begin
			LSEL <= 1;
			hvcount <= 0;
			vvcount <= 0;
			dotpu_cnt <= 0;
			polyclock <= 0;
			polyclock_cnt <= 0;
			HCOMPw <= 0;
			VCOMPw <= 0;
			HUCOUNT <= 0;
			VCOUNT <= 0;
			field <= 0;
			HCOMPl <= 0;
			VCOMPl <= 0;
			HRTC <= 1;
			VRTC <= 1;
		end else if (pix_ce) begin
			dotpu_cnt <= dotpu_cnt + 1'd1;
			HCOMPw <= 0;
			VCOMPw <= 0;

			HCOMPl<=HCOMPw;
			VCOMPl<=VCOMPw;

			if (HCOMPb)
				LSEL <= ~LSEL;

			if (&dotpu_cnt) begin // Horizontal Tick
				HUCOUNT <= HUCOUNT + 1'd1;
				if (HUCOUNT == hvbgn + 3'd4)
					HRTC <= 0;
				else if (HUCOUNT == hvend + 3'd4)
					HRTC <= 1;

				if (~HRTC)
					hvcount <= hvcount + 1'd1;
				else
					hvcount <= 0;

				if (HUCOUNT >= htotal_m) begin
					VCOUNT <= VCOUNT + 1'd1;
					if (VCOUNT == vvbgn_ovr)
						VRTC <= 0;
					else if (VCOUNT == vvend_ovr)
						VRTC <= 1;
					HCOMPw <= 1;
					HUCOUNT <= 0;
					if (~VRTC)
						vvcount <= vvcount + 1'd1;
					else
						vvcount <= 0;

					if (VCOUNT >= vtotal_m) begin
						VCOUNT <= 0;
						VCOMPw <= 1;
						field <= ~field;
					end
				end
			end
		end
	end

	assign LRAMSEL  = LSEL;
	assign HCOMP    = HCOMPb & pix_ce;
	assign VCOMP    = VCOMPb & pix_ce;
	assign VPSTART  = HCOMP && VCOUNT==0;

	assign RFOUT = VIDEN ? {Rdat, Idat} : 6'd0;
	assign GFOUT = VIDEN ? {Gdat, Idat} : 6'd0;
	assign BFOUT = VIDEN ? {Bdat, Idat} : 6'd0;
endmodule