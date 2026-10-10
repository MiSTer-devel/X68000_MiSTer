(* altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *)
module x68k_video_window (
    input clk, reset_n,
    input [95:0] config_in,
    output [95:0] config_out,
    output [51:0] window_out,
    output valid
);
    wire [1:0] hm, vm;
    wire hrl, hf;
    wire [7:0] ht, hs, hb, he, adj;
    wire [9:0] vt, vs, vb, ve, ri;
    assign {hm, vm, hrl, hf, ht, hs, hb, he, vt, vs, vb, ve, adj, ri} = config_in;
    wire interlace = vm[0] && !hf;
    wire hf_ovr = hf | interlace;
    wire [9:0] vt_ovr = interlace ? {vt[8:0],1'b1} : vt;
    wire [9:0] vb_ovr = interlace ? {vb[8:0],1'b1} : vb;
    wire [9:0] ve_ovr = interlace ? {ve[8:0],1'b1} : ve;
    wire is24 = ((hm == 2) && hf_ovr && ht >= 160) ||
                ((hm == 1) && hf_ovr && !hrl && ht >= 100) ||
                ((hm == 1) && hf_ovr && hrl && ht >= 80) ||
                ((hm == 0) && hf_ovr && !hrl && ht >= 53) ||
                ((hm == 0) && hf_ovr && hrl && ht >= 40 && ht < 50);
    wire [7:0] ha = (hb + 3'd4 <= ht) ? hb + 3'd4 : hb + 3'd4 - ht - 1'd1;
    wire [7:0] hz = (he + 3'd4 <= ht) ? he + 3'd4 : he + 3'd4 - ht - 1'd1;
    wire [7:0] hn = hf ?
        ((hm == 0) ? (hrl ? (is24 ? 8'd30 : 8'd48) : (is24 ? 8'd40 : 8'd32)) :
         (hm == 1) ? (hrl ? (is24 ? 8'd62 : 8'd48) : (is24 ? 8'd80 : 8'd64)) : 8'd96) :
        ((hm == 0) ? (hrl ? 8'd48 : 8'd32) : (hm == 1) ? 8'd64 : 8'd96);
    wire [9:0] vn = is24 ? 10'd424 : hf_ovr ? 10'd512 : 10'd256;

    reg [95:0] cfg [0:7];
    reg [7:0] h_active_start [0:7], h_active_end [0:7];
    reg [7:0] h_total [0:5], h_width [0:7], h_active [1:4];
    reg [9:0] v_start [0:4], v_total [0:5], v_height [0:7], v_active [1:4];
    reg [7:0] h_margin;
    reg [9:0] v_margin;
    reg signed [10:0] h_start_signed, h_max_signed;
    reg signed [11:0] v_start_signed, v_max_signed;
    reg [7:0] h_start_clamped, h_box_start, h_box_end;
    reg [9:0] v_start_clamped, v_box_start, v_box_end;
    reg [9:0] v_end;
    reg [7:0] filled;
    integer i;
    wire [8:0] h_length = {1'b0,h_total[0]} + 9'd1;
    wire [8:0] h_span = (h_active_end[0] >= h_active_start[0]) ?
        ({1'b0,h_active_end[0]} - {1'b0,h_active_start[0]}) :
        (h_length - {1'b0,h_active_start[0]} + {1'b0,h_active_end[0]});

    always @(posedge clk or negedge reset_n)
        if (!reset_n) filled <= 0;
        else filled <= {filled[6:0],1'b1};
    assign valid = filled[7];
    assign config_out = cfg[7];
    assign window_out = {h_active_start[7], h_active_end[7],
                         h_box_start, h_box_end, v_box_start, v_box_end};

    always @(posedge clk) begin
        cfg[0] <= {hm, vm, hrl, hf, ht, hs, hb, he, vt, vs, vb, ve, adj, ri};
        h_active_start[0] <= ha; h_active_end[0] <= hz;
        h_total[0] <= ht; v_total[0] <= vt_ovr;
        v_start[0] <= vb_ovr; v_end <= ve_ovr;
        h_width[0] <= hn; v_height[0] <= vn;
        for (i=1; i<8; i=i+1) begin
            cfg[i] <= cfg[i-1];
            h_active_start[i] <= h_active_start[i-1];
            h_active_end[i] <= h_active_end[i-1];
        end
        for (i=1; i<6; i=i+1) begin
            h_total[i] <= h_total[i-1]; v_total[i] <= v_total[i-1];
        end
        for (i=1; i<5; i=i+1) v_start[i] <= v_start[i-1];

        h_active[1] <= h_span[8] ? 8'hff : h_span == 0 ? 8'd1 : h_span[7:0];
        v_active[1] <= v_end > v_start[0] ? v_end - v_start[0] : 10'd1;
        h_width[1] <= h_width[0]; v_height[1] <= v_height[0];
        for (i=2; i<5; i=i+1) begin
            h_active[i] <= h_active[i-1]; v_active[i] <= v_active[i-1];
        end
        h_width[2] <= h_active[1] > h_width[1] ? h_active[1] : h_width[1];
        v_height[2] <= v_active[1] > v_height[1] ? v_active[1] : v_height[1];
        h_width[3] <= h_width[2] > h_total[2] ? h_total[2] : h_width[2];
        v_height[3] <= v_height[2] > v_total[2] ? v_total[2] : v_height[2];
        h_margin <= h_width[3] > h_active[3] ? (h_width[3] - h_active[3]) >> 1 : 8'd0;
        v_margin <= v_height[3] > v_active[3] ? (v_height[3] - v_active[3]) >> 1 : 10'd0;
        for (i=4; i<8; i=i+1) begin
            h_width[i] <= h_width[i-1]; v_height[i] <= v_height[i-1];
        end
        h_start_signed <= $signed({3'b0,h_active_start[4]}) - $signed({3'b0,h_margin});
        h_max_signed <= $signed({3'b0,h_total[4]}) - $signed({3'b0,h_width[4]});
        v_start_signed <= $signed({2'b0,v_start[4]}) - $signed({2'b0,v_margin});
        v_max_signed <= $signed({2'b0,v_total[4]}) - $signed({2'b0,v_height[4]});
        h_start_clamped <= h_start_signed < 0 ? 8'd0 :
            h_start_signed > h_max_signed ? h_max_signed[7:0] : h_start_signed[7:0];
        v_start_clamped <= v_start_signed < 0 ? 10'd0 :
            v_start_signed > v_max_signed ? v_max_signed[9:0] : v_start_signed[9:0];
        h_box_start <= h_start_clamped; h_box_end <= h_start_clamped + h_width[6];
        v_box_start <= v_start_clamped; v_box_end <= v_start_clamped + v_height[6];
    end
endmodule
