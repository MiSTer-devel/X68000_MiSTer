module x68k_native_crtc
(
	input               gclk,
    input               config_clk, pclk, scan_ready,
    input [3:0]         active_mode,
    output              scan_LRAMSEL,
    output              render_hblank, render_vblank, render_reset_n,
    output              scan_reset_n,
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

	output              pix_ce, // This is the pixel CE
	output              LRAMSEL,
	output [9:0]        LRAMADR,
	output [5:0]        RFOUT,
	output [5:0]        GFOUT,
	output [5:0]        BFOUT,
	output              HSYNC,
	output              VSYNC,
	output              VRTC,   // VBlank out
	output              HRTC,   // Hblank out
	output              VRTC_b,
	output              HRTC_b,
	output              VIDEN,  // Video DE
	output              HCOMP,  // Signals the start of a new line
	output              VCOMP,  // Signals the start of a new frame
	output              VPSTART,
	output              f1,
	output              vid_osc,
	output              out_is_24khz,
	input               ext_pix_en,
	input               ext_pix_ce,
	output [3:0]        pix_mode,
	output              pix_dyn
);
    wire [1:0] c_HMODE;
    wire [1:0] c_VMODE;
    wire [0:0] c_HRL;
    wire [0:0] c_hfreq;
    wire [7:0] c_htotal;
    wire [7:0] c_hsynl;
    wire [7:0] c_hvbgn;
    wire [7:0] c_hvend;
    wire [9:0] c_vtotal;
    wire [9:0] c_vsynl;
    wire [9:0] c_vvbgn;
    wire [9:0] c_vvend;
    wire [7:0] c_hadj;
    wire [9:0] c_rintl;
    wire cfg_valid;
    wire [95:0] prepared_config;
    wire [51:0] prepared_window, c_window;
    wire prepared_valid;
    x68k_video_window window_pipeline (
        .clk(config_clk), .reset_n(rstn),
        .config_in({HMODE, VMODE, HRL, hfreq, htotal, hsynl, hvbgn, hvend, vtotal, vsynl, vvbgn, vvend, hadj, rintl}),
        .config_out(prepared_config), .window_out(prepared_window), .valid(prepared_valid));
    x68k_video_snapshot #(.WIDTH(148)) config_cdc (
        .src_clk(config_clk), .dst_clk(pclk), .reset_n(rstn && prepared_valid),
        .in_data({prepared_config, prepared_window}),
        .out_data({c_HMODE, c_VMODE, c_HRL, c_hfreq, c_htotal, c_hsynl, c_hvbgn, c_hvend, c_vtotal, c_vsynl, c_vvbgn, c_vvend, c_hadj, c_rintl, c_window}), .valid(cfg_valid));
    wire c_hf = c_hfreq | c_VMODE[0];
    wire [3:0] c_mode = {c_HRL, c_hf, c_HMODE};
    wire scan_ok = rstn && scan_ready && cfg_valid && (c_mode == active_mode);
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [2:0] scan_reset;
    always @(posedge pclk or negedge scan_ok)
        if (!scan_ok) scan_reset <= 0;
        else scan_reset <= {scan_reset[1:0], 1'b1};
    assign scan_reset_n = scan_reset[2];
    reg [3:0] count;
    reg [3:0] divisor;
    always @* case (c_mode)
        4'h0,4'h2,4'h3,4'h8,4'hA,4'hB,4'hC: divisor = 8;
        4'h1,4'h9,4'hD: divisor = 4;
        4'h4: divisor = 6;
        4'h5: divisor = 3;
        default: divisor = 2;
    endcase
    assign pix_ce = scan_reset_n && count == 0;
    always @(posedge pclk or negedge scan_reset_n)
        if (!scan_reset_n) count <= 0;
        else if (count == divisor - 1'b1) count <= 0;
        else count <= count + 1'b1;

    wire line_event, frame_event;
    mister_sync #(.PRECOMPUTED_WINDOW(1)) timing (
        .window_config(c_window),
        .gclk(pclk), .rstn(scan_reset_n), .LRAMDAT(LRAMDAT),
        .HMODE(c_HMODE),
        .VMODE(c_VMODE),
        .HRL(c_HRL),
        .hfreq(c_hfreq),
        .htotal(c_htotal),
        .hsynl(c_hsynl),
        .hvbgn(c_hvbgn),
        .hvend(c_hvend),
        .vtotal(c_vtotal),
        .vsynl(c_vsynl),
        .vvbgn(c_vvbgn),
        .vvend(c_vvend),
        .hadj(c_hadj),
        .rintl(c_rintl),
        .v60hz(1'b0), .ext_pix_en(1'b1), .ext_pix_ce(pix_ce),
        .LRAMSEL(scan_LRAMSEL), .LRAMADR(LRAMADR),
        .RFOUT(RFOUT), .GFOUT(GFOUT), .BFOUT(BFOUT),
        .HSYNC(HSYNC), .VSYNC(VSYNC), .HRTC(HRTC), .VRTC(VRTC),
        .HRTC_b(HRTC_b), .VRTC_b(VRTC_b), .VIDEN(VIDEN),
        .HCOMP(line_event), .VPSTART(frame_event));

    wire interlaced = VMODE[0] && !hfreq;
    assign pix_mode = {HRL, hfreq | interlaced, HMODE};
    assign pix_dyn = 0;
    assign f1 = 0;
    assign vid_osc = pix_ce;
    assign VCOMP = VPSTART;
    assign out_HMODE = HMODE;
    assign out_VMODE = VMODE;
    assign out_hfreq = hfreq | interlaced;
    assign out_htotal = htotal;
    assign out_hsynl = hsynl;
    assign out_hvbgn = hvbgn;
    assign out_hvend = hvend;
    assign out_vtotal = interlaced ? {vtotal[8:0],1'b1} : vtotal;
    assign out_vsynl = vsynl;
    assign out_vvbgn = interlaced ? {vvbgn[8:0],1'b1} : vvbgn;
    assign out_vvend = interlaced ? {vvend[8:0],1'b1} : vvend;
    assign out_rintl = interlaced ? {rintl[8:0],1'b1} : rintl;
    assign out_is_24khz =
        ((HMODE == 2) && out_hfreq && htotal >= 160) ||
        ((HMODE == 1) && out_hfreq && !HRL && htotal >= 100) ||
        ((HMODE == 1) && out_hfreq && HRL && htotal >= 80) ||
        ((HMODE == 0) && out_hfreq && !HRL && htotal >= 53) ||
        ((HMODE == 0) && out_hfreq && HRL && htotal >= 40 && htotal < 50);

    reg line_toggle;
    reg [1:0] line_payload;
    always @(posedge pclk or negedge scan_reset_n) begin
        if (!scan_reset_n) begin line_toggle <= 0; line_payload <= 0; end
        else if (line_event) begin
            line_toggle <= ~line_toggle;
            line_payload <= {~scan_LRAMSEL, frame_event};
        end
    end
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [2:0] render_reset;
    always @(posedge gclk or negedge scan_reset_n)
        if (!scan_reset_n) render_reset <= 0;
        else render_reset <= {render_reset[1:0],1'b1};
    assign render_reset_n = render_reset[2];
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [2:0] line_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [1:0] hb_sync, vb_sync;
    reg line_seen, render_bank;
    assign HCOMP = render_reset_n && (line_sync[2] != line_seen);
    assign VPSTART = HCOMP && line_payload[0];
    assign LRAMSEL = render_bank;
    assign render_hblank = hb_sync[1];
    assign render_vblank = vb_sync[1];
    always @(posedge gclk or negedge render_reset_n) begin
        if (!render_reset_n) begin
            line_sync <= 0; line_seen <= 0; render_bank <= 1;
            hb_sync <= 3; vb_sync <= 3;
        end else begin
            line_sync <= {line_sync[1:0], line_toggle};
            hb_sync <= {hb_sync[0], HRTC};
            vb_sync <= {vb_sync[0], VRTC};
            if (HCOMP) begin
                line_seen <= line_sync[2];
                render_bank <= line_payload[1];
            end
        end
    end
endmodule
