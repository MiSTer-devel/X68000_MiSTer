LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity rp5c15 is
generic(
	clkfreq	:integer	:=21477270
);
port(
	addr	:in std_logic_vector(3 downto 0);
	wdat	:in std_logic_vector(3 downto 0);
	rdat	:out std_logic_vector(3 downto 0);
	wr		:in std_logic;
	
	clkout	:out std_logic;
	alarm	:out std_logic;
	
--I2C I/F
	TXOUT		:out	std_logic_vector(7 downto 0);		--tx data in
	RXIN		:in		std_logic_vector(7 downto 0);		--rx data out
	WRn			:out	std_logic;							--write
	RDn			:out	std_logic;							--read

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

	clk		:in std_logic;
	rstn	:in std_logic
);
end rp5c15;
architecture rtl of rp5c15 is
signal	YEH		:std_logic_vector(3 downto 0);
signal	YEL		:std_logic_vector(3 downto 0);
signal	MON		:std_logic_vector(3 downto 0);
signal	DAYH	:std_logic_vector(1 downto 0);
signal	DAYL	:std_logic_vector(3 downto 0);
signal	WDAY	:std_logic_vector(2 downto 0);
signal	HORH	:std_logic_vector(1 downto 0);
signal	HORL	:std_logic_vector(3 downto 0);
signal	MINH	:std_logic_vector(2 downto 0);
signal	MINL	:std_logic_vector(3 downto 0);
signal	SECH	:std_logic_vector(2 downto 0);
signal	SECL	:std_logic_vector(3 downto 0);

signal	YEHWD	:std_logic_vector(3 downto 0);
signal	YELWD	:std_logic_vector(3 downto 0);
signal	MONWD	:std_logic_vector(3 downto 0);
signal	DAYHWD	:std_logic_vector(1 downto 0);
signal	DAYLWD	:std_logic_vector(3 downto 0);
signal	WDAYWD	:std_logic_vector(2 downto 0);
signal	HORHWD	:std_logic_vector(1 downto 0);
signal	HORLWD	:std_logic_vector(3 downto 0);
signal	MINHWD	:std_logic_vector(2 downto 0);
signal	MINLWD	:std_logic_vector(3 downto 0);
signal	SECHWD	:std_logic_vector(2 downto 0);
signal	SECLWD	:std_logic_vector(3 downto 0);

signal	YEHWR	:std_logic;
signal	YELWR	:std_logic;
signal	MONWR	:std_logic;
signal	DAYHWR	:std_logic;
signal	DAYLWR	:std_logic;
signal	WDAYWR	:std_logic;
signal	HORHWR	:std_logic;
signal	HORLWR	:std_logic;
signal	MINHWR	:std_logic;
signal	MINLWR	:std_logic;
signal	SECHWR	:std_logic;
signal	SECLWR	:std_logic;
signal	SECZWR	:std_logic;

signal	YEHID	:std_logic_vector(3 downto 0);
signal	YELID	:std_logic_vector(3 downto 0);
signal	MONID	:std_logic_vector(3 downto 0);
signal	DAYHID	:std_logic_vector(1 downto 0);
signal	DAYLID	:std_logic_vector(3 downto 0);
signal	WDAYID	:std_logic_vector(2 downto 0);
signal	HORHID	:std_logic_vector(1 downto 0);
signal	HORLID	:std_logic_vector(3 downto 0);
signal	MINHID	:std_logic_vector(2 downto 0);
signal	MINLID	:std_logic_vector(3 downto 0);
signal	SECHID	:std_logic_vector(2 downto 0);
signal	SECLID	:std_logic_vector(3 downto 0);
signal	I2CSET	:std_logic;

signal	BNKSEL	:std_logic;
signal	I2CWR	:std_logic;
signal	MONHt	:std_logic;
signal	MONLt	:std_logic_vector(3 downto 0);
signal	monwdat	:std_logic_vector(3 downto 0);
signal	i2cwcount	:integer range 0 to clkfreq/10;
signal	wror	:std_logic;

component rtcbody
generic(
	clkfreq	:integer	:=21477270
);
port(
	YERHIN	:in std_logic_vector(3 downto 0);
	YERHWR	:in std_logic;
	YERLIN	:in std_logic_vector(3 downto 0);
	YERLWR	:in std_logic;
	MONIN	:in std_logic_vector(3 downto 0);
	MONWR	:in std_logic;
	DAYHIN	:in std_logic_vector(1 downto 0);
	DAYHWR	:in std_logic;
	DAYLIN	:in std_logic_vector(3 downto 0);
	DAYLWR	:in std_logic;
	WDAYIN	:in std_logic_vector(2 downto 0);
	WDAYWR	:in std_logic;
	HORHIN	:in std_logic_vector(1 downto 0);
	HORHWR	:in std_logic;
	HORLIN	:in std_logic_vector(3 downto 0);
	HORLWR	:in std_logic;
	MINHIN	:in std_logic_vector(2 downto 0);
	MINHWR	:in std_logic;
	MINLIN	:in std_logic_vector(3 downto 0);
	MINLWR	:in std_logic;
	SECHIN	:in std_logic_vector(2 downto 0);
	SECHWR	:in std_logic;
	SECLIN	:in std_logic_vector(3 downto 0);
	SECLWR	:in std_logic;
	SECZERO	:in std_logic;
	
	YERHOUT	:out std_logic_vector(3 downto 0);
	YERLOUT	:out std_logic_vector(3 downto 0);
	MONOUT	:out std_logic_vector(3 downto 0);
	DAYHOUT	:out std_logic_vector(1 downto 0);
	DAYLOUT	:out std_logic_vector(3 downto 0);
	WDAYOUT	:out std_logic_vector(2 downto 0);
	HORHOUT	:out std_logic_vector(1 downto 0);
	HORLOUT	:out std_logic_vector(3 downto 0);
	MINHOUT	:out std_logic_vector(2 downto 0);
	MINLOUT	:out std_logic_vector(3 downto 0);
	SECHOUT	:out std_logic_vector(2 downto 0);
	SECLOUT	:out std_logic_vector(3 downto 0);

	OUT1Hz	:out std_logic;
	
	fast	:in std_logic;

 	sclk	:in std_logic;
	rstn	:in std_logic
);
end component;

component I2Crtc is
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
end component;

begin
	rtc	:rtcbody generic map(clkfreq) port map(
		YERHIN	=>YEHWD,
		YERHWR	=>YEHWR,
		YERLIN	=>YELWD,
		YERLWR	=>YELWR,
		MONIN	=>MONWD,
		MONWR	=>MONWR,
		DAYHIN	=>DAYHWD,
		DAYHWR	=>DAYHWR,
		DAYLIN	=>DAYLWD,
		DAYLWR	=>DAYLWR,
		WDAYIN	=>WDAYWD,
		WDAYWR	=>WDAYWR,
		HORHIN	=>HORHWD,
		HORHWR	=>HORHWR,
		HORLIN	=>HORLWD,
		HORLWR	=>HORLWR,
		MINHIN	=>MINHWD,
		MINHWR	=>MINHWR,
		MINLIN	=>MINLWD,
		MINLWR	=>MINLWR,
		SECHIN	=>SECHWD,
		SECHWR	=>SECHWR,
		SECLIN	=>SECLWD,
		SECLWR	=>SECLWR,
		SECZERO	=>SECZWR,
		
		YERHOUT	=>YEH,
		YERLOUT	=>YEL,
		MONOUT	=>MON,
		DAYHOUT	=>DAYH,
		DAYLOUT	=>DAYL,
		WDAYOUT	=>WDAY,
		HORHOUT	=>HORH,
		HORLOUT	=>HORL,
		MINHOUT	=>MINH,
		MINLOUT	=>MINL,
		SECHOUT	=>SECH,
		SECLOUT	=>SECL,

		OUT1Hz	=>open,
		
		fast	=>'0',

		sclk	=>clk,
		rstn	=>rstn
	);
	
	i2c	:I2Crtc port map(
		TXOUT		=>TXOUT,
		RXIN		=>RXIN,
		WRn			=>WRn,
		RDn			=>RDn,

		TXEMP		=>TXEMP,
		RXED		=>RXED,
		NOACK		=>NOACK,
		COLL		=>COLL,
		NX_READ		=>NX_READ,
		RESTART		=>RESTART,
		START		=>START,
		FINISH		=>FINISH,
		F_FINISH	=>F_FINISH,
		INIT		=>INIT,

		YEHID		=>YEHID,
		YELID		=>YELID,
		MONID		=>MONID,
		DAYHID		=>DAYHID,
		DAYLID		=>DAYLID,
		WDAYID		=>WDAYID,
		HORHID		=>HORHID,
		HORLID		=>HORLID,
		MINHID		=>MINHID,
		MINLID		=>MINLID,
		SECHID		=>SECHID,
		SECLID		=>SECLID,
		RTCINI		=>I2CSET,
		
		YEHWD		=>YEH,
		YELWD		=>YEL,
		MONWD		=>MON,
		DAYHWD		=>DAYH,
		DAYLWD		=>DAYL,
		WDAYWD		=>WDAY,
		HORHWD		=>HORH,
		HORLWD		=>HORL,
		MINHWD		=>MINH,
		MINLWD		=>MINL,
		SECHWD		=>SECH,
		SECLWD		=>SECL,
		RTCWR		=>I2CWR,
		
		clk			=>clk,
		rstn		=>rstn
	);
	YEHWD<=	wdat 				when wr='1' else YEHID;
	YELWD<=	wdat 				when wr='1' else YELID;
	MONWD<=	monwdat 			when wr='1' else MONID;
	DAYHWD<=wdat(1 downto 0) 	when wr='1' else DAYHID;
	DAYLWD<=wdat 				when wr='1' else DAYLID;
	WDAYWD<=wdat(2 downto 0)	when wr='1' else WDAYID;
	HORHWD<=wdat(1 downto 0)	when wr='1' else HORHID;
	HORLWD<=wdat 				when wr='1' else HORLID;
	MINHWD<=wdat(2 downto 0)	when wr='1' else MINHID;
	MINLWD<=wdat 				when wr='1' else MINLID;
	SECHWD<=wdat(2 downto 0)	when wr='1' else SECHID;
	SECLWD<=wdat 				when wr='1' else SECLID;
	
	process(clk,rstn)begin
		if(rstn='0')then
			BNKSEL<='0';
		elsif(clk' event and clk='1')then
			if(addr=x"d" and wr='1')then
				BNKSEL<=wdat(0);
			end if;
		end if;
	end process;
	
	YEHWR<=	'1' when addr=x"c" and BNKSEL='0' and wr='1' else I2CSET;
	YELWR<=	'1' when addr=x"b" and BNKSEL='0' and wr='1' else I2CSET;
	MONWR<=	'1' when (addr=x"9" or addr=x"a") and BNKSEL='0' and wr='1' else I2CSET;
	DAYHWR<='1' when addr=x"8" and BNKSEL='0' and wr='1' else I2CSET;
	DAYLWR<='1' when addr=x"7" and BNKSEL='0' and wr='1' else I2CSET;
	WDAYWR<='1' when addr=x"6" and BNKSEL='0' and wr='1' else I2CSET;
	HORHWR<='1' when addr=x"5" and BNKSEL='0' and wr='1' else I2CSET;
	HORLWR<='1' when addr=x"4" and BNKSEL='0' and wr='1' else I2CSET;
	MINHWR<='1' when addr=x"3" and BNKSEL='0' and wr='1' else I2CSET;
	MINLWR<='1' when addr=x"2" and BNKSEL='0' and wr='1' else I2CSET;
	SECHWR<='1' when addr=x"1" and BNKSEL='0' and wr='1' else I2CSET;
	SECLWR<='1' when addr=x"0" and BNKSEL='0' and wr='1' else I2CSET;
	SECZWR<='1' when addr=x"0" and BNKSEL='0' and wr='1' else I2CSET;
	
	wror<=	YEHWR or YELWR or MONWR or DAYHWR or DAYLWR or WDAYWR or HORHWR or HORLWR or MINHWR or MINLWR or SECHWR or SECLWR or SECZWR;
	
	process(clk,rstn)begin
		if(rstn='0')then
			i2cwcount<=0;
			I2CWR<='0';
		elsif(clk' event and clk='1')then
			I2CWR<='0';
			if(wror='1')then
				i2cwcount<=clkfreq/10;
			elsif(i2cwcount=1)then
				I2CWR<='1';
				i2cwcount<=i2cwcount-1;
			elsif(i2cwcount>0)then
				i2cwcount<=i2cwcount-1;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			MONHt<='0';
			MONLt<=x"0";
		elsif(clk' event and clk='1')then
			if(wr='1' and BNKSEL='0')then
				case addr is
				when x"9" =>
					MONLt<=wdat;
				when x"a" =>
					MONHt<=wdat(0);
				when others =>
				end case;
			end if;
		end if;
	end process;
	monwdat<=MONLt when MONHt='0' else MONLt+x"a";

	rdat<=	SECL		when addr=x"0" and BNKSEL='0' else
			'0' & SECH	when addr=x"1" and BNKSEL='0' else
			MINL		when addr=x"2" and BNKSEL='0' else
			'0' & MINH	when addr=x"3" and BNKSEL='0' else
			HORL		when addr=x"4" and BNKSEL='0' else
			"00" & HORH	when addr=x"5" and BNKSEL='0' else
			'0' & WDAY	when addr=x"6" and BNKSEL='0' else
			DAYL		when addr=x"7" and BNKSEL='0' else
			"00" & DAYH	when addr=x"8" and BNKSEL='0' else
			MON			when MON<x"a" and addr=x"9" and BNKSEL='0' else
			MON-x"a"	when addr=x"9" and BNKSEL='0' else
			x"0"		when MON<x"a" and addr=x"a" and BNKSEL='0' else
			x"1"		when addr=x"a" and BNKSEL='0' else
			YEL			when addr=x"b" and BNKSEL='0' else
			YEH			when addr=x"c" and BNKSEL='0' else
			"000" & BNKSEL when addr=x"d" else
			x"0";
end rtl;
			
