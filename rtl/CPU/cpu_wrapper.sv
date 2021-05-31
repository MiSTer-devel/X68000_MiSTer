// CPU Wrapper by Kitrinx

module cpu_wrapper (
	input  logic        clk,
	input  logic        clk10m,
	input  logic        phi1_ce,
	input  logic        phi2_ce,
	input  logic        cpu_select,
	input  logic        reset_n,
	input  logic        buserr,
	input  logic        iackbe,
	input  logic [15:0] din,
	input  logic        dTACK_n,
	input  logic        dma_active_n,
	input  logic  [2:0] IPL,
	output logic [15:0] dout,
	output logic  [2:0] FC,
	output logic        rw_n,
	output logic [23:0] address,
	output logic        AS_n,
	output logic        UDS_n,
	output logic        LDS_n,
	output logic        OE
);

	logic [15:0] tg_dout, fx_dout;
	logic [23:0] tg_addr, fx_addr; // Note TG68 has an address range 31:0, fx68k has range 23:1
	logic        tg_OE, fx_OE;
	logic        tg_rwn, fx_rwn;
	logic        tg_ASn, fx_ASn;
	logic        tg_UDSn, fx_UDSn;
	logic        tg_LDSn, fx_LDSn;
	logic  [2:0] tg_FC, fx_FC;

	assign tg_FC = 3'd0;
	assign dout    = !cpu_select ? tg_dout       : fx_dout;
	assign address = !cpu_select ? tg_addr[23:0] : fx_addr[23:0];
	assign OE      = !cpu_select ? tg_OE         : fx_OE;
	assign rw_n    = !cpu_select ? tg_rwn        : fx_rwn;
	assign AS_n    = !cpu_select ? tg_ASn        : fx_ASn;
	assign UDS_n   = !cpu_select ? tg_UDSn       : fx_UDSn;
	assign LDS_n   = !cpu_select ? tg_LDSn       : fx_LDSn;
	assign FC      = !cpu_select ? tg_FC         : fx_FC;
	
	TG68 MPU (
		.clk           (clk10m),
		.reset         (reset_n),
		.clkena_in     (~dma_active_n),
		.data_in       (din),
		.IPL           (IPL),
		.dtack         (dTACK_n),
		.addr          (tg_addr),
		.data_out      (tg_dout),
		.as            (tg_ASn),
		.uds           (tg_UDSn),
		.lds           (tg_LDSn),
		.rw            (tg_rwn),
		.drive_data    (tg_OE)
	);
	
	//assign fx_addr[0] = 0;
	fx68k CPU (
		.clk        (clk),               // in CLK 2x the target cpu speed
		.HALTn      (1),                 // in CPU halt signal
		.extReset   (~reset_n),          // in External Reset
		.pwrUp      (~reset_n),          // in Cold boot for emulators (pair with reset)
		.enPhi1     (phi1_ce),           // in phi1 clock enable
		.enPhi2     (phi2_ce),           // in phi2 clock enable
		.eRWn       (fx_rwn),            // out read write signal (write low)
		.ASn        (fx_ASn),            // out Address Strobe
		.LDSn       (fx_LDSn),           // out Lower data strobe
		.UDSn       (fx_UDSn),           // out Upper data strobe
		.E          (),                  // out Enable
		.VMAn       (fx_addr[0]),        // out Valid Memory Address
		.FC0        (fx_FC[0]),          // out Processor status
		.FC1        (fx_FC[1]),          // out Processor status
		.FC2        (fx_FC[2]),          // out Processor status
		.BGn        (),                  // out Bus Grant
		.oRESETn    (),                  // out Reset (out)
		.oHALTEDn   (),                  // out Halted (out)
		.DTACKn     (~dma_active_n | dTACK_n),// in Data transfer acknowledge
		.VPAn       (~&FC),              // in Valid Peripheral Address
		.BERRn      (1),                 // in Bus Error
		.BRn        (1),                 // in Bus Request
		.BGACKn     (1),                 // in Bus Grant Acknowledge
		.IPL0n      (IPL[0]),            // in Interrupt Control
		.IPL1n      (IPL[1]),            // in Interrupt Control
		.IPL2n      (IPL[2]),            // in Interrupt Control
		.iEdb       (din),               // in data bus in
		.oEdb       (fx_dout),           // out data bus out
		.eab        (fx_addr[23:1])      // out address bus
	);
	
	reg ph1n, ph2n;
	always @(posedge clk) begin
		ph1n <= phi1_ce;
		ph2n <= phi2_ce;
	end

	always @(negedge clk, negedge reset_n) begin
		reg [1:0] stage;
	
		if(~reset_n) begin
			stage <= 0;
		end
		else begin
			if (ph2n) begin
			end
	
			if (ph1n) begin
				fx_OE <= 0;
				case (stage)
					0: stage <= 1;
					1: begin
						fx_OE <= ~fx_rwn && dma_active_n;
						stage <= 2;
					end
					2: stage <= 3;
					3: stage <= 0;
				endcase
			end
		end
	end
endmodule