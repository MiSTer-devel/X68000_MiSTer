LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_timing.all;

entity FDemu is
generic(
	sysclk		:integer	:=20000
);
port(
	ADDR	:out std_logic_vector(13 downto 0);
	RDDAT	:in std_logic_vector(7 downto 0);
	WRDAT	:out std_logic_vector(7 downto 0);
	DATWR	:out std_logic;
	RDMC	:in std_logic_vector(7 downto 0);
	WRMC	:out std_logic_vector(7 downto 0);
	MCWR	:out std_logic;
	TRACKLEN:in std_logic_vector(13 downto 0);
	TRACKSIDE:out std_logic_vector(7 downto 0);
	FDMODE	:in std_logic_vector(1 downto 0);
	MFM		:in std_logic;
	
	USEL	:in std_logic_vector(1 downto 0);
	READY	:in std_logic;
	WRENn	:in std_logic;		--pin24
	WRBITn	:in std_logic;		--pin22
	RDBITn	:out std_logic;		--pin30
	STEPn	:in std_logic;		--pin20
	SDIRn	:in std_logic;		--pin18
	track0n	:out std_logic;		--pin26
	indexn	:out std_logic;		--pin8
	siden	:in std_logic;		--pin32

	clk		:in std_logic;
	rstn	:in std_logic
);
end FDemu;

architecture rtl of FDemu is
constant 	maxbwidth	:integer	:=4000*sysclk/1000000;
signal	deminit		:std_logic;
signal	dembreak	:std_logic;
signal	fmrxdat		:std_logic_vector(7 downto 0);
signal	fmrxed		:std_logic;
signal	fmmf8det	:std_logic;
signal	fmmfbdet	:std_logic;
signal	fmmfcdet	:std_logic;
signal	fmmfedet	:std_logic;
signal	fmcurwid	:integer range 0 to maxbwidth*2;
signal	mfmrxdat	:std_logic_vector(7 downto 0);
signal	mfmrxed		:std_logic;
signal	rxed		:std_logic;
signal	mfmma1det	:std_logic;
signal	mfmmc2det	:std_logic;
signal	mfmcurwid	:integer range 0 to maxbwidth;
signal	fmrxbit		:std_logic;
signal	mfmrxbit	:std_logic;

signal	fmdeminit	:std_logic;
signal	mfmdeminit	:std_logic;
signal	txdat		:std_logic_vector(7 downto 0);
signal	txwr		:std_logic;
signal	fmtxwr		:std_logic;
signal	mfmtxwr		:std_logic;
signal	fmmf8wr		:std_logic;
signal	fmmfbwr		:std_logic;
signal	fmmfcwr		:std_logic;
signal	fmmfewr		:std_logic;
signal	mfmma1wr	:std_logic;
signal	mfmmc2wr	:std_logic;
signal	fmtxemp		:std_logic;
signal	mfmtxemp	:std_logic;
signal	txemp		:std_logic;
signal	fmwrbit		:std_logic;
signal	mfmwrbit	:std_logic;
signal	txwrbit		:std_logic;
signal	txwrbitex	:std_logic;
signal	fmtxend		:std_logic;
signal	mfmtxend	:std_logic;
signal	txend		:std_logic;
signal	modemsft	:std_logic;
signal	modbreak	:std_logic;

signal	curpos		:std_logic_vector(13 downto 0);
signal	lcurpos		:std_logic_vector(13 downto 0);
signal	ramwr		:std_logic;

signal	mcrdat		:std_logic;
signal	mcwdat		:std_logic_vector(7 downto 0);

signal	bitlen		:integer range 0 to maxbwidth;

signal	curtrack0	:std_logic_vector(6 downto 0);
signal	curtrack1	:std_logic_vector(6 downto 0);
signal	curtrack2	:std_logic_vector(6 downto 0);
signal	curtrack3	:std_logic_vector(6 downto 0);

signal	curtrack0m	:std_logic_vector(6 downto 0);
signal	curtrack1m	:std_logic_vector(6 downto 0);
signal	curtrack2m	:std_logic_vector(6 downto 0);
signal	curtrack3m	:std_logic_vector(6 downto 0);

constant extcount	:integer	:=(sysclk*WR_WIDTH)/1000000;

component fmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txmf8	:in std_logic;
	txmfb	:in std_logic;
	txmfc	:in std_logic;
	txmfe	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txma1	:in std_logic;
	txmc2	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component fmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMF8	:out std_logic;
	DetMFB	:out std_logic;
	DetMFC	:out std_logic;
	DetMFE	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMA1	:out std_logic;
	DetMC2	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component sftgen
generic(
	maxlen	:integer	:=100
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component signext
generic(
	extmax	:integer	:=10
);
port(
	len		:in integer range 0 to extmax;
	signin	:in std_logic;
	
	signout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin

--	bitlen<=10;
	bitlen<=	4000*sysclk/1000000	when FDMODE(1)='0' and MFM='0' else
				2000*sysclk/1000000	when FDMODE(1)='0' and MFM='1' else
				2000*sysclk/1000000	when FDMODE(1)='1' and MFM='0' else
				1000*sysclk/1000000	when FDMODE(1)='1' and MFM='1' else
				4000*sysclk/1000000;

	process(clk,rstn)begin
		if(rstn='0')then
			curpos<=(others=>'0');
			txwr<='0';
			ramwr<='0';
		elsif(clk' event and clk='1')then
			txwr<='0';
			ramwr<='0';
			if(READY='1')then
				if((WRENn='1' and txemp='1') or (WRENn='0' and rxed='1'))then
					if(WRENn='1')then
						txwr<='1';
					else
						ramwr<='1';
					end if;
					if(curpos>=TRACKLEN-1)then
						curpos<=(others=>'0');
					else
						curpos<=curpos+1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	ADDR<=curpos;
	mcrdat<=	RDMC(7) when lcurpos(2 downto 0)="000" else
				RDMC(6) when lcurpos(2 downto 0)="001" else
				RDMC(5) when lcurpos(2 downto 0)="010" else
				RDMC(4) when lcurpos(2 downto 0)="011" else
				RDMC(3) when lcurpos(2 downto 0)="100" else
				RDMC(2) when lcurpos(2 downto 0)="101" else
				RDMC(1) when lcurpos(2 downto 0)="110" else
				RDMC(0) when lcurpos(2 downto 0)="111" else
				'0';
	process(clk)begin
		if(clk' event and clk='1')then
			lcurpos<=curpos;
		end if;
	end process;
	
	txdat<=RDDAT;
	
	fmtxwr<=	'0' when MFM='1' else
				'0' when mcrdat='1' else
				txwr;
	fmmf8wr<=	'0' when MFM='1' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"f8" and txwr='1' else
				'0';
	
	fmmfbwr<=	'0' when MFM='1' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"fb" and txwr='1' else
				'0';
	
	fmmfcwr<=	'0' when MFM='1' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"fc" and txwr='1' else
				'0';

	fmmfewr<=	'0' when MFM='1' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"fe" and txwr='1' else
				'0';
	
	mfmtxwr<=	'0' when MFM='0' else
				'0' when mcrdat='1' else
				txwr;
				
	mfmma1wr<=	'0' when MFM='0' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"a1" and txwr='1' else
				'0';
			
	mfmmc2wr<=	'0' when MFM='0' else
				'0' when mcrdat='0' else
				'1' when RDDAT=x"c2" and txwr='1' else
				'0';
			
	indexn<='0' when curpos="00000000000000" else '1';
	
	sft	:sftgen generic map(maxbwidth) port map(bitlen,modemsft,clk,rstn);
	
	fmtx	:fmmod port map(
		txdat	=>txdat,
		txwr	=>fmtxwr,
		txmf8	=>fmmf8wr,
		txmfb	=>fmmfbwr,
		txmfc	=>fmmfcwr,
		txmfe	=>fmmfewr,
		break	=>'0',
		
		txemp	=>fmtxemp,
		txend	=>fmtxend,
		
		bitout	=>fmwrbit,
		writeen	=>open,
		
		sft		=>modemsft,
		clk		=>clk,
		rstn	=>rstn
	);
	
	mfmtx	:mfmmod port map(
		txdat	=>txdat,
		txwr	=>mfmtxwr,
		txma1	=>mfmma1wr,
		txmc2	=>mfmmc2wr,
		break	=>'0',
		
		txemp	=>mfmtxemp,
		txend	=>mfmtxend,
		
		bitout	=>mfmwrbit,
		writeen	=>open,
		
		sft		=>modemsft,
		clk		=>clk,
		rstn	=>rstn
	);
	txemp<=fmtxemp when MFM='0' else mfmtxemp;
	txwrbit<=fmwrbit when MFM='0' else mfmwrbit;
	wdatext	:signext generic map(extcount) port map(extcount,txwrbit,txwrbitex,clk,rstn);
	
	RDBITn<=not txwrbitex;
	
	fmrxbit<=not WRBITn when MFM='0' and WRENn='0' else '0';
	mfmrxbit<=not WRBITn when MFM='1' and WRENn='0' else '0';
	
	process(clk,rstn)
	variable lREADY	:std_logic;
	begin
		if(rstn='0')then
			lREADY:='0';
			fmdeminit<='0';
			mfmdeminit<='0';
		elsif(clk' event and clk='1')then
			fmdeminit<='0';
			mfmdeminit<='0';
			if(READY='1' and lREADY='0')then
				if(MFM='0')then
					fmdeminit<='1';
				else
					mfmdeminit<='1';
				end if;
			end if;
			lREADY:=READY;
		end if;
	end process;
	
	fmrx	:fmdem generic map(maxbwidth) port map(
		bitlen	=>bitlen,
		
		datin	=>fmrxbit,
		
		init	=>fmdeminit,
		break	=>'0',
		
		RXDAT	=>fmrxdat,
		RXED	=>fmrxed,
		DetMF8	=>fmmf8det,
		DetMFB	=>fmmfbdet,
		DetMFC	=>fmmfcdet,
		DetMFE	=>fmmfedet,
		
		curlen	=>open,
		
		clk		=>clk,
		rstn	=>rstn
	);

	mfmrx	:mfmdem generic map(maxbwidth)port map(
		bitlen	=>bitlen,
		
		datin	=>mfmrxbit,
		
		init	=>mfmdeminit,
		break	=>'0',
		
		RXDAT	=>mfmrxdat,
		RXED	=>mfmrxed,
		DetMA1	=>mfmma1det,
		DetMC2	=>mfmmc2det,
		
		curlen	=>open,
		
		clk		=>clk,
		rstn	=>rstn
	);

	process(clk,rstn)
	variable mcbit	:integer range 0 to 7;
	variable lWRENn	:std_logic;
	begin
		if(rstn='0')then
			rxed<='0';
			WRDAT<=(others=>'0');
			WRMC<=(others=>'0');
			DATWR<='0';
			MCWR<='0';
			lWRENn:='0';
		elsif(clk' event and clk='1')then
			rxed<='0';
			DATWR<='0';
			MCWR<='0';
			mcbit:=7-conv_integer(curpos(2 downto 0));
			if(lWRENn='1' and WRENn='0')then
				WRMC<=RDMC;
			end if;
			if(MFM='0')then
				if(fmmf8det='1' or fmmfbdet='1' or fmmfcdet='1' or fmmfedet='1' or fmrxed='1')then
					if(mcbit=7)then
						WRMC<=(others=>'0');
					elsif(mcbit=0)then
						MCWR<='1';
					end if;
					if(fmmf8det='1')then
						WRDAT<=x"f8";
						WRMC(mcbit)<='1';
					end if;
					if(fmmfbdet='1')then
						WRDAT<=x"fb";
						WRMC(mcbit)<='1';
					end if;
					if(fmmfcdet='1')then
						WRDAT<=x"fc";
						WRMC(mcbit)<='1';
					end if;
					if(fmmfedet='1')then
						WRDAT<=x"fe";
						WRMC(mcbit)<='1';
					end if;
					if(fmrxed='1')then
						WRDAT<=fmrxdat;
						WRMC(mcbit)<='0';
					end if;
					rxed<='1';
					DATWR<='1';
				end if;
			else
				if(mfmma1det='1' or mfmmc2det='1' or mfmrxed='1')then
					if(mcbit=7)then
						WRMC<=(others=>'0');
					elsif(mcbit=0)then
						MCWR<='1';
					end if;
					if(mfmma1det='1')then
						WRDAT<=x"a1";
						WRMC(mcbit)<='1';
					end if;
					if(mfmmc2det='1')then
						WRDAT<=x"c2";
						WRMC(mcbit)<='1';
					end if;
					if(mfmrxed='1')then
						WRDAT<=mfmrxdat;
						WRMC(mcbit)<='0';
					end if;
					rxed<='1';
					DATWR<='1';
				end if;
			end if;
			lWRENn:=WRENn;
		end if;
	end process;
	
	process(clk,rstn)
	variable lSTEPn		:std_logic;
	begin
		if(rstn='0')then
			curtrack0<=(others=>'0');
			curtrack1<=(others=>'0');
			curtrack2<=(others=>'0');
			curtrack3<=(others=>'0');
			lSTEPn:='1';
		elsif(clk' event and clk='1')then
			if(lSTEPn='1' and STEPn='0')then
				if(SDIRn='0')then
					case USEL is
					when "00" =>
						curtrack0<=curtrack0+1;
					when "01" =>
						curtrack1<=curtrack1+1;
					when "10" =>
						curtrack2<=curtrack2+1;
					when "11" =>
						curtrack3<=curtrack3+1;
					when others =>
					end case;
				else
					case USEL is
					when "00" =>
						if(curtrack0>0)then
							curtrack0<=curtrack0-1;
						end if;
					when "01" =>
						if(curtrack1>0)then
							curtrack1<=curtrack1-1;
						end if;
					when "10" =>
						if(curtrack2>0)then
							curtrack2<=curtrack2-1;
						end if;
					when "11" =>
						if(curtrack3>0)then
							curtrack3<=curtrack3-1;
						end if;
					when others =>
					end case;
				end if;
			end if;
			lSTEPn:=STEPn;
		end if;
	end process;
	
	curtrack0m<=	'0' & curtrack0(6 downto 1) when FDMODE="00" else
					curtrack0;
	curtrack1m<=	'0' & curtrack1(6 downto 1) when FDMODE="00" else
					curtrack1;
	curtrack2m<=	'0' & curtrack2(6 downto 1) when FDMODE="00" else
					curtrack2;
	curtrack3m<=	'0' & curtrack3(6 downto 1) when FDMODE="00" else
					curtrack3;
	
	track0n<=	'0' when curtrack0m="0000000" and USEL="00" else
				'0' when curtrack1m="0000000" and USEL="01" else
				'0' when curtrack2m="0000000" and USEL="10" else
				'0' when curtrack3m="0000000" and USEL="11" else
				'1';
				
	TRACKSIDE<=curtrack0m & not siden when USEL="00" else
				curtrack1m & not siden when USEL="01" else
				curtrack2m & not siden when USEL="10" else
				curtrack3m & not siden when USEL="11" else
				(others=>'0');
	
end rtl;