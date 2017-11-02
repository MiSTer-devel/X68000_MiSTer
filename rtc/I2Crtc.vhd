LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	use IEEE.std_logic_arith.all;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity I2Crtc is
port(
	TXOUT		:out	std_logic_vector(7 downto 0);		--tx data in
	RXIN		:in		std_logic_vector(7 downto 0);	--rx data out
	WRn			:out	std_logic;						--write
	RDn			:out	std_logic;						--read

	TXEMP		:in		std_logic;							--tx buffer empty
	RXED		:in		std_logic;							--rx buffered
	NOACK		:in		std_logic;							--no ack
	COLL		:in		std_logic;							--collision detect
	NX_READ		:out	std_logic;							--next data is read
	RESTART		:out	std_logic;							--make re-start condition
	START		:out	std_logic;							--make start condition
	FINISH		:out	std_logic;							--next data is final(make stop condition)
	F_FINISH	:out	std_logic;							--next data is final(make stop condition)
	INIT		:out	std_logic;

	YEHID		:out std_logic_vector(3 downto 0);
	YELID		:out std_logic_vector(3 downto 0);
	MONID		:out std_logic_vector(3 downto 0);
	DAYHID		:out std_logic_vector(1 downto 0);
	DAYLID		:out std_logic_vector(3 downto 0);
	WDAYID		:out std_logic_vector(2 downto 0);
	HORHID		:out std_logic_vector(1 downto 0);
	HORLID		:out std_logic_vector(3 downto 0);
	MINHID		:out std_logic_vector(2 downto 0);
	MINLID		:out std_logic_vector(3 downto 0);
	SECHID		:out std_logic_vector(2 downto 0);
	SECLID		:out std_logic_vector(3 downto 0);
	RTCINI		:out std_logic;
	
	YEHWD		:in std_logic_vector(3 downto 0);
	YELWD		:in std_logic_vector(3 downto 0);
	MONWD		:in std_logic_vector(3 downto 0);
	DAYHWD		:in std_logic_vector(1 downto 0);
	DAYLWD		:in std_logic_vector(3 downto 0);
	WDAYWD		:in std_logic_vector(2 downto 0);
	HORHWD		:in std_logic_vector(1 downto 0);
	HORLWD		:in std_logic_vector(3 downto 0);
	MINHWD		:in std_logic_vector(2 downto 0);
	MINLWD		:in std_logic_vector(3 downto 0);
	SECHWD		:in std_logic_vector(2 downto 0);
	SECLWD		:in std_logic_vector(3 downto 0);
	RTCWR		:in std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end I2Crtc;

architecture rtl of I2Crtc is
type I2Cstate_t is(
	IS_IDLE,
	IS_INIBGN,
	IS_INIRTCSADRW,
	IS_INIRTCWADR,
	IS_INIRTCRCNT1,
	IS_INIRTCRCNT2,
	IS_INIRTCRSEC,
	IS_INIRTCRMIN,
	IS_INIRTCRHR,
	IS_INIRTCRDAY,
	IS_INIRTCRWEK,
	IS_INIRTCRMON,
	IS_INIRTCRYER,
	IS_INIRTCEND,
	IS_WRRTCBGN,
	IS_WRRTCSADR,
	IS_WRRTCWADR,
	IS_WRRTCCNT1,
	IS_WRRTCCNT2,
	IS_WRRTCSEC,
	IS_WRRTCMIN,
	IS_WRRTCHR,
	IS_WRRTCDAY,
	IS_WRRTCWEK,
	IS_WRRTCMON,
	IS_WRRTCYER
);
signal	I2Cstate :I2Cstate_t;

constant	SADR_RTC	:std_logic_vector(6 downto 0)	:="1010001";

begin
	process(clk,rstn)
	begin
		if(rstn='0')then
			I2Cstate<=IS_INIBGN;
			WRn<='1';
			RDn<='1';
			NX_READ<='0';
			RESTART<='0';
			START<='0';
			FINISH<='0';
			F_FINISH<='0';
			INIT<='0';
		elsif(clk' event and clk='1')then
			WRn<='1';
			RDn<='1';
			F_FINISH<='0';
			INIT<='0';
			case I2Cstate is
			when IS_INIBGN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='1';
					FINISH<='0';
					TXOUT<=SADR_RTC & '0';
					WRn<='0';
					I2CSTATE<=IS_INIRTCSADRW;
				end if;
			when IS_INIRTCSADRW =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"00";
					WRn<='0';
					I2CSTATE<=IS_INIRTCWADR;
				end if;
			when IS_INIRTCWADR =>
				if(TXEMP='1')then
					NX_READ<='1';
					RESTART<='1';
					START<='0';
					FINISH<='0';
					TXOUT<=SADR_RTC & '1';
					WRn<='0';
					I2CSTATE<=IS_INIRTCRCNT1;
				end if;
			when IS_INIRTCRCNT1 =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRCNT2;
				end if;
			when IS_INIRTCRCNT2 =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRSEC;
				end if;
			when IS_INIRTCRSEC =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRMIN;
				end if;
			when IS_INIRTCRMIN =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRHR;
				end if;
			when IS_INIRTCRHR =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRDAY;
				end if;
			when IS_INIRTCRDAY =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRWEK;
				end if;
			when IS_INIRTCRWEK =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRMON;
				end if;
			when IS_INIRTCRMON =>
				if(RXED='1')then
					NX_READ<='1';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					RDn<='0';
					I2CSTATE<=IS_INIRTCRYER;
				end if;
			when IS_INIRTCRYER =>
				if(RXED='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='1';
					RDn<='0';
					I2CSTATE<=IS_INIRTCEND;
				end if;
			when IS_INIRTCEND =>
				NX_READ<='0';
				RESTART<='0';
				START<='0';
				FINISH<='0';
				RDn<='0';
				I2CSTATE<=IS_IDLE;
			when IS_IDLE=>
				if(RTCWR='1')then
					I2CSTATE<=IS_WRRTCBGN;
				end if;
			when IS_WRRTCBGN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='1';
					FINISH<='0';
					TXOUT<=SADR_RTC & '0';
					WRn<='0';
					I2CSTATE<=IS_WRRTCSADR;
				end if;
			when IS_WRRTCSADR =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"00";
					WRn<='0';
					I2CSTATE<=IS_WRRTCWADR;
				end if;
			when IS_WRRTCWADR =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"00";
					WRn<='0';
					I2CSTATE<=IS_WRRTCCNT1;
				end if;
			when IS_WRRTCCNT1 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"00";
					WRn<='0';
					I2CSTATE<=IS_WRRTCCNT2;
				end if;
			when IS_WRRTCCNT2 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<='0' & SECHWD & SECLWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCSEC;
				end if;
			when IS_WRRTCSEC =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<='0' & MINHWD & MINLWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCMIN;
				end if;
			when IS_WRRTCMIN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<="00" & HORHWD & HORLWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCHR;
				end if;
			when IS_WRRTCHR =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<="00" & DAYHWD & DAYLWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCDAY;
				end if;
			when IS_WRRTCDAY =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<="00000" & WDAYWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCWEK;
				end if;
			when IS_WRRTCWEK =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					if(MONWD>x"9")then
						TXOUT<="0000" & MONWD;
					else
						TXOUT<="0001" & (MONWD-x"a");
					end if;
					WRn<='0';
					I2CSTATE<=IS_WRRTCMON;
				end if;
			when IS_WRRTCMON =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='1';
					TXOUT<=YEHWD & YELWD;
					WRn<='0';
					I2CSTATE<=IS_WRRTCYER;
				end if;
			when IS_WRRTCYER =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					I2CSTATE<=IS_IDLE;
				end if;
			when others =>
			end case;
		end if;
	end process;
			
	process(clk,rstn)begin
		if(rstn='0')then
			YEHID<=(others=>'0');
			YELID<=(others=>'0');
			MONID<=(others=>'0');
			DAYHID<=(others=>'0');
			DAYLID<=(others=>'0');
			WDAYID<=(others=>'0');
			HORHID<=(others=>'0');
			HORLID<=(others=>'0');
			MINHID<=(others=>'0');
			MINLID<=(others=>'0');
			SECHID<=(others=>'0');
			SECLID<=(others=>'0');
			RTCINI<='0';
		elsif(clk' event and clk='1')then
			RTCINI<='0';
			if(RXED='1')then
				case I2CSTATE is
				when IS_INIRTCRSEC =>
					SECLID<=RXIN(3 downto 0);
					SECHID<=RXIN(6 downto 4);
				when IS_INIRTCRMIN =>
					MINLID<=RXIN(3 downto 0);
					MINHID<=RXIN(6 downto 4);
				when IS_INIRTCRHR =>
					HORLID<=RXIN(3 downto 0);
					HORHID<=RXIN(5 downto 4);
				when IS_INIRTCRDAY =>
					DAYLID<=RXIN(3 downto 0);
					DAYHID<=RXIN(5 downto 4);
				when IS_INIRTCRWEK =>
					WDAYID<=RXIN(2 downto 0);
				when IS_INIRTCRMON =>
					if(RXIN(4)='0')then
						MONID<=RXIN(3 downto 0);
					else
						MONID<=x"a"+RXIN(3 downto 0);
					end if;
				when IS_INIRTCRYER =>
					YELID<=RXIN(3 downto 0);
					YEHID<=RXIN(7 downto 4);
					RTCINI<='1';
				when others =>
				end case;
			end if;
		end if;
	end process;
end rtl;

