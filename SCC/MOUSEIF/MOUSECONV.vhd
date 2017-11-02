LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MOUSECONV is
generic(
	CLKCYC	:integer	:=20000;
	SFTCYC	:integer	:=400
);
port(
	REQ		:in std_logic;
	DATOUT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;

	MCLKIN	:in std_logic;
	MCLKOUT:out std_logic;
	MDATIN	:in std_logic;
	MDATOUT:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end MOUSECONV;

architecture MAIN of MOUSECONV is

component PS2IF
generic(
	SFTCYC	:integer	:=400;		--kHz
	STCLK	:integer	:=150;		--usec
	TOUT	:integer	:=150		--usec
);
port(
	DATIN	:in std_logic_vector(7 downto 0);
	DATOUT	:out std_logic_vector(7 downto 0);
	WRn		:in std_logic;
	BUSY	:out std_logic;
	RXED	:out std_logic;
	RESET	:in std_logic;
	COL		:out std_logic;
	PERR	:out std_logic;
	TWAIT	:in std_logic;
	
	KBCLKIN	:in	std_logic;
	KBCLKOUT :out std_logic;
	KBDATIN	:in std_logic;
	KBDATOUT :out std_logic;
	
	SFT		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component SFTCLK
generic(
	SYS_CLK	:integer	:=20000;
	OUT_CLK	:integer	:=1600;
	selWIDTH :integer	:=2
);
port(
	sel		:in std_logic_vector(selWIDTH-1 downto 0);
	SFT		:out std_logic;

	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

signal	SFT		:std_logic;

type STATE_T is (
	ST_IDLE,
	ST_INIT,
	ST_RESET,
	ST_RESET_BAT,
	ST_IDRD,
	ST_SETDEF,
	ST_SETDEF_ACK,
	ST_SETREMOTE,
	ST_SETREMOTE_ACK,
	ST_REQDATA,
	ST_REQDATA_ACK,
	ST_RECVDAT1,
	ST_RECVDAT2,
	ST_RECVDAT3
);

signal	STATE	:STATE_T;
signal	M_TXDAT	:std_logic_vector(7 downto 0);
signal	M_RXDAT	:std_logic_vector(7 downto 0);
signal	M_WRn		:std_logic;
signal	M_BUSY		:std_logic;
signal	M_RXED		:std_logic;
signal	M_RESET	:std_logic;
signal	M_COL		:std_logic;
signal	M_PERR		:std_logic;
signal	MWAIT		:std_logic;
signal	WAITCNT		:integer range 0 to 5;
constant waitcont	:integer	:=1;
constant waitsep	:integer	:=20;
constant waitccount	:integer	:=waitcont*SFTCYC;
constant waitscount	:integer	:=waitsep*SFTCYC;
signal	WAITSFT		:integer range 0 to waitscount;

signal	RXDONE		:std_logic;
signal	RXRDY		:std_logic;

signal	TXEMPb		:std_logic;
signal	msbX		:std_logic;
signal	msbY		:std_logic;
	
begin
	
	MSFT	:sftclk generic map(CLKCYC,SFTCYC,1) port map("1",SFT,clk,rstn);
	
	MOUSE	:PS2IF port map(
	DATIN	=>M_TXDAT,
	DATOUT	=>M_RXDAT,
	WRn		=>M_WRn,
	BUSY	=>M_BUSY,
	RXED	=>M_RXED,
	RESET	=>M_RESET,
	COL		=>M_COL,
	PERR	=>M_PERR,
	TWAIT	=>'0',
	
	KBCLKIN	=>MCLKIN,
	KBCLKOUT=>MCLKOUT,
	KBDATIN	=>MDATIN,
	KBDATOUT=>MDATOUT,
	
	SFT		=>SFT,
	clk		=>clk,
	rstn	=>rstn
	);

	process(clk,rstn)
	begin
		if(rstn='0')then
			STATE<=ST_INIT;
			M_WRn<='1';
			M_RESET<='0';
			WAITCNT<=0;
			WAITSFT<=0;
			M_TXDAT<=(others=>'0');
			RXED<='0';
			TXEMPb<='0';
		elsif(clk' event and clk='1')then
			M_WRn<='1';
			RXED<='0';
			if(WAITCNT>0)then
				WAITCNT<=WAITCNT-1;
			elsif(WAITSFT>0)then
				if(SFT='1')then
					WAITSFT<=WAITSFT-1;
				end if;
			else
				case STATE is
				when ST_INIT =>
					if(M_BUSY='0')then
						WAITSFT<=waitscount;
						STATE<=ST_RESET;
					end if;
				when ST_RESET =>
					if(M_BUSY='0')then
						M_TXDAT<=x"ff";
						M_WRn<='0';
						STATE<=ST_RESET_BAT;
					end if;
				when ST_RESET_BAT =>
					if(M_RXED='1' and M_RXDAT=x"aa")then
						STATE<=ST_IDRD;
					end if;
				when ST_IDRD =>
					if(M_RXED='1')then
						WAITSFT<=waitscount;
						STATE<=ST_SETDEF;
					end if;
				when ST_SETDEF =>
					if(M_BUSY='0')then
						M_TXDAT<=x"f6";
						M_WRn<='0';
						STATE<=ST_SETDEF_ACK;
					end if;
				when ST_SETDEF_ACK =>
					if(M_RXED='1' and M_RXDAT=x"fa")then
						WAITSFT<=waitscount;
						STATE<=ST_SETREMOTE;
					end if;
				when ST_SETREMOTE =>
					if(M_BUSY='0')then
						M_TXDAT<=x"f0";
						M_WRn<='0';
						STATE<=ST_SETREMOTE_ACK;
					end if;
				when ST_SETREMOTE_ACK =>
					if(M_RXED='1' and M_RXDAT=x"fa")then
						WAITSFT<=waitscount;
						STATE<=ST_IDLE;
					end if;
				when ST_IDLE =>
					if(REQ='1')then
						STATE<=ST_REQDATA;
					end if;
				when ST_REQDATA =>
					if(M_BUSY='0')then
						M_TXDAT<=x"eb";
						M_WRn<='0';
						STATE<=ST_REQDATA_ACK;
					end if;
				when ST_REQDATA_ACK =>
					if(M_RXED='1' and M_RXDAT=x"fa")then
						STATE<=ST_RECVDAT1;
					end if;
				when ST_RECVDAT1 =>
					if(M_RXED='1')then
						DATOUT(3 downto 0)<="00" & M_RXDAT(1 downto 0);
						DATOUT(7)<=M_RXDAT(7) and (not M_RXDAT(5));
						DATOUT(6)<=M_RXDAT(7) and M_RXDAT(5);
						DATOUT(5)<=M_RXDAT(6) and M_RXDAT(4);
						DATOUT(4)<=M_RXDAT(6) and (not M_RXDAT(4));
						msbY<=M_RXDAT(5);
						msbX<=M_RXDAT(4);
						RXED<='1';
						STATE<=ST_RECVDAT2;
					end if;
				when ST_RECVDAT2 =>
					if(M_RXED='1')then
						DATOUT<=msbX & M_RXDAT(7 downto 1);
						RXED<='1';
						STATE<=ST_RECVDAT3;
					end if;
				when ST_RECVDAT3 =>
					if(M_RXED='1')then
						DATOUT<=(not (msbY & M_RXDAT(7 downto 1)))+x"01";
						RXED<='1';
						STATE<=ST_IDLE;
					end if;
				when others =>
					STATE<=ST_IDLE;
				end case;
			end if;
		end if;
	end process;
end MAIN;
