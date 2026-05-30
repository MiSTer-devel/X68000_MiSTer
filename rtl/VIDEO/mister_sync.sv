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
	output logic        VRTC,   // VBlank out
	output logic        HRTC,   // Hblank out
	output logic        VRTC_b,
	output logic        HRTC_b,
	output              VIDEN,  // Video DE
	output              HCOMP,  // Signals the start of a new line
	output              VCOMP,  // Signals the start of a new frame
	output              VPSTART,
	output              f1,
	output              vid_osc,
	output logic        out_is_24khz
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

	// --- Dynamic 60 Hz divider ---
	logic [31:0] mod_inc_dyn;
	logic [31:0] div_dvd;
	logic [17:0] div_rem;
	logic [31:0] div_quot;
	logic [18:0] div_div;
	logic [5:0]  div_cnt;
	logic [7:0]  div_ht_r;
	logic [9:0]  div_vt_r;
	logic        div_v60_r;

	wire interlaced = (VMODE[0] == 1'b1 && ~hfreq);

	wire hfreq_ovr = interlaced ? 1'b1 : hfreq; //1'b1;
	wire [1:0] HMODE_ovr = HMODE;//2'b10;
	wire [1:0] VMODE_ovr = VMODE;
	wire [7:0] htotal_ovr = htotal;//8'd137;
	wire [9:0] vtotal_ovr = ~interlaced ? vtotal : {vtotal[8:0], 1'b1};
	wire [9:0] vsynl_ovr  = vsynl;
	wire [9:0] vvbgn_ovr  = ~interlaced ? vvbgn : {vvbgn[8:0], 1'b1};
	wire [9:0] vvend_ovr  = ~interlaced ? vvend : {vvend[8:0], 1'b1};
	wire [9:0] rintl_ovr  = ~interlaced ? rintl : {rintl[8:0], 1'b1};

	wire is_24khz =
	    ((HMODE_ovr == 2'b10) && hfreq_ovr &&          (htotal_ovr >= 8'd160)) ||
	    ((HMODE_ovr == 2'b01) && hfreq_ovr && ~HRL  && (htotal_ovr >= 8'd100)) ||
	    ((HMODE_ovr == 2'b01) && hfreq_ovr &&  HRL  && (htotal_ovr >= 8'd80 )) ||
	    ((HMODE_ovr == 2'b00) && hfreq_ovr && ~HRL  && (htotal_ovr >= 8'd53 )) ||
	    ((HMODE_ovr == 2'b00) && hfreq_ovr &&  HRL  && (htotal_ovr >= 8'd40 ) && (htotal_ovr < 8'd50));

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
	assign VSYNC = (vsynl_ovr != 0) ? (VCOUNT < vsynl_ovr) : (VCOUNT == 0);

	wire [7:0] htotal_m = htotal_ovr;
	wire [9:0] vtotal_m = vtotal_ovr;


	wire [7:0] hactive_start = (hvbgn + 3'd4 <= htotal_m) ? hvbgn + 3'd4 : hvbgn + 3'd4 - htotal_m - 1'd1;
	wire [7:0] hactive_end   = (hvend + 3'd4 <= htotal_m) ? hvend + 3'd4 : hvend + 3'd4 - htotal_m - 1'd1;
	wire [8:0] hline_len = {1'b0, htotal_m} + 9'd1;
	wire [8:0] hactive_width_w = (hactive_end >= hactive_start) ?
	                              ({1'b0, hactive_end} - {1'b0, hactive_start}) :
	                              (hline_len - {1'b0, hactive_start} + {1'b0, hactive_end});
	wire [7:0] hactive_width = hactive_width_w[8] ? 8'hff :
	                           (hactive_width_w == 9'd0) ? 8'd1 : hactive_width_w[7:0];
	wire [7:0] hbox_width_nom = hfreq ?
	                            ((HMODE_ovr == 2'b00) ? (HRL ? (is_24khz ? 8'd30 : 8'd48) : (is_24khz ? 8'd40 : 8'd32)) :
	                             (HMODE_ovr == 2'b01) ? (HRL ? (is_24khz ? 8'd62 : 8'd48) : (is_24khz ? 8'd80 : 8'd64)) :
	                             8'd96) :
	                            ((HMODE_ovr == 2'b00) ? (HRL ? 8'd48 : 8'd32) :
	                             (HMODE_ovr == 2'b01) ? 8'd64 : 8'd96);
	wire [7:0] hbox_width_exp = (hactive_width > hbox_width_nom) ? hactive_width : hbox_width_nom;  // expand-to-fit: never clip content
	wire [7:0] hbox_width = (hbox_width_exp > htotal_m) ? htotal_m : hbox_width_exp;
	wire [7:0] hbox_margin = (hbox_width > hactive_width) ? ((hbox_width - hactive_width) >> 1) : 8'd0;
	wire signed [10:0] hstart_s = $signed({3'b0, hactive_start}) - $signed({3'b0, hbox_margin});
	wire signed [10:0] hmax_start_s = $signed({3'b0, htotal_m}) - $signed({3'b0, hbox_width});
	wire signed [10:0] hstart_clamped_s = (hstart_s < 0) ? 11'sd0 :
	                                      (hstart_s > hmax_start_s) ? hmax_start_s : hstart_s;
	wire [7:0] hbox_start = hstart_clamped_s[7:0];
	wire [7:0] hbox_end   = hbox_start + hbox_width;

	wire [9:0] vactive_height = (vvend_ovr > vvbgn_ovr) ? (vvend_ovr - vvbgn_ovr) : 10'd1;
	wire [9:0] vbox_height_nom = is_24khz  ? 10'd424 :
	                             hfreq     ? 10'd512 :
	                             hfreq_ovr ? 10'd512 : 10'd256;
	wire [9:0] vbox_height_exp = (vactive_height > vbox_height_nom) ? vactive_height : vbox_height_nom;
	wire [9:0] vbox_height = (vbox_height_exp > vtotal_m) ? vtotal_m : vbox_height_exp;
	wire [9:0] vbox_margin = (vbox_height > vactive_height) ? ((vbox_height - vactive_height) >> 1) : 10'd0;

	wire signed [11:0] vstart_s = $signed({2'b0, vvbgn_ovr}) - $signed({2'b0, vbox_margin});
	wire signed [11:0] vmax_start_s = $signed({2'b0, vtotal_m}) - $signed({2'b0, vbox_height});
	wire signed [11:0] vstart_clamped_s = (vstart_s < 0) ? 12'sd0 :
	                                      (vstart_s > vmax_start_s) ? vmax_start_s : vstart_s;
	wire [9:0] vbox_start = vstart_clamped_s[9:0];
	wire [9:0] vbox_end   = vbox_start + vbox_height;

	assign VIDEN = ~(VRTC || HRTC);
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
		if (v60hz && (mod_inc_dyn != 32'd0))
			mod_inc = mod_inc_dyn;
		else begin
			case ({HRL, hfreq_ovr, HMODE_ovr})
				4'h0: mod_inc = 205848; // HRL:0 HF:0 H:256 (38.864MHz/8 = 4.858MHz)
				4'h1: mod_inc = 102924; // HRL:0 HF:0 H:512
				4'h2: mod_inc = 205848; // HRL:0 HF:0 H:768
				4'h3: mod_inc = 158888; // HRL:0 HF:0 H:###
				4'h4: mod_inc = 86266;  // HRL:0 HF:1 H:256 (69.552MHz/6 = 11.592MHz)
				4'h5: mod_inc = 43133;  // HRL:0 HF:1 H:512
				4'h6: mod_inc = 28755;  // HRL:0 HF:1 H:768
				4'h7: mod_inc = 39722;  // HRL:0 HF:1 H:### (768 alternate)
				4'h8: mod_inc = 205848; // HRL:1 HF:0 H:256
				4'h9: mod_inc = 102924; // HRL:1 HF:0 H:512
				4'hA: mod_inc = 205848; // HRL:1 HF:0 H:768
				4'hB: mod_inc = 158888; // HRL:1 HF:0 H:###
				4'hC: mod_inc = 115022; // HRL:1 HF:1 H:256 (69.552MHz/8 = 8.694MHz)
				4'hD: mod_inc = 57511;  // HRL:1 HF:1 H:512
				4'hE: mod_inc = 28755;  // HRL:1 HF:1 H:768
				4'hF: mod_inc = 39722;  // HRL:1 HF:1 H:### (768 alternate)
				default: mod_inc = 28755;
			endcase
		end
	end

	wire [19:0] div_prod    = ({1'b0, htotal_m} + 9'd1) * ({1'b0, vtotal_m} + 11'd1);
	wire [18:0] div_partial = {div_rem, div_dvd[31]};
	wire        div_geq     = (div_partial >= div_div);
	wire [18:0] div_sub     = div_partial - div_div;

	always_ff @(posedge gclk) begin
		if (~rstn) begin
			mod_inc_dyn <= 32'd0;
			div_cnt     <= 6'd0;
			div_ht_r    <= 8'd0;
			div_vt_r    <= 10'd0;
			div_v60_r   <= 1'b0;
		end else if (div_cnt == 6'd0) begin
			div_ht_r  <= htotal_m;
			div_vt_r  <= vtotal_m;
			div_v60_r <= v60hz;
			if (v60hz && htotal_m != 8'd0 && vtotal_m != 10'd0 &&
			    (htotal_m != div_ht_r || vtotal_m != div_vt_r || !div_v60_r)) begin
				div_dvd  <= 32'd2_083_333_333;
				div_rem  <= 18'd0;
				div_quot <= 32'd0;
				div_div  <= div_prod[18:0];
				div_cnt  <= 6'd1;
			end
		end else if (div_cnt <= 6'd32) begin
			div_dvd  <= {div_dvd[30:0], 1'b0};
			div_rem  <= div_geq ? div_sub[17:0] : div_partial[17:0];
			div_quot <= {div_quot[30:0], div_geq};
			div_cnt  <= div_cnt + 6'd1;
		end else begin
			mod_inc_dyn <= div_quot;
			div_cnt     <= 6'd0;
		end
	end

	assign pix_ce = polyclock;
	assign out_is_24khz = is_24khz;
	assign f1 = 1'b0;
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
			HRTC_b <= 1;
			VRTC_b <= 1;
		end else if (pix_ce) begin
			dotpu_cnt <= dotpu_cnt + 1'd1;
			HCOMPw <= 0;
			VCOMPw <= 0;

			HCOMPl<=HCOMPw;
			VCOMPl<=VCOMPw;

			if (HCOMPb)
				LSEL <= ~LSEL;

			if (&dotpu_cnt) begin
				HUCOUNT <= HUCOUNT + 1'd1;

				if (HUCOUNT == hactive_start)
					HRTC <= 0;
				else if (HUCOUNT == hactive_end)
					HRTC <= 1;
				if (HUCOUNT == ((hbox_start <= htotal_m) ? hbox_start : hbox_start - htotal_m - 1'd1))
					HRTC_b <= 0;
				else if (HUCOUNT == ((hbox_end <= htotal_m) ? hbox_end : hbox_end - htotal_m - 1'd1))
					HRTC_b <= 1;

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
						if (VCOUNT == vbox_start)
							VRTC_b <= 0;
						else if (VCOUNT == vbox_end)
							VRTC_b <= 1;
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
						if (~VRTC)
							VRTC <= 1;
						if (~VRTC_b)
							VRTC_b <= 1;
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