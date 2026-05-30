module ddram (
	input  logic        clk,
	input  logic        rst_n,

	// CPU interface (from X68K_top)
	input  logic [22:0] addr,      // 16-bit word address (= m_addr[23:1])
	input  logic [15:0] din,       // write data
	input  logic        rd,        // read request (active high, level)
	input  logic [1:0]  wr,        // write byte enables [1]=upper [0]=lower
	output logic [15:0] dout,      // read data
	output logic        ack,       // access acknowledge
	output logic        ready,     // high when init clear is done

	// DDR3 interface (directly to framework)
	output logic        DDRAM_CLK,
	output logic [7:0]  DDRAM_BURSTCNT,
	output logic [28:0] DDRAM_ADDR,
	output logic [63:0] DDRAM_DIN,
	output logic [7:0]  DDRAM_BE,
	output logic        DDRAM_RD,
	output logic        DDRAM_WE,
	input  logic [63:0] DDRAM_DOUT,
	input  logic        DDRAM_DOUT_READY,
	input  logic        DDRAM_BUSY
);

assign DDRAM_CLK = clk;

logic  [7:0] ram_burst   = 8'd1;
logic [28:0] ram_address = '0;
logic [63:0] ram_data    = '0;
logic  [7:0] ram_be      = '0;
logic        ram_read    = 1'b0;
logic        ram_write   = 1'b0;

assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_ADDR     = ram_address;
assign DDRAM_DIN      = ram_data;
assign DDRAM_BE       = ram_read ? 8'hFF : ram_be;
assign DDRAM_RD       = ram_read;
assign DDRAM_WE       = ram_write;

logic [63:0] cd0[0:7]; // qword 0 (words 0-3)
logic [63:0] cd1[0:7]; // qword 1 (words 4-7)
logic [63:0] cd2[0:7]; // qword 2 (words 8-11)
logic [63:0] cd3[0:7]; // qword 3 (words 12-15)
logic [18:0] ctag[0:7]; // tag = addr[22:4]
logic  [7:0] cvalid;

logic [6:0] plru;

logic rst_n_s0 = 1'b0;
logic rst_n_s  = 1'b0;

logic        rst_pending   = 1'b1;
logic  [1:0] rst_phase     = 2'd0;
logic  [7:0] rst_drain_cnt = 8'd0;
localparam RST_WAIT_TIMEOUT = 16'd65535;
logic [15:0] rst_wait_cnt = RST_WAIT_TIMEOUT;

assign ready = ~rst_pending;

logic wr_done = 1'b0;
assign ack = rst_pending ? 1'b0 : ((rd & hit) | wr_done);

logic [18:0] a_tag;
logic  [1:0] a_qoff;
logic  [1:0] a_ww;

assign a_tag  = addr[22:4];
assign a_qoff = addr[3:2];
assign a_ww   = addr[1:0];

logic [7:0] chit;
genvar gi;
generate
	for (gi = 0; gi < 8; gi = gi + 1) begin : hit_check
		assign chit[gi] = cvalid[gi] & (ctag[gi] == a_tag);
	end
endgenerate

logic hit;
assign hit = |chit;

logic [2:0] hit_idx;
assign hit_idx[0] = |(chit & 8'hAA);
assign hit_idx[1] = |(chit & 8'hCC);
assign hit_idx[2] = |(chit & 8'hF0);

logic [2:0] plru_victim;
assign plru_victim[2] = plru[0];
assign plru_victim[1] = plru_victim[2] ? plru[2]  : plru[1];
assign plru_victim[0] = plru_victim[2] ? (plru_victim[1] ? plru[6] : plru[5])
                                       : (plru_victim[1] ? plru[4] : plru[3]);

logic [2:0] first_invalid;
logic       has_invalid;

always_comb begin
	first_invalid = 3'd0;
	has_invalid   = 1'b0;
	for (int i = 7; i >= 0; i--) begin
		if (!cvalid[i]) begin
			first_invalid = i[2:0];
			has_invalid   = 1'b1;
		end
	end
end

logic [2:0] victim;
assign victim = has_invalid ? first_invalid : plru_victim;

logic [63:0] hit_qw;
always_comb begin
	hit_qw = 64'd0;
	for (int k = 0; k < 8; k++) begin
		if (chit[k]) begin
			case (a_qoff)
				2'd0: hit_qw = cd0[k];
				2'd1: hit_qw = cd1[k];
				2'd2: hit_qw = cd2[k];
				2'd3: hit_qw = cd3[k];
			endcase
		end
	end
end

assign dout = (a_ww == 2'd0) ? hit_qw[15:0]  :
              (a_ww == 2'd1) ? hit_qw[31:16]  :
              (a_ww == 2'd2) ? hit_qw[47:32]  :
                               hit_qw[63:48];

function automatic logic [6:0] calc_next_plru(
	input logic [6:0] current_plru,
	input logic [2:0] target_idx
);
	logic [6:0] next_plru;
	next_plru = current_plru;
	next_plru[0] = ~target_idx[2];
	if (!target_idx[2]) next_plru[1] = ~target_idx[1];
	else                next_plru[2] = ~target_idx[1];
	case (target_idx[2:1])
		2'b00: next_plru[3] = ~target_idx[0];
		2'b01: next_plru[4] = ~target_idx[0];
		2'b10: next_plru[5] = ~target_idx[0];
		2'b11: next_plru[6] = ~target_idx[0];
	endcase
	return next_plru;
endfunction

logic [63:0] wr_mask;
logic [63:0] wr_data_repl;

always_comb begin
	wr_mask = 64'd0;
	if (wr[0]) wr_mask[(a_ww * 16) +:      8] = 8'hFF;
	if (wr[1]) wr_mask[(a_ww * 16) + 8 +: 8] = 8'hFF;
	wr_data_repl = {4{din}};
end

localparam S_IDLE = 1'd0, S_FILL = 1'd1;
logic        state      = S_IDLE;
logic [18:0] s_tag;
logic  [2:0] fill_slot;
logic  [1:0] fill_beat  = 2'd0;

localparam WATCHDOG_MAX = 9'd511;
logic [8:0] watchdog_cnt = WATCHDOG_MAX;

localparam RST_WAIT  = 2'd0,
           RST_DRAIN = 2'd1,
           RST_DONE  = 2'd2;

always_ff @(posedge clk) begin

	rst_n_s0 <= rst_n;
	rst_n_s  <= rst_n_s0;

	if (!rst_n_s && !rst_pending) begin
		rst_pending  <= 1'b1;
		rst_phase    <= RST_WAIT;
		rst_wait_cnt <= RST_WAIT_TIMEOUT;
		ram_read     <= 1'b0;
		ram_write    <= 1'b0;
	end

	if (rst_pending) begin
		case (rst_phase)

		RST_WAIT: begin
			ram_read  <= 1'b0;
			ram_write <= 1'b0;
			if (!DDRAM_BUSY || rst_wait_cnt == 16'd0) begin
				rst_phase     <= RST_DRAIN;
				rst_drain_cnt <= 8'd255;
			end else begin
				rst_wait_cnt <= rst_wait_cnt - 1'b1;
			end
		end

		RST_DRAIN: begin
			if (rst_drain_cnt == 8'd0)
				rst_phase <= RST_DONE;
			else
				rst_drain_cnt <= rst_drain_cnt - 8'd1;
		end

		RST_DONE: begin
			cvalid       <= 8'd0;
			plru         <= 7'd0;
			wr_done      <= 1'b0;
			fill_beat    <= 2'd0;
			state        <= S_IDLE;
			ram_burst    <= 8'd1;
			watchdog_cnt <= WATCHDOG_MAX;
			rst_wait_cnt <= RST_WAIT_TIMEOUT;
			rst_pending  <= 1'b0;
		end

		default: begin
			rst_phase    <= RST_WAIT;
			rst_wait_cnt <= RST_WAIT_TIMEOUT;
		end

		endcase

	end else begin

		if (wr == 2'b00) wr_done <= 1'b0;

		if ((rd | (|wr)) && hit)
			plru <= calc_next_plru(plru, hit_idx);
			
		if (|wr && !wr_done) begin
			for (int i = 0; i < 8; i++) begin
				if (cvalid[i] && (ctag[i] == a_tag)) begin
					case (a_qoff)
						2'd0: cd0[i] <= (cd0[i] & ~wr_mask) | (wr_data_repl & wr_mask);
						2'd1: cd1[i] <= (cd1[i] & ~wr_mask) | (wr_data_repl & wr_mask);
						2'd2: cd2[i] <= (cd2[i] & ~wr_mask) | (wr_data_repl & wr_mask);
						2'd3: cd3[i] <= (cd3[i] & ~wr_mask) | (wr_data_repl & wr_mask);
					endcase
				end
			end
		end
		
		if (state == S_FILL && DDRAM_DOUT_READY) begin
			case (fill_beat)
				2'd0: cd0[fill_slot] <= DDRAM_DOUT;
				2'd1: cd1[fill_slot] <= DDRAM_DOUT;
				2'd2: cd2[fill_slot] <= DDRAM_DOUT;
				2'd3: cd3[fill_slot] <= DDRAM_DOUT;
			endcase
			if (fill_beat == 2'd3) begin
				ctag[fill_slot]  <= s_tag;
				cvalid           <= cvalid | (8'd1 << fill_slot);
				plru             <= calc_next_plru(plru, fill_slot);
				state            <= S_IDLE;
				watchdog_cnt     <= WATCHDOG_MAX;
			end
			fill_beat <= fill_beat + 1'd1;
		end

		if (state == S_FILL) begin
			if (watchdog_cnt == 9'd0) begin
				state        <= S_IDLE;
				watchdog_cnt <= WATCHDOG_MAX;
				ram_read     <= 1'b0;
			end else begin
				watchdog_cnt <= watchdog_cnt - 9'd1;
			end
		end

		if (!DDRAM_BUSY) begin
			ram_read  <= 1'b0;
			ram_write <= 1'b0;

			case (state)
				S_IDLE: begin
					if (rd && !hit) begin
						ram_address  <= {5'b00110, 3'b000, a_tag, 2'b00};
						ram_read     <= 1'b1;
						ram_burst    <= 8'd4;
						s_tag        <= a_tag;
						fill_slot    <= victim;
						fill_beat    <= 2'd0;
						watchdog_cnt <= WATCHDOG_MAX;
						state        <= S_FILL;
					end else if (|wr && !wr_done) begin
						ram_address <= {5'b00110, 3'b000, addr[22:2]};
						ram_data    <= wr_data_repl;
						ram_write   <= 1'b1;
						ram_burst   <= 8'd1;
						case (addr[1:0])
							2'd0: ram_be <= {6'd0, wr[1], wr[0]};
							2'd1: ram_be <= {4'd0, wr[1], wr[0], 2'd0};
							2'd2: ram_be <= {2'd0, wr[1], wr[0], 4'd0};
							2'd3: ram_be <= {wr[1], wr[0], 6'd0};
						endcase
						wr_done <= 1'b1;
					end
				end
				S_FILL: ;
			endcase
		end

	end
end

endmodule
