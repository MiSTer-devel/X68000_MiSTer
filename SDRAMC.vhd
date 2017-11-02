LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE IEEE.STD_LOGIC_ARITH.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY SDRAMC IS
generic(
	AWIDTH		:integer	:=25;
	CAWIDTH		:integer	:=10;
	LAWIDTH		:integer	:=8;
	CLKMHZ		:integer	:=120		--MHz
);
port(
	-- SDRAM PORTS
	PMEMCKE		:OUT	STD_LOGIC;							-- SD-RAM CLOCK ENABLE
	PMEMCS_N	:OUT	STD_LOGIC;							-- SD-RAM CHIP SELECT
	PMEMRAS_N	:OUT	STD_LOGIC;							-- SD-RAM ROW/RAS
	PMEMCAS_N	:OUT	STD_LOGIC;							-- SD-RAM /CAS
	PMEMWE_N	:OUT	STD_LOGIC;							-- SD-RAM /WE
	PMEMUDQ		:OUT	STD_LOGIC;							-- SD-RAM UDQM
	PMEMLDQ		:OUT	STD_LOGIC;							-- SD-RAM LDQM
	PMEMBA1		:OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 1
	PMEMBA0		:OUT	STD_LOGIC;							-- SD-RAM BANK SELECT ADDRESS 0
	PMEMADR		:OUT	STD_LOGIC_VECTOR( 12 DOWNTO 0 );	-- SD-RAM ADDRESS
	PMEMDAT		:INOUT	STD_LOGIC_VECTOR( 15 DOWNTO 0 );	-- SD-RAM DATA

	addr_high	:in std_logic_vector(AWIDTH-LAWIDTH-1 downto 0);
	bgnaddr		:in std_logic_vector(LAWIDTH-1 downto 0);
	endaddr		:in std_logic_vector(LAWIDTH-1 downto 0);
	addr_rc		:out std_logic_vector(LAWIDTH-1 downto 0);
	addr_wc		:out std_logic_vector(LAWIDTH-1 downto 0);
	rddat		:out std_logic_vector(15 downto 0);
	wrdat		:in std_logic_vector(15 downto 0);
	de			:out std_logic;
	we			:in std_logic_vector(1 downto 0);
	rd			:in std_logic;
	wr			:in std_logic;
	refrsh		:in std_logic;
	busy		:out std_logic;
	
	initdone	:out std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
);
end SDRAMC;

architecture rtl of SDRAMC is
type state_t is (
	ST_INITPALL,
	ST_INITREF,
	ST_INITMRS,
	ST_REFRESH,
	ST_READ,
	ST_WRITE,
	ST_IDLE
);
signal	STATE	:state_t;

constant RAWIDRG	:integer	:=AWIDTH-CAWIDTH;

--command: CKE & CSN & RAS_N & CAS_N & WE_N
constant cmd_CWAIT	:std_logic_vector(4 downto 0)	:="01111";
constant cmd_NOP	:std_logic_vector(4 downto 0)	:="11111";
constant cmd_BNKE	:std_logic_vector(4 downto 0)	:="10011";
constant cmd_READ	:std_logic_vector(4 downto 0)	:="10101";
constant cmd_WRITE	:std_logic_vector(4 downto 0)	:="10100";
constant cmd_PALL	:std_logic_vector(4 downto 0)	:="10010";
constant cmd_REFRSH	:std_logic_vector(4 downto 0)	:="10001";
constant cmd_MRS	:std_logic_vector(4 downto 0)	:="10000";

signal	COMMAND	:std_logic_vector(4 downto 0);
signal	DQE		:std_logic_vector(1 downto 0);
signal	BA		:std_logic_vector(1 downto 0);
signal	MADDR	:std_logic_vector(12 downto 0);

signal	clkstate	:integer range 0 to 11;
signal	csshift		:std_logic;
signal	curaddr		:std_logic_vector(7 downto 0);

constant INITR_TIMES	:integer	:=20;
signal	INITR_COUNT	:integer range 0 to INITR_TIMES;
constant INITTIMERCNT:integer	:=1000;
signal	INITTIMER	:integer range 0 to INITTIMERCNT;
--constant clockwtime	:integer	:=50000;	--usec
constant clockwtime	:integer	:=2;	--usec
constant cwaitcnt	:integer	:=clockwtime*CLKMHZ;	--clocks
signal	CLOCKWAIT	:integer range 0 to cwaitcnt;
signal	RADDR		:std_logic_vector(12 downto 0);
signal	CBADDR		:std_logic_vector(10 downto 0);
signal	CEADDR		:std_logic_vector(10 downto 0);
signal	CZADDR		:std_logic_vector(10 downto 0);
signal	BADDR		:std_logic_vector(1 downto 0);
signal	addr1		:std_logic_vector(LAWIDTH-1 downto 0);
signal	addr2		:std_logic_vector(LAWIDTH-1 downto 0);
signal	addr3		:std_logic_vector(LAWIDTH-1 downto 0);
signal	addr4		:std_logic_vector(LAWIDTH-1 downto 0);
constant lastlow	:std_logic_vector(LAWIDTH-1 downto 0)	:=(others=>'1');

begin
	
	addr1	<=conv_std_logic_vector(1,LAWIDTH);
	addr2	<=conv_std_logic_vector(2,LAWIDTH);
	addr3	<=conv_std_logic_vector(3,LAWIDTH);
	addr4	<=conv_std_logic_vector(4,LAWIDTH);
	
	busy<=	'1' when STATE/=ST_IDLE else
			'1' when rd='1' else
			'1' when wr='1' else
			'1' when refrsh='1' else
			'0';
	
	BADDR<=	addr_high(AWIDTH-LAWIDTH-1 downto AWIDTH-LAWIDTH-2);
	process(addr_high)begin
		RADDR<=(others=>'0');
		RADDR(AWIDTH-CAWIDTH-3 downto 0)<=	addr_high(AWIDTH-LAWIDTH-3 downto CAWIDTH-LAWIDTH);
		CZADDR<=(others=>'0');
		CZADDR(CAWIDTH-1 downto LAWIDTH)<=addr_high(CAWIDTH-LAWIDTH-1 downto 0);
	end process;
	process(addr_high,bgnaddr)begin
		CBADDR<=(others=>'0');
		CBADDR(CAWIDTH-1 downto LAWIDTH)<=addr_high(CAWIDTH-LAWIDTH-1 downto 0);
		CBADDR(LAWIDTH-1 downto 0)<=bgnaddr;
	end process;
	process(addr_high,endaddr)begin
		CEADDR<=(others=>'0');
		CEADDR(CAWIDTH-1 downto LAWIDTH)<=addr_high(CAWIDTH-LAWIDTH-1 downto 0);
		CEADDR(LAWIDTH-1 downto 0)<=endaddr;
	end process;
	
	
	process(clk,rstn)
	variable	st_next	:std_logic;
	begin
		if(rstn='0')then
			COMMAND<=cmd_NOP;
			DQE<="11";
			BA<="11";
			MADDR<=(others=>'0');
			clkstate<=0;
			csshift<='1';
			curaddr<=(others=>'0');
			STATE<=ST_INITPALL;
			INITR_COUNT	<=INITR_TIMES;
			INITTIMER	<=INITTIMERCNT;
			CLOCKWAIT	<=cwaitcnt;
			de<='0';
			initdone<='0';
			PMEMDAT <=(others=>'Z');
		elsif(clk' event and clk='1')then
			st_next:='0';
			if(INITTIMER>0)then
				if(INITTIMER=1)then
					COMMAND<=cmd_NOP;
					CLOCKWAIT<=cwaitcnt;
				else
					COMMAND<=cmd_CWAIT;
				end if;
				INITTIMER<=INITTIMER-1;
			elsif(CLOCKWAIT>0)then
				CLOCKWAIT<=CLOCKWAIT-1;
				clkstate<=0;
				STATE<=ST_INITPALL;
			else
				case STATE is
				when ST_INITPALL =>
					case clkstate is
					when 0 =>
						COMMAND<=cmd_PALL;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'1');
					when 3 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						st_next:='1';
					when others =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					end case;
				when ST_INITREF | ST_REFRESH =>
					case clkstate is
					when 0 =>
						COMMAND<=cmd_REFRSH;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					when 9 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						st_next:='1';
					when others =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					end case;
				when ST_INITMRS =>
					case clkstate is
					when 0 =>
						COMMAND<=cmd_MRS;
						DQE<="11";
						BA<="00";
						MADDR<="0000000110111";		--CAS3, full page burst
					when 2 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						st_next:='1';
					when others =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					end case;
				when ST_READ =>
					case clkstate is
					when 0 =>
						COMMAND<=cmd_BNKE;
						DQE<="11";
						BA<=BADDR;
						MADDR<=RADDR;
					when 3 =>
						COMMAND<=cmd_READ;
						DQE<="00";
						BA<=BADDR;
						MADDR<='0' & CBADDR(10) & '0' & CBADDR(9 downto 0);
						curaddr<=bgnaddr;
					when 4 =>
						if(curaddr=lastlow)then
							COMMAND<=cmd_READ;
							DQE<="00";
							BA<=BADDR;
							MADDR<='0' & CZADDR(10) & '0' & CZADDR(9 downto 0);
						else
							COMMAND<=cmd_NOP;
							DQE<="00";
							BA<="00";
							MADDR<=(others=>'0');
						end if;
					when 5 =>
						if((curaddr+addr1)=lastlow)then
							COMMAND<=cmd_READ;
							DQE<="00";
							BA<=BADDR;
							MADDR<='0' & CZADDR(10) & '0' & CZADDR(9 downto 0);
						else
							COMMAND<=cmd_NOP;
							DQE<="00";
							BA<="00";
							MADDR<=(others=>'0');
						end if;
					when 6 =>
						if((curaddr+addr2)=lastlow)then
							COMMAND<=cmd_READ;
							DQE<="00";
							BA<=BADDR;
							MADDR<='0' & CZADDR(10) & '0' & CZADDR(9 downto 0);
						else
							COMMAND<=cmd_NOP;
							DQE<="00";
							BA<="00";
							MADDR<=(others=>'0');
						end if;
						csshift<='0';
--						curaddr<=curaddr+addr1;
					when 7 =>
						if((curaddr+addr3)=lastlow)then
							COMMAND<=cmd_READ;
							DQE<="00";
							BA<=BADDR;
							MADDR<='0' & CZADDR(10) & '0' & CZADDR(9 downto 0);
						else
							COMMAND<=cmd_NOP;
							DQE<="00";
							BA<="00";
							MADDR<=(others=>'0');
						end if;
						curaddr<=curaddr+addr1;
						if((curaddr+addr4)=endaddr)then
							csshift<='1';
						end if;
						de<='1';
					when 8 =>
						COMMAND<=cmd_PALL;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'1');
						curaddr<=curaddr+addr1;
					when 10  =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						de<='0';
						MADDR<=(others=>'0');
						st_next:='1';
					when others =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					end case;
				when ST_WRITE =>
					case clkstate is
					when 0 =>
						COMMAND<=cmd_BNKE;
						DQE<="11";
						BA<=BADDR;
						MADDR<=RADDR;
						curaddr<=bgnaddr;
					when 1 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						de<='1';
					when 2 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						curaddr<=curaddr+addr1;
					when 3 =>
						COMMAND<=cmd_WRITE;
						DQE<=not we;
						BA<=BADDR;
						MADDR<='0' & CBADDR(10) & '0' & CBADDR(9 downto 0);
						curaddr<=curaddr+addr1;
						PMEMDAT<=wrdat;
						csshift<='0';
					when 4 =>
						COMMAND<=cmd_NOP;
						DQE<=not we;
						BA<=BADDR;
						MADDR<=(others=>'0');
						PMEMDAT<=wrdat;
						if(curaddr>=endaddr or curaddr<bgnaddr)then
							csshift<='1';
							de<='0';
						else
							curaddr<=curaddr+addr1;
						end if;
					when 5 =>
						PMEMDAT<=(others=>'Z');
						COMMAND<=cmd_PALL;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'1');
					when 7 =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
						st_next:='1';
					when others =>
						COMMAND<=cmd_NOP;
						DQE<="11";
						BA<="00";
						MADDR<=(others=>'0');
					end case;
				when others =>
					st_next:='1';
				end case;
				if(csshift='1')then
					clkstate<=clkstate+1;
				end if;
				if(st_next='1')then
					if(STATE=ST_INITPALL)then
						STATE<=ST_INITREF;
						INITR_COUNT<=INITR_TIMES;
					elsif(STATE=ST_INITREF)then
						if(INITR_COUNT>0)then
							INITR_COUNT<=INITR_COUNT-1;
						else
							STATE<=ST_INITMRS;
						end if;
					elsif(STATE=ST_INITMRS)then
						STATE<=ST_REFRESH;
						initdone<='1';
					elsif(rd='1')then
						STATE<=ST_READ;
						curaddr<=(others=>'0');
					elsif(wr='1')then
						STATE<=ST_WRITE;
					elsif(refrsh='1')then
						STATE<=ST_REFRESH;
					else
						STATE<=ST_IDLE;
					end if;
					clkstate<=0;
				end if;
			end if;
		end if;
	end process;
	
	PMEMCKE	<=COMMAND(4);
	PMEMCS_N	<=COMMAND(3);
	PMEMRAS_N<=COMMAND(2);
	PMEMCAS_N<=COMMAND(1);
	PMEMWE_N	<=COMMAND(0);
	PMEMUDQ	<=DQE(1);
	PMEMLDQ	<=DQE(0);
	PMEMBA1	<=BA(1);
	PMEMBA0	<=BA(0);
	PMEMADR	<=MADDR;

	process(clk)begin
		if(clk' event and clk='1')then
			rddat<=PMEMDAT;
		end if;
	end process;
	
	addr_wc<=curaddr;
	process(clk)
	variable addr_dly	:std_logic_vector(7 downto 0);
	begin
		if(clk' event and clk='1')then
--			addr_rc<=addr_dly;
--			addr_dly:=curaddr;
			addr_rc<=curaddr;
		end if;
	end process;
end rtl;			
					
						
						
			
			