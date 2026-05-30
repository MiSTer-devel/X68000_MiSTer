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
    signal R54, R55, R57 : std_logic_vector(7 downto 0); -- Register group 5
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
signal	rxrate	:std_logic_vector(4 downto 0);
signal	rxsrc		:std_logic;
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
signal	RxE		:std_logic;
signal	TxRx		:std_logic;
signal	TxDF		:std_logic;
signal	txrate	:std_logic_vector(4 downto 0);
signal	TxCL,TxPE,TxPL,TxEO,TxSL,TxST	:std_logic;
signal	TxC,BRKE,TxIDLC,TxE	:std_logic;
signal	ME,CFC,DE,APD,PN,PDFC	:std_logic;
signal	CLKM,OUTE	:std_logic;
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
signal	txfifordat	:std_logic_vector(7 downto 0);
signal	txfiford		:std_logic;
signal	txfifoclr		:std_logic;
signal	txfifoempn	:std_logic;
signal	txfifofull	:std_logic;

signal	rxfifowdat	:std_logic_vector(7 downto 0); -- RX FIFO write data
signal	rxfifowr		:std_logic;       -- RX FIFO write enable
signal	rxfifordat	:std_logic_vector(7 downto 0); -- RX FIFO data
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
signal	rxstoperr	:std_logic;
signal	rxparerr		:std_logic;
signal	rxstop2err	:std_logic;
signal	rxbusy		:std_logic;

signal	txdivcount	:integer range 0 to 2047;
signal	txsft			:std_logic;
signal	txframelen	:integer range 1 to 13;
signal	txdata		:std_logic_vector(12 downto 0);
signal	txen			:std_logic;
signal	txrd			:std_logic;
signal	txbusy		:std_logic;
signal	rstcmd		:std_logic;

signal	intgt		:std_logic;
signal	inttx		:std_logic;
signal	intrx		:std_logic;
signal	intol		:std_logic;
signal	intrc		:std_logic;
signal	intpc		:std_logic;
signal	intcc		:std_logic;
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
signal	mcounter	:std_logic_vector(13 downto 0);
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

	txfifo	:datfifo generic map(64,8) port map(
		datin		=>txfifowdat,
		datwr		=>txfifowr,
		
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
	
	-- Reset process: Initializes all internal registers and counters on reset
	process(clk,rstn)
	variable ltxfifoempn	:std_logic;
	begin
	if rising_edge(clk) then
		if(rstn='0')then
			inttx<='1';
			ltxfifoempn:='0';
		elsif(ce ='1')then
			if(sreset='1')then
				inttx<='1';
			elsif(txfifoempn='0' and ltxfifoempn='1')then
				inttx<='1';
			elsif(intclr(inum_tx)='1')then
				inttx<='0';
			end if;
			ltxfifoempn:=txfifoempn;
		end if;
	end if;
	end process;
	
	rxfifo	:datfifo generic map(128,8) port map(
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
	
	process(clk,rstn,ce)begin
	if rising_edge(clk) then
		if(rstn='0')then
			intrx<='0';
		elsif(ce ='1')then
			if(sreset='1')then
				intrx<='0';
			elsif(rxfifoempn='1')then
				intrx<='1';
			elsif(intclr(inum_rx)='1')then
				intrx<='0';
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
			R05<=(others=>'0');
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
			rmsg_tx<='0';
			rmsg_sync<='0';
			rmsg_cc<='0';
			rmsg_pc<='0';
			rmsg_rc<='0';
			rmsg_content<=(others=>'0');
			fifo_IRx<='0';
			rxsrc<='0';
			txfifowdat<=(others=>'0');
			txfifowr<='0';
			CCLD<='0';
			PCADD<='0';
			PCCLR<='0';
			INTRATE<=(others=>'0');
			PCADDVAL<=(others=>'0');
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
			CFC<='0';
			PDFC<='0';
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
				R05<=(others=>'0');
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
				R76<=(others=>'0');
				R77<=(others=>'0');
				R84<=(others=>'0');
				R85<=(others=>'0');
				R86<=(others=>'0');
				R87<=(others=>'0');
				rmsg_tx<='0';
				rmsg_sync<='0';
				rmsg_cc<='0';
				rmsg_pc<='0';
				rmsg_rc<='0';
				rmsg_content<=(others=>'0');
				fifo_IRx<='0';
				rxsrc<='0';
				txfifowdat<=(others=>'0');
				txfifowr<='0';
				CCLD<='0';
				PCADD<='0';
				PCCLR<='0';
				INTRATE<=(others=>'0');
				PCADDVAL<=(others=>'0');
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
						CFC<=DATIN(4);
						PDFC<=DATIN(0);
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
	rxsrc<=R24(5);
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
	ME<=R65(7);
	DE<=R65(3);
	APD<=R65(2);
	PN<=R65(1);
	CLKM<=R66(1);
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
				R57	when reggroup=x"5" and ADDR="111" else
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
	
	R34(7)<=rxfifoempn;
	rxfifoclr<=RxC;
	txfifoclr<=TxC;
	R36<=rxfifordat;
	
	process(clk,crstn,ce)
	variable rd,lrd	:std_logic;
	begin
	if rising_edge(clk) then
		if(crstn='0')then
			lrd:='0';
			rxfiford<='0';
		elsif(ce ='1')then
			rxfiford<='0';
			if(DATWR='1' and ADDR="110" and reggroup=x"3")then
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
	R54(2)<='0';
	R54(1)<='0';
	R54(0)<=txbusy;
	
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
				if(RxE='1')then
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
	process(rxdone,RxCL,RxPE,RxPL,RxEO,RxSL,RxST)
	variable	par	:std_logic;
	variable	par4	:std_logic_vector(3 downto 0);
	variable	parloc	:integer range 0 to 12;
	variable parlen	:integer range 0 to 4;
	begin
		if(rxdone='1')then
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
	
	rxfifowr<=rxdone and ((not rxstoperr) and (not rxparerr) and (not rxstop2err) and (not rxfifofull));
	
	process(clk,crstn,ce)begin
	if rising_edge(clk) then

		if(crstn='0')then
			R34(6 downto 1)<=(others=>'0');
		elsif(ce ='1')then
			if(rxfifofull='1' and rxdone='1')then
				R34(6)<='1';
			elsif(RxOVC='1')then
				R34(6)<='0';
			end if;
			if(rxstoperr='1' or rxstop2err='1')then
				R34(4)<='1';
			elsif(rxfifowr='1')then
				R34(4)<='0';
			end if;
			if(rxparerr='1')then
				R34(3)<='1';
			elsif(rxfifowr='1')then
				R34(3)<='0';
			end if;
		end if;
	end if;
	end process;
	R34(0)<=rxbusy;
	
	rxfifowdat<=rxbyte;

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
	
	
	txfiford<=txrd;
	--process(clk,crstn)
	process(txfifordat,TxPE,TxPL,TxEO,TxCL,TxSL)
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
			txdata(7 downto 0)<=txfifordat;
			vlen:=8;
		else
			txdata(6 downto 0)<=txfifordat(6 downto 0);
			vlen:=7;
		end if;
		if(TxPE='1')then
			if(TxPL='0')then
				par:=TxEO;
				for i in 0 to 7 loop
					if(TxCL='0' or i<7)then
						par:=par xor txfifordat(i);
					end if;
				end loop;
				txdata(vlen)<=par;
				vlen:=vlen+1;
			else
				par4:=(others=>TxEO);
				if(TxCL='0')then
					par4:=par4 xor txfifordat(3 downto 0) xor txfifordat(7 downto 4);
				else
					par4:=par4 xor txfifordat(3 downto 0) xor ('0' & txfifordat(6 downto 4));
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

	
	txen<=TXE and txfifoempn;
	
	txunit	:txframenb	generic map(13,3)	port map(
		SD			=>TxD,
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
					if(gcounter>0)then
						gcounter<=gcounter-1;
					elsif(GTLDVAL/=gczero)then
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
		elsif(ce ='1')then
			if(sreset='1')then
				intcc<='0';
				ccounter<=(others=>'0');
			else
				if(intclr(inum_cc)='1')then
					intcc<='0';
				end if;
				if(CCLD='1')then
					ccounter<=CCLDVAL;
				elsif(ccountsft='1')then
					if(ccounter>0)then
						ccounter<=ccounter-1;
					elsif(CCLDVAL/=cczero)then
						intcc<='1';
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
		elsif(ce ='1')then
			if(sreset='1')then
				mcounter<=(Others=>'0');
			else
				if(MTLD='1')then
					mcounter<=MTLDVAL;
				elsif(mcountsft='1')then
					if(mcounter>0)then
						mcounter<=mcounter-1;
					elsif(MTLDVAL/=mczero)then
						mcounter<=MTLDVAL;
					end if;
				end if;
			end if;
		end if;
	end if;
	end process;
	
	--interrupt session
	
	intol<='0';
	intrc<='0';
	intpc<='0';
	intmm<='0';
	
	intx<=intgt & inttx & intrx & intol & intrc & intpc & intcc & intmm;
	intm<=intx and intmask;
	R02<=intm;
	
	process(intm)
	variable num	:integer range 0 to 8;
	begin
		num:=8;
		for i in 7 downto 0 loop
			if(intm(i)='1')then
				num:=i;
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

	IVECT<=R00;
	
end rtl;