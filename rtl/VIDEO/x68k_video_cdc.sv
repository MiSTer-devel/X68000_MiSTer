module x68k_video_snapshot #(parameter WIDTH=1) (
    input src_clk, dst_clk, reset_n,
    input [WIDTH-1:0] in_data,
    output reg [WIDTH-1:0] out_data,
    output reg valid
);
    reg [WIDTH-1:0] held;
    reg req, ack, sent;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [1:0] req_sync, ack_sync;
    always @(posedge src_clk or negedge reset_n) begin
        if (!reset_n) begin
            held <= 0; req <= 0; sent <= 0; ack_sync <= 0;
        end else begin
            ack_sync <= {ack_sync[0], ack};
            if (ack_sync[1] == req && (!sent || held != in_data)) begin
                held <= in_data;
                req <= ~req;
                sent <= 1;
            end
        end
    end
    always @(posedge dst_clk or negedge reset_n) begin
        if (!reset_n) begin
            req_sync <= 0; ack <= 0; out_data <= 0; valid <= 0;
        end else begin
            req_sync <= {req_sync[0], req};
            if (req_sync[1] != ack) begin
                out_data <= held;
                valid <= 1;
                ack <= req_sync[1];
            end
        end
    end
endmodule

module x68k_scanline_ram (
    input wrclk, rdclk, wren,
    input [9:0] wraddr, rdaddr,
    input [15:0] data,
    output reg [15:0] q
);
    (* ramstyle = "M10K, no_rw_check" *) reg [15:0] mem [0:1023];
    always @(posedge wrclk) if (wren) mem[wraddr] <= data;
    always @(posedge rdclk) q <= mem[rdaddr];
endmodule
