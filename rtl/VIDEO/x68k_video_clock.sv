module x68k_video_clock (
    input refclk, mgmt_clk, reset_n,
    input [3:0] mode,
    input v60,
    output clk_video,
    output reg ready = 0,
    output reg [3:0] active_mode = 0
);
    wire [63:0] to_pll, from_pll;
    wire locked, waitrequest;
    wire [5:0] address;
    wire [31:0] data;
    wire write;
    pll_native pll_inst (.refclk(refclk), .rst(~reset_n),
        .outclk_0(clk_video), .locked(locked),
        .reconfig_to_pll(to_pll), .reconfig_from_pll(from_pll));
    pll_cfg reconfig (.mgmt_clk(mgmt_clk), .mgmt_reset(~reset_n),
        .mgmt_read(1'b0), .mgmt_readdata(),
        .mgmt_waitrequest(waitrequest), .mgmt_address(address),
        .mgmt_write(write), .mgmt_writedata(data),
        .reconfig_to_pll(to_pll), .reconfig_from_pll(from_pll));

    function automatic [1:0] family(input [3:0] m, input boost);
        if (m[1:0] == 3) family = 2'd2;
        else if (!m[2]) family = 2'd1;
        else family = boost ? 2'd3 : 2'd0;
    endfunction
    reg [4:0] candidate = 0, applied = 0;
    reg [5:0] quiet = 0;
    reg [1:0] target = 0;
    reg [2:0] state = 0;
    reg [11:0] settle = 0;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS", preserve *) reg [1:0] lock_sync = 0;
    reg valid = 0;
    localparam [2:0] IDLE=0, WRITE_M=1, WRITE_C=2, WRITE_K=3, START=4, GAP=5, SETTLE=6;
    wire [4:0] request = {v60, mode};
    assign write = state >= WRITE_M && state <= START;
    assign address = state == WRITE_M ? 6'd4 : state == WRITE_C ? 6'd5 :
                     state == WRITE_K ? 6'd7 : 6'd2;
    function automatic [31:0] m_word(input [1:0] f);
        case (f)
            0: m_word = 32'h00020605;
            1: m_word = 32'h00000606;
            2: m_word = 32'h00000404;
            3: m_word = 32'h00000606;
        endcase
    endfunction
    function automatic [31:0] k_word(input [1:0] f);
        case (f)
            0: k_word = 32'd551123331;
            1: k_word = 32'd1874158801;
            2: k_word = 32'd240518169;
            3: k_word = 32'd170864107;
        endcase
    endfunction
    assign data = state == WRITE_M ? m_word(target) :
                  state == WRITE_C ? (target == 1 ? 32'h808 : 32'h404) :
                  state == WRITE_K ? k_word(target) : 32'd0;

    always @(posedge mgmt_clk) begin
        lock_sync <= {lock_sync[0], locked};
        if (!reset_n) begin
            ready <= 0;
            state <= IDLE;
            quiet <= 0;
            settle <= 0;
            candidate <= 0;
            applied <= 0;
            active_mode <= 0;
            valid <= 0;
            lock_sync <= 0;
        end else begin
            if (request != candidate) begin
                candidate <= request;
                quiet <= 0;
            end else if (!(&quiet)) quiet <= quiet + 1'b1;
            if (request != applied || !lock_sync[1]) ready <= 0;
            case (state)
                IDLE: if (&quiet && candidate == request && (!valid || request != applied)) begin
                    ready <= 0;
                    applied <= request;
                    active_mode <= mode;
                    target <= family(mode, v60);
                    valid <= 1;
                    state <= WRITE_M;
                end else if (valid && request == applied) begin
                    if (lock_sync[1]) ready <= 1;
                    else begin
                        settle <= 0;
                        state <= SETTLE;
                    end
                end
                WRITE_M, WRITE_C, WRITE_K, START:
                    if (!waitrequest) state <= state + 1'b1;
                GAP: begin
                    settle <= 0;
                    state <= SETTLE;
                end
                SETTLE: begin
                    if (waitrequest || !lock_sync[1]) settle <= 0;
                    else if (&settle) state <= IDLE;
                    else settle <= settle + 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
