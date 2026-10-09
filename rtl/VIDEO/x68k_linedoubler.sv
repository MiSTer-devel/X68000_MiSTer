module x68k_linedoubler
(
	input             clk,
	input             reset_n,
	input             ce_in,
	input       [7:0] r_in, g_in, b_in,
	input             hs_in, vs_in, hb_in, vb_in,
	output reg        ce_out,
	output      [7:0] r_out, g_out, b_out,
	output            hs_out, vs_out, hb_out, vb_out
);
	localparam AW = 11;
	localparam DW = 26;

	(* ramstyle = "no_rw_check" *) reg [DW-1:0] line_buf [0:(2 << AW)-1];
	reg             wr_bank = 0, rd_bank = 0;
	reg [AW-1:0]    wr_addr = 0, rd_addr = 0, rd_len = 0;
	reg             have_line = 0;
	reg             hs_prev = 0;
	reg             wr_vs = 0, rd_vs = 0;
	reg             wr_vb = 1, rd_vb = 1;
	wire            line_start = hs_prev & ~hs_in;
	reg [5:0]       age = 0, period = 6'd8;
	wire            half_ce = (age == ((period >> 1) - 1'b1));
	wire            sample = ce_in | half_ce;
	wire [AW-1:0]   completed_len = wr_addr + ce_in;
	wire [AW:0]     read_slot = line_start ? {wr_bank,{AW{1'b0}}} :
	                                    {rd_bank,rd_addr};
	reg [DW-1:0]    read_data;
	assign {r_out,g_out,b_out,hs_out,hb_out} =
		have_line ? read_data : {24'd0,2'b01};
	assign vs_out = have_line ? rd_vs : 1'b0;
	assign vb_out = have_line ? rd_vb : 1'b1;

	always @(posedge clk) begin
		if (ce_in)
			line_buf[{wr_bank,wr_addr}] <=
				{r_in,g_in,b_in,hs_in,hb_in};
		if (sample)
			read_data <= line_buf[read_slot];
	end

	always @(posedge clk) begin
		if (!reset_n) begin
			wr_bank   <= 0;
			rd_bank   <= 0;
			wr_addr   <= 0;
			rd_addr   <= 0;
			rd_len    <= 0;
			have_line <= 0;
			hs_prev   <= 0;
			wr_vs     <= 0;
			rd_vs     <= 0;
			wr_vb     <= 1;
			rd_vb     <= 1;
			age       <= 0;
			period    <= 6'd8;
			ce_out    <= 0;
		end else begin
			hs_prev <= hs_in;
			ce_out <= sample;
			if (ce_in) begin
				period <= age + 1'b1;
				age <= 0;
			end else begin
				age <= age + 1'b1;
			end
			if (line_start) begin
				rd_vs <= wr_vs;
				rd_vb <= wr_vb;
				wr_vs <= vs_in;
				wr_vb <= vb_in;
				wr_bank <= ~wr_bank;
				wr_addr <= 0;
				rd_bank <= wr_bank;
				rd_len <= completed_len;
				have_line <= (completed_len != 0);
				if (sample && completed_len != 0) begin
					rd_addr <= (completed_len == 1) ? 11'd0 : 11'd1;
				end else begin
					rd_addr <= 0;
				end
			end else begin
				if (ce_in) wr_addr <= wr_addr + 1'b1;
				if (sample && have_line) begin
					rd_addr <= (rd_addr == rd_len - 1'b1) ? 11'd0 : rd_addr + 1'b1;
				end
			end
		end
	end
endmodule
