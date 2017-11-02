library ieee,work;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.I2C_pkg.all;

entity I2CIF is
port(
	DATIN	:in	std_logic_vector(I2CDAT_WIDTH-1 downto 0);		--tx data in
	DATOUT	:out	std_logic_vector(I2CDAT_WIDTH-1 downto 0);	--rx data out
	WRn		:in		std_logic;						--write
	RDn		:in		std_logic;						--read

	TXEMP	:out std_logic;							--tx buffer empty
	RXED	:out std_logic;							--rx buffered
	NOACK	:out std_logic;							--no ack
	COLL	:out std_logic;							--collision detect
	NX_READ	:in std_logic;							--next data is read
	RESTART	:in std_logic;							--make re-start condition
	START	:in std_logic;							--make start condition
	FINISH	:in std_logic;							--next data is final(make stop condition)
	F_FINISH :in std_logic;							--next data is final(make stop condition)
	INIT	:in std_logic;
	
--	INTn :out	std_logic;

	SDAIN :in	std_logic;
	SDAOUT :out	std_logic;
	SCLIN :in	std_logic;
	SCLOUT :out	std_logic;

	SFT	:in		std_logic;
	clk	:in		std_logic;
	rstn :in	std_logic
);
end I2CIF;

architecture MAIN of I2CIF is
signal	TXBUF	:std_logic_vector(I2CDAT_WIDTH downto 0);
signal	TXCNT	:integer range 0 to I2CDAT_WIDTH+1;
signal	CLKST	:integer range 0 to 3;
signal	LASTWRn	:std_logic;
signal	LASTSDA	:std_logic;
signal	BUSBUSY	:std_logic;
signal	RXFULL	:std_logic;
signal	TXBIT	:std_logic;
signal	STATE	:integer range 0 to 6;
 constant	ST_IDLE		:integer	:=0;
 constant	ST_WAITBUS	:integer	:=1;
 constant	ST_TXBUF	:integer	:=2;
 constant	ST_RXDAT	:integer	:=3;
 constant	ST_RDWAIT	:integer	:=4;
 constant	ST_START	:integer	:=5;
 constant	ST_STOP		:integer	:=6;
signal	INITTING	:std_logic;
signal	INITCOUNT	:integer range 0 to 10;
signal	TXEMPbuf	:std_logic;

begin
	DATOUT<=TXBUF(I2CDAT_WIDTH downto 1);

--	SCLOUT<= '0' when (CLKST=1 or CLKST=2) else '1';
	TXEMP<=TXEMPbuf and WRn;
	
	RXED<=RXFULL and RDn;
	
	process(clk,rstn)begin
		if(rstn='0')then
			TXBUF<=(others=>'0');
			TXCNT<=0;
			STATE<=ST_IDLE;
			CLKST<=0;SCLOUT<='0';
			TXEMPbuf<='1';
			RXFULL<='0';
			NOACK<='0';
			BUSBUSY<='0';
			SDAOUT<='0';
			TXBIT<='1';
			COLL<='0';
			LASTSDA<='1';
			INITTING<='1';
			INITCOUNT<=10;
		elsif(clk' event and clk='1')then
			LASTSDA<=SDAIN;
			if(INIT='1')then
				INITTING<='1';
				INITCOUNT<=9;
				CLKST<=3;SCLOUT<='1';
			end if;
			if(WRn='0')then --WRn fall edge
				if(STATE=ST_IDLE)then
					TXBUF(I2CDAT_WIDTH downto 1)<=DATIN;
					TXBUF(0)<='1';	-- for ack receive(Hi-Z)
					STATE<=ST_WAITBUS;
					TXEMPbuf<='0';
					COLL<='0';
				end if;
			elsif(F_FINISH='1' and STATE=ST_IDLE)then	--force stop condition
				TXEMPbuf<='0';
				STATE<=ST_STOP;
			end if;
			if(RDn='0')then
				RXFULL<='0';
				NOACK<='0';
			end if;
			if(INITTING='0' and (STATE=ST_IDLE or STATE=ST_WAITBUS))then
				if(LASTSDA='1' and SDAIN='0')then
					BUSBUSY<='1';
				elsif(LASTSDA='0' and SDAIN='1' and SCLIN='1')then	--modifyied 081029
					BUSBUSY<='0';
				end if;
			end if;
			if(SFT='1')then
				if(INITTING='1' or (STATE/=ST_IDLE and STATE/=ST_WAITBUS and STATE/=ST_RDWAIT))then
					if(CLKST=0)then
						CLKST<=1;SCLOUT<='0';
					elsif(CLKST=1)then
						CLKST<=2;SCLOUT<='0';
					elsif(CLKST=2)then
						CLKST<=3;SCLOUT<='1';
					elsif(CLKST=3)then
						if(SCLIN='1')then
							CLKST<=0;SCLOUT<='1';
						end if;
					end if;
				end if;
				if(INITTING='0')then
					if(STATE=ST_WAITBUS)then
						if(BUSBUSY='0')then
							STATE<=ST_TXBUF;
							CLKST<=0;SCLOUT<='1';
							if(RESTART='1')then
								STATE<=ST_START;	--start condition
							elsif(START='1')then
								STATE<=ST_START;
								CLKST<=3;SCLOUT<='1';
							end if;
							TXCNT<=I2CDAT_WIDTH+1;
						end if;
					end if;
					if(STATE=ST_TXBUF)then
						if(CLKST=1)then
							TXCNT<=TXCNT-1;
							if(TXBUF(I2CDAT_WIDTH)='1')then
								SDAOUT<='1';
								TXBIT<='1';
							else
								SDAOUT<='0';
								TXBIT<='0';
							end if;
							TXBUF(I2CDAT_WIDTH downto 1)<=TXBUF(I2CDAT_WIDTH-1 downto 0);
							TXBUF(0)<='0';
						elsif(CLKST=3 and TXCNT=0 and SCLIN='1')then
							if(SDAIN='0')then
								NOACK<='0';
								if(NX_READ='1')then
									TXCNT<=I2CDAT_WIDTH+1;
									STATE<=ST_RXDAT;
								elsif(FINISH='1')then
									STATE<=ST_STOP;
								else
									TXEMPbuf<='1';
									STATE<=ST_IDLE;
								end if;
							else
								NOACK<='1';
								STATE<=ST_STOP;
							end if;
						elsif(CLKST=2 and TXCNT/=0 and TXBIT='1' and SDAIN='0')then	--collision detected
							COLL<='1';
							BUSBUSY<='1';
							TXEMPbuf<='1';
							STATE<=ST_IDLE;
							CLKST<=3;SCLOUT<='1';
						end if;
					elsif(STATE=ST_RXDAT)then
						if(CLKST=3 and SCLIN='1')then
							TXCNT<=TXCNT-1;
							TXBUF(I2CDAT_WIDTH downto 1)<=TXBUF(I2CDAT_WIDTH-1 downto 0);
							TXBUF(0)<=SDAIN;
							if(TXCNT=1)then
								RXFULL<='1';
								STATE<=ST_RDWAIT;
							end if;
						elsif(CLKST=1)then
							if(TXCNT=1)then
								SDAOUT<='0';	--ack
								TXBIT<='0';
							else
								SDAOUT<='1';
								TXBIT<='1';
							end if;
						end if;
					elsif(STATE=ST_RDWAIT)then
						if(RXFULL='0')then
							if(FINISH='1')then
								SDAOUT<='1';
								TXBIT<='1';
								TXEMPbuf<='1';
								STATE<=ST_IDLE;
	--							STATE<=ST_STOP;
							elsif(NX_READ='1')then
								TXCNT<=I2CDAT_WIDTH+1;
								STATE<=ST_RXDAT;
							else
								SDAOUT<='1';
								TXBIT<='1';
								TXEMPbuf<='1';
								STATE<=ST_IDLE;
--								STATE<=ST_STOP;
							end if;
						end if;
					elsif(STATE=ST_START)then
						if(CLKST=1)then
							SDAOUT<='1';
							TXBIT<='1';
						elsif(CLKST=3)then
							SDAOUT<='0';
							TXBIT<='0';
							STATE<=ST_TXBUF;
						end if;
					elsif(STATE=ST_STOP)then
						if(CLKST=3)then
							SDAOUT<='1';
							TXBIT<='1';
							TXEMPbuf<='1';
							STATE<=ST_IDLE;
						elsif(CLKST=1)then
							SDAOUT<='0';
							TXBIT<='0';
						end if;
					end if;
				else	--init
					if(CLKST=1)then
						SDAOUT<='1';
						TXBIT<='1';
					elsif(CLKST=3)then
						if(INITCOUNT=0)then
							INITTING<='0';
							SDAOUT<='1';
							TXBIT<='1';
							if(STATE/=ST_WAITBUS)then
								STATE<=ST_IDLE;
							end if;
						else
							INITCOUNT<=INITCOUNT-1;
							SDAOUT<='0';
							TXBIT<='0';
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
end MAIN;
					
			