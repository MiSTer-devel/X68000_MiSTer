library IEEE;
use IEEE.std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.std_logic_unsigned.all;

entity em3802 is
    generic(
        sysclk : integer := 10000;  -- System clock frequency (default: 10 kHz)
        oscm   : integer := 1000;   -- Master oscillator frequency (default: 1 kHz)
        oscf   : integer := 614;    -- Oscillator fine-tuning frequency (default: 614 Hz)
        rstlen : integer := 32      -- Reset duration in clock cycles
    );
    port(
        ADDR   : in std_logic_vector(2 downto 0); -- Address input for accessing registers
        DATIN  : in std_logic_vector(7 downto 0); -- Data input for writing to registers
        DATOUT : out std_logic_vector(7 downto 0); -- Data output for reading from registers
        DATWR  : in std_logic;       -- Data write strobe (active high)
        DATRD  : in std_logic;       -- Data read strobe (active high)
        INT    : out std_logic;      -- Interrupt output (active high)
        IVECT  : out std_logic_vector(7 downto 0); -- Interrupt vector output

        RxD    : in std_logic;       -- UART receive data line
        TxD    : out std_logic;      -- UART transmit data line
        RxF    : in std_logic;       -- UART receive FIFO flag (indicates data availability)
        TxF    : out std_logic;      -- UART transmit FIFO flag (indicates readiness to transmit)
        SYNC   : out std_logic;      -- Synchronization signal
        CLICK  : out std_logic;      -- Timing signal output
        GPOUT  : out std_logic_vector(7 downto 0); -- General-purpose output
        GPIN   : in std_logic_vector(7 downto 0);  -- General-purpose input
        GPOE   : out std_logic_vector(7 downto 0); -- General-purpose output enable

        gcountsft : in std_logic;    -- Shift enable for general-purpose counter
        ccountsft : in std_logic;    -- Shift enable for clock counter
        mcountsft : in std_logic;    -- Shift enable for master counter

        clk  : in std_logic;         -- System clock input
	ce   :in std_logic := '1';
        rstn : in std_logic          -- Reset input (active low)
    );
end em3802;

architecture rtl of em3802 is
    -- Internal Signals
    signal reggroup : std_logic_vector(3 downto 0); -- Register group selector
    signal rstcount : integer range 0 to rstlen-1;  -- Reset counter
    signal crsten   : std_logic;       -- Reset enable signal
    signal crstn    : std_logic;       -- Combined reset signal

    -- Register bank signals for configuration and state
    signal R00, R01, R02 : std_logic_vector(7 downto 0); -- General-purpose registers
    signal R04, R05, R06 : std_logic_vector(7 downto 0); -- Additional registers
    signal R14, R16      : std_logic_vector(7 downto 0); -- Register group 1
    signal R24, R25, R26, R27 : std_logic_vector(7 downto 0); -- Register group 2
    signal R34, R35, R36 : std_logic_vector(7 downto 0); -- Register group 3
    signal R44, R45      : std_logic_vector(7 downto 0); -- Register group 4
    signal R54, R55 : std_logic_vector(7 downto 0); -- Register group 5
    signal R64, R65, R66, R67 : std_logic_vector(7 downto 0); -- Register group 6
    signal R74, R75, R76, R77 : std_logic_vector(7 downto 0); -- Register group 7
    signal R84, R85, R86, R87 : std_logic_vector(7 downto 0); -- Register group 8
    signal R94, R95, R96 : std_logic_vector(7 downto 0); -- Register group 9

    -- Interrupt management signals
    signal intclr   : std_logic_vector(7 downto 0); -- Interrupt clear
    signal intmask  : std_logic_vector(7 downto 0); -- Interrupt mask
    signal intstatus: std_logic_vector(7 downto 0); -- Interrupt status
    signal intvectoff : std_logic_vector(2 downto 0); -- Interrupt vector offset
signal	CT,OB,VE,VM	:std_logic;
signal	ASE,MCE,CDE,MCDS	:std_logic;
signal	MCFS	:std_logic_Vector(1 downto 0);
signal	rmsg_tx,rmsg_sync,rmsg_cc,rmsg_pc,rmsg_rc	:std_logic;
signal	rmsg_content	:std_logic_vector(2 downto 0);
-- UART-related signals
    signal fifo_IRx : std_logic;       -- UART RX FIFO interrupt
    signal irxfifowdat :std_logic_vector(7 downto 0);
    signal irxfifowr   :std_logic;
    signal irxfifodat  :std_logic_vector(7 downto 0);
    signal irxfifoempn :std_logic;
    signal irxfifofull :std_logic;
signal	rxrate	:std_logic_vector(4 downto 0);
signal	RxCL,RxPE,RxPL,RxEO,RxSL,RxST	:std_logic;
signal	IDCL		:std_logic;
signal	ID_MAKER	:std_logic_vector(6 downto 0);
signal	BDRE		:std_logic;
signal	ID_DEVICE:std_logic_vector(6 downto 0);
signal	RxC		:std_logic;
signal	RxOVC		:std_logic;
signal	FLTE		:std_logic;
signal	BLKC		:std_logic;
signal	RxOLC		:std_logic;
signal	AHE		:std_logic;
signal ah_state :integer range 0 to 4;
signal ah_busy :std_logic;
signal ah_maker_ok :std_logic;
signal ah_evac_f0 :std_logic_vector(7 downto 0);
signal ah_evac_maker :std_logic_vector(7 downto 0);
signal ah_evac_device :std_logic_vector(7 downto 0);
signal ah_replay_count :integer range 0 to 3;
signal ah_replay_index :integer range 0 to 2;
signal ah_replay_data :std_logic_vector(7 downto 0);
signal ah_direct_pass :std_logic;
signal rxfifo_req :std_logic;
signal	RxE		:std_logic;
signal	TxRx		:std_logic;
signal	TxDF		:std_logic;
signal	txrate	:std_logic_vector(4 downto 0);
signal	TxCL,TxPE,TxPL,TxEO,TxSL,TxST	:std_logic;
signal	TxC,BRKE,TxIDLC,TxE	:std_logic;

signal OUTE		:std_logic;
signal	CCLD			:std_logic;
signal	CCLDVAL	:std_logic_vector(6 downto 0);
signal	PCADD		:std_logic;
signal	PCCLR		:std_logic;
signal	INTRATE	:std_logic_vector(3 downto 0);
signal	PCADDVAL	:std_logic_vector(14 downto 0);
signal	GTLDVAL	:std_logic_vector(13 downto 0);
signal	GTLD		:std_logic;
signal	MTLDVAL	:std_logic_vector(13 downto 0);
signal	MTLD		:std_logic;

signal	txfifowdat	:std_logic_vector(7 downto 0);
signal	txfifowr		:std_logic;
signal	txfifowr_accept	:std_logic;
signal	txfifordat	:std_logic_vector(7 downto 0);
signal	txfiford		:std_logic;
signal	txfifoclr		:std_logic;
signal	txfifoempn	:std_logic;
signal	txfifofull	:std_logic;
signal itxfifowdat :std_logic_vector(7 downto 0);
signal itxfifowr   :std_logic;
signal itxfifodat  :std_logic_vector(7 downto 0);
signal itxfiford   :std_logic;
signal itxfifoempn :std_logic;
signal itxfifofull :std_logic;
signal itx_manual_req :std_logic;
signal itx_clock_pending :std_logic;

signal	rxfifowdat	:std_logic_vector(9 downto 0); -- RX FIFO write data
signal	rxfifowr		:std_logic;       -- RX FIFO write enable
signal	rxfifordat	:std_logic_vector(9 downto 0); -- RX FIFO data
signal	rxfiford		:std_logic;       -- RX FIFO read enable
signal	rxfifoclr		:std_logic;
signal	rxfifoempn	:std_logic;     -- RX FIFO empty flag
signal	rxfifofull	:std_logic;    -- RX FIFO full flag

    -- Counter and timing signals
    constant divm : integer := sysclk / oscm; -- Master clock divider
    constant divf : integer := sysclk / oscf; -- Fine clock divider
    signal countm : integer range 0 to divm; -- Master clock counter
    signal countf : integer range 0 to divf; -- Fine clock counter

signal	rxdivcount	:integer range 0 to 2047;
signal	rxsft			:std_logic;

signal	sftm			:std_logic;
signal	sftf			:std_logic;

signal	rxframelen	:integer range 1 to 13;
signal	srxbit		:std_logic;
signal	rxbyte		:std_logic_vector(7 downto 0);
signal	rxdata		:std_logic_vector(12 downto 0);
signal	rxdone		:std_logic;
signal rxframe_done :std_logic;
signal rx_midi_clock :std_logic;
signal	rxstoperr	:std_logic;
signal	rxparerr		:std_logic;
signal	rxstop2err	:std_logic;
signal	rxbusy		:std_logic;

signal	txdivcount	:integer range 0 to 2047;
signal	txsft			:std_logic;
signal	txframelen	:integer range 1 to 13;
signal	txdata		:std_logic_vector(12 downto 0);
signal	txen			:std_logic;
signal	txserial		:std_logic;
signal	txrd			:std_logic;
signal	txbusy		:std_logic;
signal txidle       :std_logic;
constant txidle_ticks :integer :=sysclk*80;
signal txidle_count :integer range 0 to txidle_ticks-1;
constant rxoffline_ticks :integer :=sysclk*300;
signal rxoffline_count :integer range 0 to rxoffline_ticks-1;
signal rxoffline :std_logic;
signal rxbreak_count :integer range 0 to 120;
signal rxbreak :std_logic;
signal rxbreak_event :std_logic;
signal active_sense_pending :std_logic;
signal txsource :std_logic_vector(7 downto 0);
signal	rstcmd		:std_logic;

signal	intgt		:std_logic;
signal	inttx		:std_logic;
signal	intrx		:std_logic;
signal	intol		:std_logic;
signal	intrc		:std_logic;
signal	intpc		:std_logic;
signal	intcc		:std_logic;
signal intmc :std_logic;
signal intirq1 :std_logic;
signal	intmm		:std_logic;

constant inum_gt	:integer	:=7;
constant inum_tx	:integer	:=6;
constant inum_rx	:integer	:=5;
constant inum_ol	:integer	:=4;
constant inum_rc	:integer	:=3;
constant inum_pc	:integer	:=2;
constant inum_cc	:integer	:=1;
constant inum_mm	:integer	:=0;

signal	intx		:std_logic_vector(7 downto 0);
signal	intm		:std_logic_vector(7 downto 0);
signal	intnum	:std_logic_vector(3 downto 0);

signal	gcounter	:std_logic_vector(13 downto 0);
signal	ccounter	:std_logic_vector(6 downto 0);
signal click_running       :std_logic;
signal click_start_pending :std_logic;
signal click_pulse :std_logic;
signal click_pulse_count :integer range 0 to 2047;
signal	mcounter	:std_logic_vector(13 downto 0);

signal  mclk        :std_logic;
signal midim_phase :std_logic;
signal  midi_clock_dist :std_logic;
signal interp_div16 :integer range 0 to 15;
signal interp_measure :integer range 0 to 1048575;
signal interp_measured :std_logic;
signal interp_spacing :integer range 0 to 1048575;
signal interp_countdown :integer range 0 to 1048575;
signal interp_emitted :integer range 0 to 15;
signal interp_due :integer range 0 to 16;
signal rcounter :std_logic_vector(7 downto 0);
signal recording_running :std_logic;
signal pcounter :integer range -32768 to 32767;
signal playback_running :std_logic;
signal sync_running :std_logic;
signal sync_pulse :std_logic;
signal sync_pulse_count :integer range 0 to 2047;
constant gczero	:std_logic_Vector(13 downto 0)	:=(others=>'0');
constant cczero	:std_logic_vector(6 downto 0)		:=(others=>'0');
constant mczero	:std_logic_Vector(13 downto 0)	:=(others=>'0');
signal	sreset	:std_logic;



component datfifo
generic(
	depth		:integer	:=32;
	dwidth	:integer	:=8
);
port(
	datin		:in std_logic_vector(dwidth-1 downto 0);
	datwr		:in std_logic;
	
	datout	:out std_logic_vector(dwidth-1 downto 0);
	datrd		:in std_logic;
	
	indat		:out std_logic;
	buffull	:out std_logic;
	datnum	:out integer range 0 to depth-1;
	
	clr		:in std_logic	:='0';
	
	clk		:in std_logic;
	ce   		:in std_logic := '1';
	rstn		:in std_logic
);
end component;

component rxframe
	generic(
		maxlen 	:integer	:=8;
		maxwid	:integer	:=4
	);
	port(
		SD		:in std_logic;	-- serial data input
		
		SFT		:in std_logic;	-- shift enable signal
		WIDTH	:in std_logic_vector(maxwid-1 downto 0);	-- 1bit width of serial
		LEN		:in integer range 1 to maxlen;
		
		DATA	:out std_logic_Vector(maxlen-1 downto 0);	--received data
		DONE	:out std_logic;	-- received

		BUSY	:out std_logic;
		STOPERR	:out std_logic;	-- stop error detect
		SFTRST	:in std_logic;	-- stop receive and reset
				
		clk		:in std_logic;	-- system clock
		ce   		:in std_logic := '1';
		rstn	:in std_logic	-- system reset
	);
end component;

component txframe
	generic(
		maxlen	:integer	:=8;		--max bits/frame
		maxwid	:integer	:=4			--max bit/clock
	);
	port(
		SD		:out std_logic;		-- serial data output
		DRCNT	:out std_logic;		-- driver control signal

		SFT		:in std_logic;		-- shift enable signal
		WIDTH	:in std_logic_vector(maxwid-1 downto 0);	-- 1bit width of serial
		LEN		:in integer range 1 to maxlen;		--bits/frame
		STPLEN	:in integer range 1 to 4;			--stop bit length*2
		
		DATA	:in std_logic_vector(maxlen-1 downto 0);	-- transmit data input
		WRITE	:in std_logic;		-- transmit write signal(start)
		BUFEMP	:out std_logic;		-- transmit buffer empty signal
		
		clk		:in std_logic;		-- system clock
		ce   		:in std_logic := '1';
		rstn	:in std_logic		-- system reset
	);
end component;

component txframenb
	generic(
		maxlen	:integer	:=8;		--max bits/frame
		maxwid	:integer	:=4			--max bit/clock
	);
	port(
		SD		:out std_logic;		-- serial data output
		DRCNT	:out std_logic;		-- driver control signal

		SFT		:in std_logic;		-- shift enable signal
		WIDTH	:in std_logic_vector(maxwid-1 downto 0);	-- 1bit width of serial
		LEN		:in integer range 1 to maxlen;		--bits/frame
		STPLEN	:in integer range 1 to 4;			--stop bit length*2
		
		DATA	:in std_logic_vector(maxlen-1 downto 0);	-- transmit data input
		EXDATA:in std_logic;		-- transmit buffer exist signal
		TXED	:out std_logic;		-- transmited signal(start)
		
		clk		:in std_logic;		-- system clock
		ce   		:in std_logic := '1';
		rstn	:in std_logic		-- system reset
	);
end component;


begin

	txfifo	:datfifo generic map(17,8) port map(
		datin		=>txfifowdat,
		datwr		=>txfifowr_accept,
		
		datout	=>txfifordat,
		datrd		=>txfiford,
		
		datnum	=>open,
		indat		=>txfifoempn,
		buffull	=>txfifofull,
		
		clr		=>txfifoclr,
		
		clk		=>clk,
		ce   		=>ce,
		rstn		=>rstn and (not sreset)
	);
	
	itxfifo :datfifo generic map(5,8) port map(
		datin   =>itxfifowdat,
		datwr   =>itxfifowr,
		datout  =>itxfifodat,
		datrd   =>itxfiford,
		datnum  =>open,
		indat   =>itxfifoempn,
		buffull =>itxfifofull,
		clr     =>TxC,
		clk     =>clk,
		ce      =>ce,
		rstn    =>rstn and (not sreset)
	);

	irxfifowdat<=rxbyte;
	irxfifowr<=rxframe_done and CDE and
		not rxstoperr and not rxstop2err and not rxparerr and
		'1' when rxbyte>=x"F9" and rxbyte<=x"FD" and
		(not irxfifofull or fifo_IRx)='1' else '0';

	rx_midi_clock<=rxframe_done and
		not rxstoperr and not rxstop2err and
		not rxparerr when rxbyte=x"F8" else '0';

	midi_clock_dist<=
		(mclk and not MCDS and
			(MCFS(1) and MCFS(0))) or
		(rx_midi_clock and not MCDS and
				not MCFS(1) and MCFS(0)) or
		(rmsg_tx and MCDS and
			not rmsg_content(2) and
			not rmsg_content(1) and
			not rmsg_content(0));

	itx_manual_req<=rmsg_tx and
		(rmsg_content(2) or rmsg_content(1) or rmsg_content(0)) and
		not (rmsg_content(2) and rmsg_content(1));
	itxfifowdat<=x"F8" + ("00000" & rmsg_content)
		when itx_manual_req='1' else
		x"F8" when itx_clock_pending='1' else x"FE";
	itxfifowr<=(itx_manual_req or itx_clock_pending or
		active_sense_pending) and
		(not itxfifofull or itxfiford);

	process(clk,rstn)
	begin
		if rising_edge(clk) then
			if(rstn='0')then
				itx_clock_pending<='0';
			elsif(ce='1')then
				if(sreset='1' or TxC='1')then
					itx_clock_pending<='0';
				elsif(midi_clock_dist='1' and MCE='1')then
					itx_clock_pending<='1';
				elsif(itxfifowr='1' and
					itx_manual_req='0' and
					itx_clock_pending='1')then
					itx_clock_pending<='0';
				end if;
			end if;
		end if;
	end process;

	-- Reset process: Initializes all internal registers and counters on reset
	process(clk,rstn)
	variable ltxfifoempn	:std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			inttx<='0';
			ltxfifoempn:='0';
		elsif(ce ='1')then
			if(sreset='1')then
				inttx<='0';
			elsif(TxC='1')then
				null;
			elsif(txfifowr_accept='1')then
				inttx<='0';
			elsif(txfifoempn='0' and ltxfifoempn='1')then
				inttx<='1';
			elsif(intclr(inum_tx)='1')then
				inttx<='0';
			end if;
			if(TxC='1')then
				ltxfifoempn:='0';
			else
				ltxfifoempn:=txfifoempn;
			end if;
		end if;
	end if;
	end process;
	
	irxfifo :datfifo generic map(5,8) port map(
		datin   =>irxfifowdat,
		datwr   =>irxfifowr,
		datout  =>irxfifodat,
		datrd   =>fifo_IRx,
		datnum  =>open,
		indat   =>irxfifoempn,
		buffull =>irxfifofull,
		clr     =>'0',
		clk     =>clk,
		ce      =>ce,
		rstn    =>rstn and (not sreset)
	);

	rxfifo  :datfifo generic map(129,10) port map(
		datin		=>rxfifowdat,
		datwr		=>rxfifowr,
		
		datout	=>rxfifordat,
		datrd		=>rxfiford,
		
		datnum	=>open,
		indat		=>rxfifoempn,
		buffull	=>rxfifofull,
		
		clr		=>rxfifoclr,
		
		clk		=>clk,
		ce   		=>ce,
		rstn		=>rstn and (not sreset)
	);
	
	process(clk,rstn,ce)
	variable lrxfifoempn :std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			intrx<='0';
			lrxfifoempn:='0';
		elsif(ce='1')then
			if(sreset='1' or RxC='1')then
				intrx<='0';
				lrxfifoempn:='0';
			else
				if(rxfifoempn='0')then
					intrx<='0';
				elsif(intclr(inum_rx)='1')then
					intrx<='0';
				elsif(lrxfifoempn='0')then
					intrx<='1';
				end if;

				lrxfifoempn:=rxfifoempn;
			end if;
		end if;
	end if;
	end process;
	

	process(clk,rstn,ce)begin
	if rising_edge(clk) then
		if(rstn='0')then
			rstcount<=rstlen-1;
			rstcmd<='0';
		elsif(ce ='1')then
			if(crsten='1')then
				if(rstcount>0)then
					rstcount<=rstcount-1;
					rstcmd<='0';
				else
					rstcmd<='1';
				end if;
			else
				rstcmd<='0';
			end if;
		end if;
	end if;
	end process;
	
	crstn<=rstn and (not rstcmd);
	
	process(clk,rstn,ce)
	variable ldatwr	:std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			intclr<=(others=>'0');
			R01<=(others=>'0');
			R04<=(others=>'0');
			R05<=x"02";
			R06<=(others=>'0');
			R14<=(others=>'0');
			R24<=(others=>'0');
			R25<=(others=>'0');
			R26<=(others=>'0');
			R27<=(others=>'0');
			R35<=(others=>'0');
			R44<=(others=>'0');
			R45<=(others=>'0');
			R55<=(others=>'0');
			R65<=(others=>'0');
			R66<=(others=>'0');
			R67<=(others=>'0');
			R76<=(others=>'0');
			R77<=(others=>'0');
			R84<=(others=>'0');
			R85<=(others=>'0');
			R86<=(others=>'0');
			R87<=(others=>'0');
			R94<=(others=>'0');
			R95<=(others=>'0');
			rmsg_tx<='0';
			rmsg_sync<='0';
			rmsg_cc<='0';
			rmsg_pc<='0';
			rmsg_rc<='0';
			rmsg_content<=(others=>'0');
			fifo_IRx<='0';
			txfifowdat<=(others=>'0');
			txfifowr<='0';
			CCLD<='0';
			PCADD<='0';
			PCCLR<='0';
			GTLD<='0';
			MTLD<='0';
			ldatwr:='0';
			sreset<='0';
		elsif(ce ='1')then
			intclr<=(others=>'0');
			rmsg_tx<='0';
			rmsg_sync<='0';
			rmsg_cc<='0';
			rmsg_pc<='0';
			rmsg_rc<='0';
			fifo_IRx<='0';
			RxC<='0';
			RxOVC<='0';
			BLKC<='0';
			RxOLC<='0';
			TxC<='0';
			TxIDLC<='0';
			txfifowr<='0';
			CCLD<='0';
			PCADD<='0';
			PCCLR<='0';
			GTLD<='0';
			MTLD<='0';
			sreset<='0';
			if(rstcmd='1')then
				sreset<='1';
				intclr<=(others=>'0');
				R01<=(others=>'0');
				R04<=(others=>'0');
				R05<=x"02";
				R06<=(others=>'0');
				R14<=(others=>'0');
				R24<=(others=>'0');
				R25<=(others=>'0');
				R26<=(others=>'0');
				R27<=(others=>'0');
				R35<=(others=>'0');
				R44<=(others=>'0');
				R45<=(others=>'0');
				R55<=(others=>'0');
				R65<=(others=>'0');
				R66<=(others=>'0');
				R67<=(others=>'0');
				R76<=(others=>'0');
				R77<=(others=>'0');
				R84<=(others=>'0');
				R85<=(others=>'0');
				R86<=(others=>'0');
				R87<=(others=>'0');
				R94<=(others=>'0');
				R95<=(others=>'0');
				rmsg_tx<='0';
				rmsg_sync<='0';
				rmsg_cc<='0';
				rmsg_pc<='0';
				rmsg_rc<='0';
				rmsg_content<=(others=>'0');
				fifo_IRx<='0';
				txfifowdat<=(others=>'0');
				txfifowr<='0';
				CCLD<='0';
				PCADD<='0';
				PCCLR<='0';
				GTLD<='0';
				MTLD<='0';
			end if;
			if(DATWR='1' and ldatwr='0')then
				case ADDR is
				when "001" =>
					R01<=DATIN;
				when "011" =>
					intclr<=DATIN;
				when "100" =>
					case reggroup is
					when x"0" =>
						R04<=DATIN;
					when x"1" =>
						R14<=DATIN;
					when x"2" =>
						R24<=DATIN;
					when x"4" =>
						R44<=DATIN;
					when x"8" =>
						R84<=DATIN;
					when x"9" =>
						R94<=DATIN;
					when others =>
					end case;
				when "101" =>
					case reggroup is
					when x"0" =>
						R05<=DATIN;
					when x"1" =>
						rmsg_content<=DATIN(2 downto 0);
						if(DATIN(2 downto 0)="000")then
							rmsg_tx<='1';
							rmsg_sync<='1';
							rmsg_cc<='1';
							rmsg_pc<='1';
							rmsg_rc<='1';
						else
							rmsg_tx<=DATIN(7);
							rmsg_sync<=DATIN(6);
							rmsg_cc<=DATIN(5);
							rmsg_pc<=DATIN(4);
							rmsg_rc<=DATIN(3);
						end if;
					when x"2" =>
						R25<=DATIN;
					when x"3" =>
						R35<=DATIN;
						RXOLC<=DATIN(2);
						BLKC<=DATIN(3);
						RXOVC<=DATIN(6);
						RXC<=DATIN(7);
					when x"4" =>
						R45<=DATIN;
						
					when x"5" =>
						R55<=DATIN;
						TXC<=DATIN(7);
						TxIDLC<=DATIN(2);
					when x"6" =>
						R65<=DATIN;
					when x"7" =>
						R75<=DATIN;
						PCADD<=DATIN(5);
						PCCLR<=DATIN(4);
					when x"8" =>
						R85<=DATIN;
						GTLD<=DATIN(7);
					when x"9" =>
						R95<=DATIN;
					when others =>
					end case;
				when "110" =>
					case reggroup is
					when x"0" =>
						R06<=DATIN;
					when x"2" =>
						R26<=DATIN;
					when x"5" =>
						txfifowdat<=DATIN;
						txfifowr<='1';
					when x"6" =>
						R66<=DATIN;
					when x"7" =>
						R76<=DATIN;
					when x"8" =>
						R86<=DATIN;
					when others =>
					end case;
				when "111" =>
					case reggroup is
					when x"1" =>
						fifo_IRx<=DATIN(0);
					when x"2" =>
						R27<=DATIN;
					when x"6" =>
						R67<=DATIN;
						CCLD<=DATIN(7);
					when x"7" =>
						R77<=DATIN;
					when x"8" =>
						R87<=DATIN;
						MTLD<=DATIN(7);
					when others =>
					end case;
				when others =>
				end case;
			end if;
			ldatwr:=datwr;
		end if;
	end if;
	end process;

	crsten<=R01(7);
	reggroup<=R01(3 downto 0);
	intvectoff<=R04(7 downto 5);
	CT<=R05(3);
	OB<=R05(2);
	VE<=R05(1);
	VM<=R05(0);
	intmask<=R06;
	ASE<=R14(5);
	MCE<=R14(4);
	CDE<=R14(3);
	MCDS<=R14(2);
	MCFS<=R14(1 downto 0);
	rxrate<=R24(4 downto 0);
	RxCL<=R25(5);
	RxPE<=R25(4);
	RxPL<=R25(3);
	RxEO<=R25(2);
	RxSL<=R25(1);
	RxST<=R25(0);
	IDCL<=R26(7);
	ID_MAKER<=R26(6 downto 0);
	BDRE<=R27(7);
	ID_DEVICE<=R27(6 downto 0);
	FLTE<=R35(4);
	AHE<=R35(1);
	RxE<=R35(0);
	TxRx<=R44(6);
	TxDF<=R44(5);
	txrate<=R44(4 downto 0);
	TxCL<=R45(5);
	TxPE<=R45(4);
	TxPL<=R45(3);
	TxEO<=R45(2);
	TxSL<=R45(1);
	TxST<=R45(0);
	BRKE<=R55(3);
	TxE<=R55(0);
	OUTE<=R66(0);
	CCLDVAL<=R67(6 downto 0);
	PCADDVAL<=R77(6 downto 0) & R76;
	INTRATE<=R75(3 downto 0);
	GTLDVAL<=R85(5 downto 0) & R84;
	MTLDVAL<=R87(5 downto 0) & R86;
	GPOE<=R94;
	GPOUT<=R95;
	process(clk)begin
	if rising_edge(clk) then

		if(ce = '1')then
			R96<=GPIN;
		end if;
	end if;
	end process;
	
	DATOUT<=	R00	when ADDR="000" else
				R02	when ADDR="010" else
				R04	when reggroup=x"0" and ADDR="100" else
				R05	when reggroup=x"0" and ADDR="101" else
				R06	when reggroup=x"0" and ADDR="110" else
				R14	when reggroup=x"1" and ADDR="100" else
				R16	when reggroup=x"1" and ADDR="110" else
				R24	when reggroup=x"2" and ADDR="100" else
				R25	when reggroup=x"2" and ADDR="101" else
				R26	when reggroup=x"2" and ADDR="110" else
				R27	when reggroup=x"2" and ADDR="111" else
				R34	when reggroup=x"3" and ADDR="100" else
				R35	when reggroup=x"3" and ADDR="101" else
				R36	when reggroup=x"3" and ADDR="110" else
				R44	when reggroup=x"4" and ADDR="100" else
				R45	when reggroup=x"4" and ADDR="101" else
				R54	when reggroup=x"5" and ADDR="100" else
				R55	when reggroup=x"5" and ADDR="101" else
				(others=>'0') when reggroup=x"5" and ADDR="111" else
				R64	when reggroup=x"6" and ADDR="100" else
				R65	when reggroup=x"6" and ADDR="101" else
				R66	when reggroup=x"6" and ADDR="110" else
				R67	when reggroup=x"6" and ADDR="111" else
				R74	when reggroup=x"7" and ADDR="100" else
				R75	when reggroup=x"7" and ADDR="101" else
				R76	when reggroup=x"7" and ADDR="110" else
				R77	when reggroup=x"7" and ADDR="111" else
				R84	when reggroup=x"8" and ADDR="100" else
				R85	when reggroup=x"8" and ADDR="101" else
				R86	when reggroup=x"8" and ADDR="110" else
				R87	when reggroup=x"8" and ADDR="111" else
				R94	when reggroup=x"9" and ADDR="100" else
				R95	when reggroup=x"9" and ADDR="101" else
				R96	when reggroup=x"9" and ADDR="110" else
				(others=>'0');
	
	-- FSK/TAPE interface is not implemented.
	-- Preserve documented idle output and direct RxF status.
	TxF<='0';
	R64(7)<=RxF;
	R64(6 downto 0)<=(others=>'0');
	SYNC<=sync_pulse;
	CLICK<=click_pulse when OUTE='1' else '0';
	R16<=irxfifodat when irxfifoempn='1' else x"00";
	R74<=rcounter;
	R34(7)<=rxfifoempn;
	rxfifoclr<=RxC;
	txfifowr_accept<=txfifowr and (not txfifofull or txfiford);
	txfifoclr<=TxC;
	R36<=rxfifordat(7 downto 0);
	
	process(clk,crstn,ce)
	variable rd,lrd	:std_logic;
	begin
	if rising_edge(clk) then
		if(crstn='0')then
			lrd:='0';
			rxfiford<='0';
		elsif(ce ='1')then
			rxfiford<='0';
			if(DATRD='1' and ADDR="110" and reggroup=x"3")then
				rd:='1';
			else
				rd:='0';
			end if;
			if(rd='0' and lrd='1')then
				rxfiford<='1';
			end if;
			lrd:=rd;
		end if;
	end if;
	end process;
	
	R54(7)<=not txfifoempn;
	R54(6)<=not txfifofull;
	R54(5 downto 3)<=(others=>'0');
	R54(2)<=txidle;
	R54(1)<='0';
	R54(0)<=txbusy;

	-- Latch TX idle and schedule Active Sense every 80 ms.
	process(clk,rstn)
	begin
		if rising_edge(clk) then
			if(rstn='0')then
				txidle<='0';
				txidle_count<=0;
				active_sense_pending<='0';
			elsif(ce='1')then
				if(sreset='1')then
					txidle<='0';
					txidle_count<=0;
					active_sense_pending<='0';
				else
					if(TxIDLC='1')then
						txidle<='0';
					end if;
					if(TxC='1')then
						active_sense_pending<='0';
					elsif(itxfifowr='1' and itx_manual_req='0' and
						itx_clock_pending='0')then
						active_sense_pending<='0';
					end if;
					if(TxE='0' or txfifoempn='1' or txbusy='1')then
						txidle_count<=0;
					elsif(txidle_count=txidle_ticks-1)then
						txidle<='1';
						txidle_count<=0;
						if(ASE='1')then
							active_sense_pending<='1';
						end if;
					else
						txidle_count<=txidle_count+1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	process(clk,crstn,ce)begin
		if rising_edge(clk) then
			if(crstn='0')then
				countm<=divm-1;
				sftm<='0';
			elsif(ce = '1')then
				sftm<='0';
				if(countm=0)then
					sftm<='1';
					countm<=divm-1;
				else
					countm<=countm-1;
				end if;
			end if;
		end if;
	end process;
	
	process(clk,crstn,ce)begin
		if rising_edge(clk) then
			if(crstn='0')then
				countf<=divf-1;
				sftf<='0';
			elsif(ce = '1')then
				sftf<='0';
				if(countf=0)then
					sftf<='1';
					countf<=divf-1;
				else
					countf<=countf-1;
				end if;
			end if;
		end if;
	end process;
	
	process(clk,crstn,ce)begin
		if rising_edge(clk) then
			if(crstn='0')then
				rxdivcount<=0;
			elsif(ce = '1')then
				rxsft<='0';
				if(rxrate(4)='0' and sftm='1' )then
					if(rxdivcount=0)then
						rxsft<='1';
						if(rxrate(3)='0')then
							rxdivcount<=3;
						else
							rxdivcount<=7;
						end if;
					else
						rxdivcount<=rxdivcount-1;
						if(rxrate(3)='0')then
							if(rxdivcount>3)then
								rxdivcount<=3;
							end if;
						else
							if(rxdivcount>7)then
								rxdivcount<=7;
							end if;
						end if;
					end if;
				elsif(rxrate(4)='1' and sftf='1')then
					if(rxdivcount=0)then
						rxsft<='1';
						case rxrate(3 downto 0)is
						when x"8" =>
							rxdivcount<=15;
						when x"9" =>
							rxdivcount<=31;
						when x"a" =>
							rxdivcount<=63;
						when x"b" =>
							rxdivcount<=127;
						when x"c" =>
							rxdivcount<=255;
						when x"d" =>
							rxdivcount<=511;
						when x"e" =>
							rxdivcount<=1023;
						when x"f" =>
							rxdivcount<=2047;
						when others =>
							rxdivcount<=7;
						end case;
					else
						rxdivcount<=rxdivcount-1;
						case rxrate(3 downto 0) is
						when x"8" =>
							if(rxdivcount>15)then
								rxdivcount<=15;
							end if;
						when x"9" =>
							if(rxdivcount>31)then
								rxdivcount<=31;
							end if;
						when x"a" =>
							if(rxdivcount>63)then
								rxdivcount<=63;
							end if;
						when x"b" =>
							if(rxdivcount>127)then
								rxdivcount<=127;
							end if;
						when x"c" =>
							if(rxdivcount>255)then
								rxdivcount<=255;
							end if;
						when x"d" =>
							if(rxdivcount>511)then
								rxdivcount<=511;
							end if;
						when x"e" =>
							if(rxdivcount>1023)then
								rxdivcount<=1023;
							end if;
						when x"f" =>
						when others =>
							if(rxdivcount>7)then
								rxdivcount<=7;
							end if;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	process(clk,crstn,ce)begin
		if rising_edge(clk) then
			if(crstn='0')then
				srxbit<='1';
			elsif(ce = '1')then
				if(RxE='1' or rxbusy='1')then
					srxbit<=RxD;
				else
					srxbit<='1';
				end if;
			end if;
		end if;
	end process;
	
	process(RxCL,RxPE,RxPL,RxSL)
	variable vlen	:integer range 1 to 13;
	begin
		if(RxCL='1')then
			vlen:=7;
		else
			vlen:=8;
		end if;
		if(RxPE='1')then
			if(RxPL='1')then
				vlen:=vlen+4;
			else
				vlen:=vlen+1;
			end if;
		end if;
		if(RxSL='1')then
			vlen:=vlen+1;
		end if;
		rxframelen<=vlen;
	end process;
	
	rxunit	:rxframe generic map(13,3) port map(
		SD		=>srxbit,
		
		SFT		=>rxsft,
		WIDTH		=>"100",
		LEN		=>rxframelen,
		
		DATA		=>rxdata,
		DONE		=>rxdone,
		
		BUSY		=>rxbusy,
		STOPERR	=>rxstoperr,
		SFTRST	=>'0',
				
		clk		=>clk,
		ce   		=>ce,
		rstn		=>crstn
	);
	rxbyte<=rxdata(7 downto 0) when RxCL='0' else ('0' & rxdata(6 downto 0));
	process(rxframe_done,rxdata,RxCL,RxPE,RxPL,RxEO,RxSL,RxST)
	variable	par	:std_logic;
	variable	par4	:std_logic_vector(3 downto 0);
	variable	parloc	:integer range 0 to 12;
	variable parlen	:integer range 0 to 4;
	begin
		rxparerr<='0';
		rxstop2err<='0';

		if(rxframe_done='1')then
			par:='0';
			if(RxCL='0')then
				for i in 0 to 7 loop
					par:=par xor rxdata(i);
				end loop;
				par4:=rxdata(3 downto 0) xor rxdata(7 downto 4);
				parloc:=8;
			else
				for i in 0 to 6 loop
					par:=par xor rxdata(i);
				end loop;
				par4:=rxdata(3 downto 0) xor ('0' & rxdata(6 downto 4));
				parloc:=7;
			end if;
			if(RxPE='1')then
				if(RxPL='0')then
					parlen:=1;
					if(RxEO='0')then
						if(par=rxdata(parloc))then
							rxparerr<='0';
						else
							rxparerr<='1';
						end if;
					else
						if(par=rxdata(parloc))then
							rxparerr<='1';
						else
							rxparerr<='0';
						end if;
					end if;
				else
					parlen:=4;
					if(RxEO='0')then
						if(par4=rxdata(parloc+3 downto parloc))then
							rxparerr<='0';
						else
							rxparerr<='1';
						end if;
					else
						if((par4 xor rxdata(parloc+3 downto parloc))="0000")then
							rxparerr<='0';
						else
							rxparerr<='1';
						end if;
					end if;
				end if;
			else
				rxparerr<='0';
				parlen:=0;
			end if;
			if(RxSL='1')then
				if(RxST='1')then
					if(rxdata(parloc+parlen)='0')then
						rxstop2err<='0';
					else
						rxstop2err<='1';
					end if;
				else
					if(rxdata(parloc+parlen)='0')then
						rxstop2err<='1';
					else
						rxstop2err<='0';
					end if;
				end if;
			else
				rxstop2err<='0';
			end if;
		end if;
	end process;
	
	rxframe_done<=rxdone or rxstoperr;
        ah_replay_data<=ah_evac_f0 when ah_replay_index=0 else
                ah_evac_maker when ah_replay_index=1 else
                ah_evac_device;

        ah_direct_pass<='1' when
                rxstoperr='1' or rxstop2err='1' or rxparerr='1' or
                rxbyte>=x"F8" or AHE='0' or
                (rxbyte>=x"80" and rxbyte<=x"F7" and rxbyte/=x"F0") or
                (rxbyte/=x"F0" and (ah_state=0 or ah_state=3))
                else '0';

        rxfifo_req<='1' when ah_replay_count>0 else
                rxframe_done and not (FLTE and rx_midi_clock) and
                ah_direct_pass;
        rxfifowr<=rxfifo_req and not rxfifofull;
	
	process(clk,crstn,ce)begin
	if rising_edge(clk) then

		if(crstn='0')then
			R34(6)<='0';
		elsif(ce ='1')then
			if(rxfifofull='1' and rxfifo_req='1')then
				R34(6)<='1';
			elsif(RxOVC='1')then
				R34(6)<='0';
			end if;
		end if;
	end if;
	end process;
	R34(5)<=rxfifordat(9) when rxfifoempn='1' else '0';
	R34(4)<=rxfifordat(8) when rxfifoempn='1' else '0';
	R34(3)<=rxbreak;
	R34(2)<=rxoffline;
	R34(1)<=ah_busy;
	R34(0)<=rxbusy;
	
        rxfifowdat<="00" & ah_replay_data when ah_replay_count>0 else
                (rxstoperr or rxstop2err) & rxparerr & rxbyte;

	process(clk,crstn)begin
	if rising_edge(clk) then

		if(crstn='0')then
			txdivcount<=0;
		elsif(ce ='1')then
			txsft<='0';
			if(txrate(4)='0' and sftm='1' )then
				if(txdivcount=0)then
					txsft<='1';
					if(txrate(3)='0')then
						txdivcount<=3;
					else
						txdivcount<=7;
					end if;
				else
					txdivcount<=txdivcount-1;
					if(txrate(3)='0')then
						if(txdivcount>3)then
							txdivcount<=3;
						end if;
					else
						if(txdivcount>7)then
							txdivcount<=7;
						end if;
					end if;
				end if;
			elsif(txrate(4)='1' and sftf='1')then
				if(txdivcount=0)then
					txsft<='1';
					case txrate(3 downto 0) is
					when x"8" =>
						txdivcount<=15;
					when x"9" =>
						txdivcount<=31;
					when x"a" =>
						txdivcount<=63;
					when x"b" =>
						txdivcount<=127;
					when x"c" =>
						txdivcount<=255;
					when x"d" =>
						txdivcount<=511;
					when x"e" =>
						txdivcount<=1023;
					when x"f" =>
						txdivcount<=2047;
					when others =>
						txdivcount<=7;
					end case;
				else
					txdivcount<=txdivcount-1;
					case txrate(3 downto 0) is
					when x"8" =>
						if(txdivcount>15)then
							txdivcount<=15;
						end if;
					when x"9" =>
						if(txdivcount>31)then
							txdivcount<=31;
						end if;
					when x"a" =>
						if(txdivcount>63)then
							txdivcount<=63;
						end if;
					when x"b" =>
						if(txdivcount>127)then
							txdivcount<=127;
						end if;
					when x"c" =>
						if(txdivcount>255)then
							txdivcount<=255;
						end if;
					when x"d" =>
						if(txdivcount>511)then
							txdivcount<=511;
						end if;
					when x"e" =>
						if(txdivcount>1023)then
							txdivcount<=1023;
						end if;
					when x"f" =>
					when others =>
						if(txdivcount>7)then
							txdivcount<=7;
						end if;
					end case;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	
	txfiford<=txrd and not itxfifoempn;
	itxfiford<=txrd and itxfifoempn;
	txsource<=itxfifodat when itxfifoempn='1' else txfifordat;
	--process(clk,crstn)
	process(clk)
	variable vlen	:integer range 1 to 13;
	variable	par	:std_logic;
	variable par4	:std_logic_vector(3 downto 0);
	begin
		if rising_edge(clk) then
		--	if(crstn='0')then
		--		txwr<='0';
		--		txdata<=(others=>'0');
		--		txfiford<='0';
		--		txframelen<=1;
		--	elsif(ce ='1')then
		--		txwr<='0';
		--		txfiford<='0';
		--		if(txemp='1' and txfifoemp='0')then
		--			txwr<='1';
		--			txfiford<='1';
		if(TxCL='0')then
			txdata(7 downto 0)<=txsource;
			vlen:=8;
		else
			txdata(6 downto 0)<=txsource(6 downto 0);
			vlen:=7;
		end if;
		if(TxPE='1')then
			if(TxPL='0')then
				par:=TxEO;
				for i in 0 to 7 loop
					if(TxCL='0' or i<7)then
						par:=par xor txsource(i);
					end if;
				end loop;
				txdata(vlen)<=par;
				vlen:=vlen+1;
			else
				par4:=(others=>TxEO);
				if(TxCL='0')then
					par4:=par4 xor txsource(3 downto 0) xor txsource(7 downto 4);
				else
					par4:=par4 xor txsource(3 downto 0) xor ('0' & txsource(6 downto 4));
				end if;
				txdata(vlen+3 downto vlen)<=par4;
				vlen:=vlen+4;
			end if;
		end if;
		if(TxSL='1')then
			txdata(vlen)<=not TxST;
			vlen:=vlen+1;
		end if;
		txframelen<=vlen;
	--			end if;
	--		end if;
	--	end if;
	end if;
	end process;

	
	TxD<='0' when BRKE='1' else
		RxD when TxRx='1' else
		'1' when TxDF='1' else txserial;

	txen<=TXE and (txfifoempn or itxfifoempn);
	
	txunit	:txframenb	generic map(13,3)	port map(
		SD			=>txserial,
		DRCNT		=>txbusy,

		SFT		=>txsft,
		WIDTH		=>"100",
		LEN		=>txframelen,
		STPLEN	=>2,
		
		DATA		=>txdata,
		EXDATA	=>txen,
		TXED		=>txrd,
		
		clk		=>clk,
		ce   		=>ce,
		rstn		=>crstn
	);
	
	-- MIDI clock interval measurement at CLK/16.
	process(clk,rstn)begin
	if rising_edge(clk) then
		if(rstn='0')then
			interp_div16<=0;
			interp_measure<=0;
			interp_measured<='0';
		elsif(ce='1')then
			if(sreset='1')then
				interp_div16<=0;
				interp_measure<=0;
				interp_measured<='0';
			else
				if(interp_div16=15)then
					interp_div16<=0;
					if(interp_measure<1048575)then
						interp_measure<=interp_measure+1;
					end if;
				else
					interp_div16<=interp_div16+1;
				end if;
				if(midi_clock_dist='1')then
					interp_measure<=0;
					interp_measured<='1';
				end if;
			end if;
		end if;
	end if;
	end process;

	-- MIDI clock interpolation and missing-clock compensation.
	process(clk,rstn)
	variable rate :integer range 0 to 15;
	variable measured_now :integer range 0 to 1048575;
	variable missing :integer range 0 to 15;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			interp_spacing<=0;
			interp_countdown<=0;
			interp_emitted<=0;
			interp_due<=0;
		elsif(ce='1')then
			interp_due<=0;
			rate:=conv_integer(INTRATE);
			if(sreset='1' or rate=0)then
				interp_spacing<=0;
				interp_countdown<=0;
				interp_emitted<=0;
			elsif(midi_clock_dist='1')then
				if(interp_div16=15 and interp_measure<1048575)then
					measured_now:=interp_measure+1;
				else
					measured_now:=interp_measure;
				end if;
				if(interp_measured='1')then
					interp_spacing<=measured_now/rate;
					interp_countdown<=measured_now/rate;
					if(interp_emitted<rate)then
						missing:=rate-interp_emitted;
					else
						missing:=0;
					end if;
					interp_due<=missing+1;
				else
					interp_due<=1;
				end if;
				interp_emitted<=1;
			elsif(interp_div16=15 and interp_spacing>0 and
			      interp_emitted<rate)then
				if(interp_countdown<=1)then
					interp_due<=1;
					interp_emitted<=interp_emitted+1;
					interp_countdown<=interp_spacing;
				else
					interp_countdown<=interp_countdown-1;
				end if;
			end if;
		end if;
	end if;
	end process;

	--counter section
	
	process(clk,rstn)begin
	if rising_edge(clk) then

		if(rstn='0')then
			gcounter<=(others=>'0');
			intgt<='0';
		elsif(ce ='1')then
			if(sreset='1')then
				gcounter<=(others=>'0');
				intgt<='0';
			else
				if(intclr(inum_gt)='1')then
					intgt<='0';
				end if;
				if(GTLD='1')then
					gcounter<=GTLDVAL;
				elsif(gcountsft='1')then
					if(gcounter>1)then
						gcounter<=gcounter-1;
					elsif(gcounter=1 and GTLDVAL>1)then
						intgt<='1';
						gcounter<=GTLDVAL;
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	process(clk,rstn)begin
	if rising_edge(clk) then

		if(rstn='0')then
			ccounter<=(others=>'0');
			intcc<='0';
			click_running<='0';
			click_start_pending<='0';
			click_pulse<='0';
			click_pulse_count<=0;
		elsif(ce='1')then
			if(sreset='1')then
				intcc<='0';
				ccounter<=(others=>'0');
				click_running<='0';
				click_start_pending<='0';
				click_pulse<='0';
				click_pulse_count<=0;
			else
				if(sftm='1' and click_pulse='1')then
					if(click_pulse_count=0)then
						click_pulse<='0';
					else
						click_pulse_count<=click_pulse_count-1;
					end if;
				end if;
				if(intclr(inum_cc)='1' and CT='0')then
					intcc<='0';
				end if;

				if(rmsg_cc='1')then
					case rmsg_content is
					when "010" =>
						click_running<='1';
						click_start_pending<='1';
					when "011" =>
						click_running<='0';
						click_start_pending<='0';
					when "100" =>
						click_running<='1';
					when others =>
					end case;
				elsif(CCLD='1' and CCLDVAL>1)then
					ccounter<=CCLDVAL;
					intcc<='1';
					click_pulse<='1';
					click_pulse_count<=2047;
				elsif(midi_clock_dist='1' and click_running='1')then
					if(click_start_pending='1')then
						click_start_pending<='0';
						if(CCLDVAL>1)then
							ccounter<=CCLDVAL;
							intcc<='1';
							click_pulse<='1';
							click_pulse_count<=2047;
						end if;
					elsif(ccounter>0)then
						ccounter<=ccounter-1;
					elsif(CCLDVAL/=cczero)then
						intcc<='1';
						click_pulse<='1';
						click_pulse_count<=2047;
						ccounter<=CCLDVAL;
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;

	process(clk,rstn)begin
	if rising_edge(clk) then

		if(rstn='0')then
			mcounter<=(others=>'0');
			midim_phase<='0';
			mclk<='0';

		elsif(ce ='1')then
			mclk<='0';

			if(sreset='1')then
				mcounter<=(Others=>'0');
				midim_phase<='0';

			else
				if(mcountsft='1')then
					if(MCE='1')then
						midim_phase<=not midim_phase;
					else
						midim_phase<='0';
					end if;
				end if;
				if(MTLD='1' and MTLDVAL>1)then
					mcounter<=MTLDVAL;
					mclk<='1';

				elsif(mcountsft='1' and (MCE='0' or midim_phase='1'))then
					if(mcounter>0)then
						mcounter<=mcounter-1;
					elsif(MTLDVAL>1)then
						mcounter<=MTLDVAL;
						mclk<='1';
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	-- SYNC controller with 2.048 ms output pulse.
	process(clk,rstn)begin
	if rising_edge(clk) then
		if(rstn='0')then
			sync_running<='0';
			sync_pulse<='0';
			sync_pulse_count<=0;
		elsif(ce='1')then
			if(sreset='1')then
				sync_running<='0';
				sync_pulse<='0';
				sync_pulse_count<=0;
			else
				if(rmsg_sync='1')then
					case rmsg_content is
					when "010" =>
						sync_running<='1';
					when "011" =>
						sync_running<='0';
					when "100" =>
						sync_running<='1';
					when others =>
					end case;
				end if;
				if(midi_clock_dist='1' and sync_running='1')then
					sync_pulse<='1';
					sync_pulse_count<=2047;
				elsif(sftm='1' and sync_pulse='1')then
					if(sync_pulse_count=0)then
						sync_pulse<='0';
					else
						sync_pulse_count<=sync_pulse_count-1;
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;

	-- Playback counter controlled by R15 PC destination.
	process(clk,rstn)
	variable rate :integer range 0 to 15;
	variable pending :integer range 0 to 15;
	variable value :integer range -65536 to 65534;
	variable changed :std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			pcounter<=0;
			playback_running<='0';
			intpc<='0';
		elsif(ce='1')then
			if(sreset='1')then
				pcounter<=0;
				playback_running<='0';
				intpc<='0';
			else
				rate:=conv_integer(INTRATE);
				value:=pcounter;
				changed:='0';
				if(PCCLR='1')then
					value:=0;
					changed:='1';
				end if;
				if(PCADD='1')then
					value:=value+conv_integer(PCADDVAL);
					changed:='1';
				end if;
				if(rmsg_pc='1')then
					case rmsg_content is
					when "010" =>
						value:=0;
						changed:='1';
						playback_running<='1';
					when "011" =>
						if(playback_running='1' and rate>0)then
							if(interp_emitted<rate)then
								pending:=rate-interp_emitted;
							else
								pending:=0;
							end if;
							value:=value-pending;
							changed:='1';
						end if;
						playback_running<='0';
					when "100" =>
						playback_running<='1';
					when others =>
					end case;
				elsif(playback_running='1' and interp_due>0)then
					value:=value-interp_due;
					changed:='1';
				end if;
				if(value>32767)then
					value:=value-65536;
				elsif(value< -32768)then
					value:=value+65536;
				end if;
				pcounter<=value;
				if(changed='1')then
					if(value<=0)then
						intpc<='1';
					else
						intpc<='0';
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;

	-- Recording counter controlled by R15 RC destination.
	process(clk,rstn)
	variable rate :integer range 0 to 15;
	variable pending :integer range 0 to 15;
	variable total :integer range 0 to 271;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			rcounter<=(others=>'0');
			recording_running<='0';
			intrc<='0';
		elsif(ce='1')then
			if(sreset='1')then
				rcounter<=(others=>'0');
				recording_running<='0';
				intrc<='0';
			else
				if(intclr(inum_rc)='1')then
					intrc<='0';
				end if;
				rate:=conv_integer(INTRATE);
				if(rmsg_rc='1')then
					case rmsg_content is
					when "010" =>
						rcounter<=(others=>'0');
						recording_running<='1';
					when "011" =>
						if(recording_running='1' and rate>0)then
							if(interp_emitted<rate)then
								pending:=rate-interp_emitted;
							else
								pending:=0;
							end if;
							total:=conv_integer(rcounter)+pending;
							rcounter<=conv_std_logic_vector(total mod 256,8);
							if(total>=256)then
								intrc<='1';
							end if;
						end if;
						recording_running<='0';
					when "100" =>
						recording_running<='1';
					when others =>
					end case;
				elsif(recording_running='1' and interp_due>0)then
					total:=conv_integer(rcounter)+interp_due;
					rcounter<=conv_std_logic_vector(total mod 256,8);
					if(total>=256)then
						intrc<='1';
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;

	-- Address Hunter filtering and evacuated-byte replay.
	process(clk,rstn)begin
	if rising_edge(clk) then
	    if(rstn='0')then
	        ah_state<=0;
	        ah_busy<='0';
	        ah_maker_ok<='0';
	        ah_evac_f0<=(others=>'0');
	        ah_evac_maker<=(others=>'0');
	        ah_evac_device<=(others=>'0');
	        ah_replay_count<=0;
	        ah_replay_index<=0;
	    elsif(ce='1')then
	        if(sreset='1' or AHE='0')then
	            ah_state<=0;
	            ah_busy<='0';
	            ah_maker_ok<='0';
	            ah_replay_count<=0;
	            ah_replay_index<=0;
	        else
	            if(ah_replay_count>0 and rxfifofull='0')then
	                if(ah_replay_count=1)then
	                    ah_replay_count<=0;
	                else
	                    ah_replay_count<=ah_replay_count-1;
	                    ah_replay_index<=ah_replay_index+1;
	                end if;
	            end if;

	            if(rxframe_done='1' and
	              rxstoperr='0' and rxstop2err='0' and
	              rxparerr='0')then
	            if(rxbyte=x"F0")then
	                ah_evac_f0<=rxbyte;
	                ah_state<=1;
	                ah_busy<='1';
	                ah_maker_ok<='0';
	                    ah_replay_count<=0;
	                    ah_replay_index<=0;
	            elsif(rxbyte>=x"80" and rxbyte<=x"F7")then
	                ah_state<=0;
	                ah_busy<='0';
	                    ah_replay_count<=0;
	                    ah_replay_index<=0;
	            elsif(rxbyte<x"80")then
	                case ah_state is
	                when 1 =>
	                    ah_evac_maker<=rxbyte;
	                    if(rxbyte(6 downto 0)=ID_MAKER)then
	                        ah_maker_ok<='1';
	                        if(IDCL='1')then
	                            ah_state<=2;
	                        else
	                            ah_state<=3;
	                                ah_replay_count<=2;
	                                ah_replay_index<=0;
	                        end if;
	                    else
	                        ah_maker_ok<='0';
	                        ah_state<=4;
	                    end if;
	                when 2 =>
	                    ah_evac_device<=rxbyte;
	                    if(ah_maker_ok='1' and
	                      (rxbyte(6 downto 0)=ID_DEVICE or
	                       (BDRE='1' and rxbyte=x"7F")))then
	                        ah_state<=3;
	                            ah_replay_count<=3;
	                            ah_replay_index<=0;
	                    else
	                        ah_state<=4;
	                    end if;
	                when others =>
	                end case;
	                end if;
	            end if;
	        end if;
	    end if;
	end if;
	end process;

	-- BREAK detector: RxD low for two character periods.
	process(clk,rstn)
	variable break_limit :integer range 16 to 120;
	begin
	if rising_edge(clk) then
	    if(rstn='0')then
	        rxbreak_count<=0;
	        rxbreak<='0';
	        rxbreak_event<='0';
	    elsif(ce='1')then
	        rxbreak_event<='0';
	        if(sreset='1')then
	            rxbreak_count<=0;
	            rxbreak<='0';
	        elsif(BLKC='1' or intclr(inum_ol)='1')then
	            rxbreak_count<=0;
	            rxbreak<='0';
	        elsif(RxE='0' or srxbit='1')then
	            rxbreak_count<=0;
	        elsif(rxsft='1')then
	            break_limit:=8*(rxframelen+2);
	            if(rxbreak_count>=break_limit-1)then
	                rxbreak_count<=break_limit;
	                if(rxbreak='0')then
	                    rxbreak<='1';
	                    rxbreak_event<='1';
	                end if;
	            else
	                rxbreak_count<=rxbreak_count+1;
	            end if;
	        end if;
	    end if;
	end if;
	end process;

	-- Receiver off-line detector, approximately 300 ms.
	process(clk,rstn)begin
	if rising_edge(clk) then
	    if(rstn='0')then
	        rxoffline_count<=0;
	        rxoffline<='0';
	        intol<='0';
	    elsif(ce='1')then
	        if(sreset='1' or RxE='0')then
	            rxoffline_count<=0;
	            rxoffline<='0';
	            intol<='0';
	        else
	            if(RxOLC='1' or intclr(inum_ol)='1')then
	                rxoffline<='0';
	            end if;
	            if(RxOLC='1' or BLKC='1' or intclr(inum_ol)='1')then
	                intol<='0';
	            end if;
	            if(rxbreak_event='1' and OB='1')then
	                intol<='1';
	            end if;
	            if(rxframe_done='1')then
	                rxoffline_count<=0;
	            elsif(rxoffline_count=rxoffline_ticks-1)then
	                rxoffline_count<=0;
	                rxoffline<='1';
	                if(OB='0')then
	                    intol<='1';
	                end if;
	            else
	                rxoffline_count<=rxoffline_count+1;
	            end if;
	        end if;
	    end if;
	end if;
	end process;

	-- MIDI clock detect latch for selectable IRQ-1.
	process(clk,rstn)begin
	if rising_edge(clk) then
		if(rstn='0')then
			intmc<='0';
		elsif(ce='1')then
			if(sreset='1')then
				intmc<='0';
			elsif(intclr(inum_cc)='1' and CT='1')then
				intmc<='0';
			elsif(midi_clock_dist='1' and MCDS='0')then
				intmc<='1';
			end if;
		end if;
	end if;
	end process;

	--interrupt session
	
	process(clk,rstn)
	variable irx_front_delivered :std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			intmm<='0';
			irx_front_delivered:='0';
		elsif(ce='1')then
			if(sreset='1')then
				intmm<='0';
				irx_front_delivered:='0';
			elsif(irxfifoempn='0')then
				intmm<='0';
				irx_front_delivered:='0';
			elsif(fifo_IRx='1')then
				intmm<='0';
				irx_front_delivered:='0';
			elsif(intclr(inum_mm)='1')then
				intmm<='0';
			elsif(irx_front_delivered='0')then
				intmm<='1';
				irx_front_delivered:='1';
			end if;
		end if;
	end if;
	end process;
	
	intirq1<=intmc when CT='1' else intcc;
	intx<=intgt & inttx & intrx & intol & intrc & intpc & intirq1 & intmm;
	intm<=intx and intmask;
	R02<=intx;
	
	process(intm)
	variable num	:integer range 0 to 8;
	begin
		num:=8;
		for i in 7 downto 0 loop
			if(intm(i)='1')then
				num:=i;
				exit;
			end if;
		end loop;
		intnum<=conv_std_logic_vector(num,4);
		if(num=8)then
			INT<='0';
		else
			INT<='1';
		end if;
	end process;
	
	R00(7 downto 5)<=intvectoff;
	R00(0)<='0';
	R00(4 downto 1)<=intnum;

	IVECT<=R00 when VE='1' and (VM='1' or intm/=x"00") else (others=>'0');
	
end rtl;
