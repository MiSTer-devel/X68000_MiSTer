// Mister video sync for x68000 by Jamie Blanks

module mister_sync
(
	input               gclk,
	input               vid_ce,
	input               rstn,
	input  [15:0]       LRAMDAT,
	input  [7:0]        TRAM_DAT,
	input  [7:0]        FRAM_DAT,
	input  [5:0]        CURL,
	input  [6:0]        CURC,
	input               CURE,
	input               TXTMODE,
	input  [1:0]        HMODE,
	input               VMODE,
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

	output              dclk, // This is the pixel CE
	output              LRAMSEL,
	output [9:0]        LRAMADR,
	output [12:0]       TRAM_ADR,
	output [11:0]       FRAM_ADR,
	output [DACRES-1:0] ROUT,
	output [DACRES-1:0] GOUT,
	output [DACRES-1:0] BOUT,
	output [5:0]        RFOUT,
	output [5:0]        GFOUT,
	output [5:0]        BFOUT,
	output              HSYNC,
	output              VSYNC,
	output              VRTC,   // VBlank out
	output              HRTC,   // Hblank out
	output              VIDEN,  // Video DE
	output              HCOMP,
	output              VCOMP,
	output              VPSTART
);
	logic [9:0] VCOUNT;
	logic [7:0] HUCOUNT;
	logic [7:0] HUVCOUNT;

	logic       HCOMPw;
	logic       VCOMPw;
	logic       HCOMPb;
	logic       VCOMPb;
	logic       VISIBLE;
	logic       lVISIBLE;
	logic       LSEL;
	logic       HCOMPl;
	logic       VCOMPl;
	logic       Idat;
	logic       vid_ce_old;
	logic [4:0] Rdat;
	logic [4:0] Gdat;
	logic [4:0] Bdat;
	logic [5:0] X68R;
	logic [5:0] X68G;
	logic [5:0] X68B;
	logic [5:0] TXTR;
	logic [5:0] TXTG;
	logic [5:0] TXTB;
	logic [5:0] Rdat6;
	logic [5:0] Gdat6;
	logic [5:0] Bdat6;
	logic [3:0] Rdat4;
	logic [3:0] Gdat4;
	logic [3:0] Bdat4;
	logic       dsel;
	logic       ssel;
	logic       freq_ce;
	logic       T_BIT;
	logic       X_BIT;
	logic [2:0] T_FGCOLOR;
	logic [2:0] T_BGCOLOR;
	logic [2:0] dotpu_cnt;
	logic [7:0] hvcount;
	logic [9:0] vvcount;

	//wire [31:0] VIV = VFP+VSY+VBP;
	
	wire [7:0] HUVIS = hvend - hvbgn;
	wire [9:0] VVIS = vvend - vvbgn;

	wire [7:0] HIV = htotal - HUVIS;
	wire [9:0] VIV = vtotal - VVIS;
	
	parameter DACRES = 4;
	parameter DOTPU = 4'd8;
	
	assign VRTC = (VCOUNT >= vvbgn) && (VCOUNT < vvend);
	assign HRTC = (HUCOUNT >= hvbgn) && (HUCOUNT < hvend);
	assign HSYNC = HUCOUNT < hsynl;
	assign VSYNC = VCOUNT < vsynl;
	
	assign VIDEN = (VRTC && HRTC);

	TEXTSCRv_m #(
		.TAWIDTH    (13),
		.CURLINE    (4),
		.CBLINKINT  (20),
		.BLINKINT   (20),
		.LWIDTH     (6),
		.CWIDTH     (7)
	) textscr (
		.TRAMADR    (TRAM_ADR),
		.TRAMDAT    (TRAM_DAT),
		.FRAMADR    (FRAM_ADR),
		.FRAMDAT    (FRAM_DAT),
		.BITOUT     (T_BIT),
		.FGCOLOR    (T_FGCOLOR),
		.BGCOLOR    (T_BGCOLOR),
		// .THRUE      (open),
		// .BLINK      (open),
		.CURL       (CURL),
		.CURC       (CURC),
		.CURE       (CURE),
		.CURM       (0),
		.CBLINK     (1),
		.HMODE      (1),
		.VMODE      (1),
		.UCOUNT     (dotpu_cnt),
		.HUCOUNT    (HUCOUNT),
		.VCOUNT     (VCOUNT),
		.HVCOUNT    (hvcount),
		.vvcount    (vvcount),
		.HCOMP      (HCOMPw),
		.VCOMP      (VCOMPw),
		.HUVIS      (HUVIS),
		.HIV        (HIV),
		.VIV        (VIV),
		.VIR        (VRTC),
		.HIR        (HRTC),
		.clk        (gclk),
		.ce         (vid_ce_old),
		.rstn       (rstn)
	);
	
	// 69.55199 - Video clock
	// 38.86363 - Also attached to video circuits
	//                       69.55199       38.86363
	// 15KHz - 55.46Hz       
	// 256x256 = 6.25MHz     11.128304      6.21818
	// 512x256 = 10MHz       6.955199       3.886363
	// 512x512 = 19.75MHz    3.52161        1.96777
	
	// 31Khz - 61.46Hz
	// 256x256 = 7MHz        9.93599        5.55194
	// 512x256 = 11.25MHz    6.18239        3.45454
	// 512x512 = 21.75MHz    3.19778        1.78683
	// 768x512 = 30.25MHz    2.29923        1.28474

	wire [7:0] HUWIDTH = htotal;
	
	assign dclk = vid_ce_old;

	assign HUVCOUNT = (HUCOUNT >= hvbgn) && (HUCOUNT < hvend) ? HUCOUNT-hvbgn : HUVIS;
	assign LRAMADR[2:0] = dotpu_cnt;
	assign LRAMADR[9:3] = hvcount[6:0];
	
	assign lVISIBLE = VIDEN;
	
	assign Rdat = LRAMDAT[10:6];
	assign Gdat = LRAMDAT[15:11];
	assign Bdat = LRAMDAT[5:1];
	assign Idat = LRAMDAT[0];

	assign X68R = lVISIBLE ? {Rdat, Idat} : '0;
	assign X68G = lVISIBLE ? {Gdat, Idat} : '0;
	assign X68B = lVISIBLE ? {Bdat, Idat} : '0;

	assign HCOMPb = (HCOMPw && ~HCOMPl);
	assign VCOMPb = (VCOMPw && ~VCOMPl);

	logic [1:0] freq_cnt;
	
	assign vid_ce_old = freq_ce;

	always @(posedge gclk) begin
		HCOMPl<=HCOMPw;
		VCOMPl<=VCOMPw;
		
		freq_ce <= hfreq ? freq_cnt[0] : &freq_cnt;
		freq_cnt <= freq_cnt + 1'd1;

		if(~rstn) begin
			freq_ce <= 1;
			LSEL <= 0;
			ssel <= 0;
			hvcount <= 0;
			vvcount <= 0;
			dsel <= 0;
			dotpu_cnt <= 0;
		end else if (freq_ce) begin
			dotpu_cnt <= dotpu_cnt + 1'd1;
			dsel <= ~dsel;
			HCOMPw <= 0;
			VCOMPw <= 0;


			if(HCOMPb == 1)
				LSEL <= ~LSEL;
			if(VCOMPb)
				ssel <= ~ssel;

			if (&dotpu_cnt) begin // Horizontal Tick
				if (HRTC)
					hvcount <= hvcount + 1'd1;
				else
					hvcount <= 0;
				HUCOUNT <= HUCOUNT + 1'd1;
				if (HUCOUNT >= htotal) begin
					HCOMPw <= 1;
					HUCOUNT <= 0;
					if (VRTC)
						vvcount <= vvcount + 1'd1;
				else
					vvcount <= 0;
					VCOUNT <= VCOUNT + 1'd1;
					if (VCOUNT >= vtotal) begin
						VCOUNT <= 0;
						VCOMPw <= 1;
					end
				end
			end
		end
	end
	
	assign LRAMSEL  = LSEL;
	assign HCOMP    = HCOMPb;
	assign VCOMP    = VCOMPb;
	assign VPSTART  = (HCOMPb == 1 && VCOUNT==vvbgn);
	
	assign TXTR = T_BIT ? {6{T_FGCOLOR[2]}} : {6{T_BGCOLOR[2]}};
	assign TXTG = T_BIT ? {6{T_FGCOLOR[1]}} : {6{T_BGCOLOR[1]}};
	assign TXTB = T_BIT ? {6{T_FGCOLOR[0]}} : {6{T_BGCOLOR[0]}};
	
	assign Rdat6 = ~TXTMODE ? X68R : TXTR;
	assign Gdat6 = ~TXTMODE ? X68G : TXTG;
	assign Bdat6 = ~TXTMODE ? X68B : TXTB;

	assign Rdat4 = ((LSEL ^ ssel ^ dsel) && ~&Rdat6[5:2] && Rdat6[1]) ? Rdat6[5:2] + 1'd1 : Rdat6[5:2];
	assign Gdat4 = ((LSEL ^ ssel ^ dsel) && ~&Gdat6[5:2] && Gdat6[1]) ? Gdat6[5:2] + 1'd1 : Gdat6[5:2];
	assign Bdat4 = ((LSEL ^ ssel ^ dsel) && ~&Bdat6[5:2] && Bdat6[1]) ? Bdat6[5:2] + 1'd1 : Bdat6[5:2];
	
	assign ROUT = Rdat4;
	assign GOUT = Gdat4;
	assign BOUT = Bdat4;

	assign RFOUT = Rdat6;
	assign GFOUT = Gdat6;
	assign BFOUT = Bdat6;

endmodule