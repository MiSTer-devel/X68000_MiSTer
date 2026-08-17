LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_sectinfo.all;

entity fdc_mister is
generic(
	maxtrack	:integer	:=85;
	preseek	:std_logic	:='0';
	drives	:integer	:=2;
	wtrack	:integer	:=7;
	wsect		:integer	:=5;
	TCtout	:integer	:=100;
	sfreq		:integer	:=20
);
port(
	RDn		:in std_logic;
	WRn		:in std_logic;
	CSn		:in std_logic;
	A0		:in std_logic;
	WDAT	:in std_logic_vector(7 downto 0);
	RDAT	:out std_logic_vector(7 downto 0);
	DATOE	:out std_logic;
	DACKn	:in std_logic;
	DRQ		:out std_logic;
	TC		:in std_logic;
	INTn	:out std_logic;
	WAITIN	:in std_logic	:='0';

	unit		:out std_logic_vector(drives-1 downto 0);
	track		:out std_logic_Vector(wtrack-1 downto 0);
	head		:out std_logic;
	sect		:out std_logic_vector(wsect-1 downto 0);
	sectsize	:out std_logic_vector(1 downto 0);
	rdreq		:out std_logic;
	wrreq		:out std_logic;
	syncreq		:out std_logic;
	sectaddr	:out std_logic_vector(9 downto 0);
	rddat		:in std_logic_vector(7 downto 0);
	wrdat		:out std_logic_vector(7 downto 0);
	mfm			:out std_logic;
	sectbusy	:in std_logic;
	readonly	:in std_logic;
	fmterr		:in std_logic;
	ready		:in std_logic_vector(drives-1 downto 0);
	dsel		:in std_logic_vector(1 downto 0) := "00";

	rxN		:in std_logic_vector(7 downto 0);
	hd80	:in std_logic	:='0';	
	is2hs	:in std_logic	:='0';	
	sectspt	:in std_logic_vector(wsect-1 downto 0)	:="01000";

	seekwait	:std_logic;
	txwait		:std_logic;
	ismode	:in std_logic	:='1';
	busy		:out std_logic;
	hmssft	:in std_logic;
	bitsft	:in std_logic;
	sys_ce	:in std_logic	:='1';
	clk		:in std_logic;
	rstn	:in std_logic
);
end fdc_mister;

architecture rtl of fdc_mister is
constant cmd_READDATA			:std_logic_vector(4 downto 0)	:="00110";
constant cmd_READDELETEDDATA	:std_logic_vector(4 downto 0)	:="01100";
constant cmd_WRITEDATA			:std_logic_vector(4 downto 0)	:="00101";
constant cmd_WRITEDELETEDDATA	:std_logic_vector(4 downto 0)	:="01001";
constant cmd_READATRACK			:std_logic_vector(4 downto 0)	:="00010";
constant cmd_READID				:std_logic_vector(4 downto 0)	:="01010";
constant cmd_FORMATATRACK		:std_logic_vector(4 downto 0)	:="01101";
constant cmd_SCANEQUAL			:std_logic_vector(4 downto 0)	:="10001";
constant cmd_SCANLOWEQUAL		:std_logic_vector(4 downto 0)	:="11001";
constant cmd_SCANHIGHEQUAL		:std_logic_vector(4 downto 0)	:="11101";
constant cmd_RECALIBRATE		:std_logic_vector(4 downto 0)	:="00111";
constant cmd_SENSEINTSTATUS	:std_logic_vector(4 downto 0)	:="01000";
constant cmd_SPECIFY				:std_logic_vector(4 downto 0)	:="00011";
constant cmd_SENSEDRIVESTATUS	:std_logic_vector(4 downto 0)	:="00100";
constant cmd_SEEK					:std_logic_vector(4 downto 0)	:="01111";

signal	WPRT		:std_logic;
signal	syncbusy_seen	:std_logic;
signal	track0n		:std_logic_vector(3 downto 0);
signal	track0nb		:std_logic_vector(3 downto 0);
signal	track0ns		:std_logic;
signal	READYn		:std_logic;
signal	seekReadyin	:std_logic;

signal	IOWR_DAT	:std_logic;
signal	IORD_DAT	:std_logic;
signal	IORD_STA	:std_logic;
signal	lIORD_DAT	:std_logic;
signal	datnum		:integer range 0 to 20;
signal	CPUWR_DAT	:std_logic;
signal	CPURD_DAT	:std_logic;
signal	lCPURD_DAT	:std_logic_vector(1 downto 0);
signal	lCPUWR_DAT	:std_logic_vector(1 downto 0);
signal	DMARD		:std_logic;
signal	DMAWR		:std_logic;
signal	lDMARD		:std_logic;
signal	lDMAWR		:std_logic;
signal	DMARDx		:std_logic;
signal	DMAWRx		:std_logic;
signal	CPUWRDAT	:std_logic_vector(7 downto 0);

signal	EXEC			:std_logic;
signal	end_EXEC		:std_logic;
signal	RD_CMD		:std_logic;
signal	RDDAT_CMD	:std_logic_vector(7 downto 0);
signal	COMPDAT		:std_logic_vector(7 downto 0);
signal	scancomp	:std_logic;
signal	sREADYn		:std_logic;
signal	command	:std_logic_vector(4 downto 0);
signal	ecommand:std_logic_vector(4 downto 0);
signal	C		:std_logic_vector(7 downto 0);
signal	iC		:integer range 0 to maxtrack;
signal	D		:std_logic_vector(7 downto 0);
signal	DTL		:std_logic_vector(7 downto 0);
signal	EOT		:std_logic_vector(7 downto 0);
signal	HD		:std_logic;
signal	H		:std_logic_vector(7 downto 0);
signal	MF		:std_logic;
signal	MT		:std_logic;
signal	N		:std_logic_vector(7 downto 0);
signal	ND		:std_logic;
signal	R		:std_logic_vector(7 downto 0);
signal	cntR	:std_logic_vector(7 downto 0);
signal	SC		:std_logic_vector(7 downto 0);
signal	SRT		:std_logic_vector(3 downto 0);
signal	US		:std_logic_vector(1 downto 0);
signal	iUS		:integer range 0 to 3;
subtype PCN_t is std_logic_vector(7 downto 0);
signal	PCN		:PCN_t;
type PCN_array is array(natural range <>) of PCN_t;
signal	PCNx	:PCN_array(0 to 3);
signal	cPCN	:PCN_t;
signal	ST0		:std_logic_vector(7 downto 0);
signal	ST1		:std_logic_vector(7 downto 0);
signal	ST2		:std_logic_vector(7 downto 0);
signal	ST3		:std_logic_vector(7 downto 0);
signal	RDDAT_DAT	:std_logic_vector(7 downto 0);
signal	saddr	:std_logic_vector(9 downto 0);

signal	sIC		:std_logic_vector(1 downto 0);	
signal	sSE		:std_logic;						
signal	sEC		:std_logic;						
signal	sNR		:std_logic;						
signal	sHD		:std_logic;						
signal	sUS		:std_logic_vector(1 downto 0);
signal	sEN		:std_logic;						
signal	sDE		:std_logic;						
signal	sOR		:std_logic;						
signal	sND		:std_logic;						
signal	sNW		:std_logic;						
signal	sMA		:std_logic;						
signal	sCM		:std_logic;						
signal	sDD		:std_logic;
signal	sWC		:std_logic;						
signal	sSH		:std_logic;						
signal	sSN		:std_logic;						
signal	sBC		:std_logic;						
signal	sMD		:std_logic;

signal	sDxB	:std_logic_vector(3 downto 0);
signal	sCB		:std_logic;
signal	sEXM	:std_logic;
signal	sDIO	:std_logic;
signal	sRQM	:std_logic;
signal	MSR		:std_logic_vector(7 downto 0);

signal	sideb	:std_logic;
signal	uselb	:std_logic_vector(1 downto 0);
signal	DxBclr	:std_logic;
signal	SISen	:std_logic;
signal	SISclr	:std_logic;
signal	dUS		:std_logic_Vector(1 downto 0);
signal	idUS		:integer range 0 to 3;

signal	sDIOc	:std_logic;
signal	sDIOd	:std_logic;

signal	TCclr		:std_logic;
signal	TCen,TCenb		:std_logic;

signal	INT		:std_logic;		
signal	INTs		:std_logic;
signal	DMARQ		:std_logic;		
signal	setC		:std_logic;
signal	incC		:std_logic;
signal	resH		:std_logic;
signal	setH		:std_logic;
signal	setR		:std_logic;
signal	incR		:std_logic;
signal	resR		:std_logic;
signal	wrapR		:std_logic;
signal	cmdwd		:integer range 0 to 400000;
signal	setN		:std_logic;
signal	setHD		:std_logic;
signal	resHD		:std_logic;

signal	rxC			:std_logic_vector(7 downto 0);
signal	rxR			:std_logic_vector(7 downto 0);
signal	ridcnt		:std_logic_vector(wsect-1 downto 0);	

signal	bytecount	:integer range 0 to 16384;
signal	diag_nomatch	:std_logic;
signal	seek_bgn	:std_logic;
signal	seek_end	:std_logic_vector(3 downto 0);
signal	seek_init	:std_logic;
signal	seek_err	:std_logic_vector(3 downto 0);
signal	seek_sft	:std_logic;

signal	seek_initv	:std_logic_vector(3 downto 0);
signal	seek_bgnv	:std_logic_vector(3 downto 0);
signal	seek_endv	:std_logic_vector(3 downto 0);
signal	seek_busyv	:std_logic_vector(3 downto 0);
signal	seek_errv	:std_logic_vector(3 downto 0);
signal	seekbusy	:std_logic;
signal	seekusel	:std_logic_vector(1 downto 0);
signal	iseekusel	:integer range 0 to 3;
signal	seekpend		:std_logic_vector(3 downto 0);
signal	seek_sftx	:std_logic_vector(3 downto 0);
subtype cylnum_t is integer range 0 to maxtrack;
type cylnum_array is array(natural range <>) of  cylnum_t;
signal	seek_cylx	:cylnum_array(0 to 3);
signal	seek_curx	:cylnum_array(0 to 3);
signal	iCx			:cylnum_array(0 to 3);
signal	TCtcount		:integer range 0 to TCtout;
signal	txsft			:std_logic;

type execstate_t is (
		es_idle,
		es_seek,
		es_wseek,
		es_readychk,
		es_C,
		es_Cw,
		es_H,
		es_Hw,
		es_R,
		es_Rw,
		es_N,
		es_Nw,
		es_DATA,
		es_DATAw,
		es_NXT,
		es_waitTC,
		es_sync
	);
signal	execstate	:execstate_t;
component seekcont
generic(
	maxtrack	:integer	:=80
);
port(
	uselin	:in std_logic_vector(1 downto 0);
	inireq	:in std_logic;
	seekreq	:in std_logic;
	destin	:in integer range 0 to maxtrack;
	
	iniout	:out std_logic_vector(3 downto 0);
	seekout	:out std_logic_vector(3 downto 0);
	dest0	:out integer range 0 to maxtrack;
	dest1	:out integer range 0 to maxtrack;
	dest2	:out integer range 0 to maxtrack;
	dest3	:out integer range 0 to maxtrack;
	readyin	:in std_logic;
	
	sendin	:in std_logic_vector(3 downto 0);
	serrin	:in std_logic_vector(3 downto 0);
	
	seek_end	:out std_logic_vector(3 downto 0);
	seek_err	:out std_logic_vector(3 downto 0);
	readyout	:out std_logic;
	
	seek_pend	:out std_logic_vector(3 downto 0);
	busy	:out std_logic;
	uselout	:out std_logic_vector(1 downto 0);
	
	clk		:in std_logic;
	rstn	:in	std_logic
);
end component;

component heademu
generic(
	maxtrack	:integer	:=79;
	maxset		:integer	:=10;
	initseek	:integer	:=0
);
port(
	desttrack	:in integer range 0 to maxtrack;
	destset		:in std_logic;
	setwait		:in integer range 0 to maxset;		
	
	curtrack	:out integer range 0 to maxtrack;
	
	reachtrack	:out std_logic;
	busy		:out std_logic;
	
	track0n		:out std_logic;
	
	init		:in std_logic;
	seekerr		:out std_logic;
	
	sft			:in std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
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

component sftdiv
generic(
	width	:integer	:=8
);
port(
	sel		:in std_logic_vector(width-1 downto 0);
	sftin	:in std_logic;
	
	sftout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;
function Ntolen(xN:std_logic_vector(7 downto 0);xDTL:std_logic_vector(7 downto 0)) return integer is
variable bytelen	:integer range 0 to 16384;
begin
	if(xN=x"00" and xDTL<x"80")then
		bytelen:=conv_integer(xDTL);
	elsif(xN=x"00")then
		bytelen:=128;
	elsif(xN=x"01")then
		bytelen:=256;
	elsif(xN=x"02")then
		bytelen:=512;
	elsif(xN=x"03")then
		bytelen:=1024;
	elsif(xN=x"04")then
		bytelen:=2048;
	elsif(xN=x"05")then
		bytelen:=4096;
	elsif(xN=x"06")then
		bytelen:=8192;
	else
		bytelen:=16384;
	end if;
	return bytelen;
end Ntolen;

begin
	
	IOWR_DAT<='1' when CSn='0' and A0='1' and WRn='0' else '0';
	IORD_DAT<='1' when CSn='0' and A0='1' and RDn='0' else '0';
	IORD_STA<='1' when CSn='0' and A0='0' and RDn='0' else '0';
	DMAWR<='1' when DACKn='0' and WRn='0' else '0';
	DMARD<='1' when DACKn='0' and RDn='0' else '0';

	WPRT<=not readonly;
	READYn<=not ready(conv_integer(dsel)) when conv_integer(dsel)<drives else '1';
	seekReadyin<=not ready(idUS) when idUS<drives else '1';
	txsft<=	'1' when txwait='0' else bitsft;

	process(clk,rstn)
		variable wr_high_clks : integer range 0 to 3 := 0;
		variable wr_data_l    : std_logic_vector(7 downto 0) := (others=>'0');
	begin
		if(rstn='0')then
			lIORD_DAT<='0';
			CPUWRDAT<=(others=>'0');
			CPUWR_DAT<='0';
			CPURD_DAT<='0';
			DRQ<='0';
			wr_high_clks:=0;
			wr_data_l:=(others=>'0');
		elsif(clk' event and clk='1')then
			CPUWR_DAT<='0';
			CPURD_DAT<='0';
			DMARDx<='0';
			DMAWRx<='0';
			if(IOWR_DAT='1')then
				wr_data_l:=WDAT;
				if(wr_high_clks<3)then wr_high_clks:=wr_high_clks+1; end if;
			elsif(wr_high_clks/=0)then
				if(wr_high_clks>=2)then
					CPUWRDAT<=wr_data_l;
					CPUWR_DAT<='1';
				end if;
				wr_high_clks:=0;
			end if;
			if(sys_ce='1')then
				if(IORD_DAT='0' and lIORD_DAT='1')then
					CPURD_DAT<='1';
				end if;
				if(DMAWR='1')then
					CPUWRDAT<=WDAT;
				elsif(DMAWR='0' and lDMAWR='1')then
					DMAWRx<='1';
				end if;
				if(DMARD='0' and lDMARD='1')then
					DMARDx<='1';
				end if;
				lIORD_DAT<=IORD_DAT;
				lDMAWR<=DMAWR;
				lDMARD<=DMARD;
			end if;
			if(DMARQ='1')then
				DRQ<='1';
			elsif(DACKn='0')then
				DRQ<='0';
			elsif(sys_ce='1' and (IORD_DAT='1' or IOWR_DAT='1'))then
				DRQ<='0';
			end if;
		end if;
	end process;
	
	DATOE<='1' when IORD_DAT='1' or IORD_STA='1' or DMARD='1' else '0';
	
		process(clk,rstn)begin
		if(rstn='0')then
			command	<=(others=>'0');
			C		<=(others=>'0');
			D		<=(others=>'0');
			DTL		<=(others=>'0');
			EOT		<=(others=>'0');
			HD		<='0';
			MF		<='0';
			MT		<='0';
			N		<=(others=>'0');
			ND		<='0';
			H		<=(others=>'0');
			R		<=(others=>'0');
			SC		<=(others=>'0');
			SRT		<=(others=>'0');
			US		<=(others=>'0');
			datnum	<=0;
			EXEC	<='0';
			RD_CMD	<='1';
			RDDAT_CMD<=(others=>'0');
			sDIOc	<='0';
			DxBclr	<='0';
			SISclr	<='0';
			cmdwd	<=0;
		elsif(clk' event and clk='1')then
			EXEC<='0';
			DxBclr	<='0';
			SISclr	<='0';
			if(setC='1')then
				C<=rxC;
			elsif(incC='1')then
				C<=C+x"01";
			end if;
			if(setH='1')then
				H<=x"01";
			elsif(resH='1')then
				H<=x"00";
			end if;
			if(setR='1')then
				R<=rxR;
			elsif(incR='1')then
				R<=R+x"01";
			elsif(wrapR='1')then
				R<=x"01";
			elsif(resR='1')then
				if(is2hs='1')then
					R<=x"0A";	
				else
					R<=x"01";
				end if;
			end if;
			if(setN='1')then
				N<=rxN;
			end if;
			if(setHD='1')then
				HD<='1';
			elsif(resHD='1')then
				HD<='0';
			end if;
			if(datnum=0)then
				RDDAT_CMD<=(others=>'0');
				RD_CMD<='1';
				sDIOc<='0';
				if(CPUWR_DAT='1')then
					command<=CPUWRDAT(4 downto 0);
					case CPUWRDAT(4 downto 0) is
					when cmd_READDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_READDELETEDDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_WRITEDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_WRITEDELETEDDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_READATRACK =>
						MF<=CPUWRDAT(6);
					when cmd_READID =>
						MF<=CPUWRDAT(6);
					when cmd_FORMATATRACK =>
						MF<=CPUWRDAT(6);
						R<=x"00";
					when cmd_SCANEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_SCANLOWEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_SCANHIGHEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when others=>
					end case;
					datnum<=1;
				end if;
			else
				case command is
				when cmd_READDATA | cmd_READDELETEDDATA | cmd_WRITEDATA | cmd_WRITEDELETEDDATA |
					cmd_READATRACK |
					cmd_SCANEQUAL | cmd_SCANLOWEQUAL | cmd_SCANHIGHEQUAL =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							C<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(CPUWR_DAT='1')then
							H<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 4 =>
						if(CPUWR_DAT='1')then
							R<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 5 =>
						if(CPUWR_DAT='1')then
							N<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 6 =>
						if(CPUWR_DAT='1')then
							EOT<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 7 =>
						if(CPUWR_DAT='1')then
							datnum<=datnum+1;
						end if;
					when 8 =>
						if(CPUWR_DAT='1')then
							DTL<=CPUWRDAT;
							RD_CMD<='0';
							sDIOc<='1';
							datnum<=datnum+1;
						end if;
					when 9 =>
						if(WAITIN='0')then
							EXEC<='1';
							datnum<=datnum+1;
						end if;
					when 10 =>
						if(end_EXEC='1')then
							RD_CMD<='1';
							RDDAT_CMD<=ST0;
							datnum<=datnum+1;
						end if;
					when 11=>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST1;
							datnum<=datnum+1;
						end if;
					when 12 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST2;
							datnum<=datnum+1;
						end if;
					when 13 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=C;
							datnum<=datnum+1;
						end if;
					when 14 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=H;
							datnum<=datnum+1;
						end if;
					when 15 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=R;
							datnum<=datnum+1;
						end if;
					when 16 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=N;
							datnum<=datnum+1;
						end if;
					when 17 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_READID =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							sDIOc<='1';
							RD_CMD<='0';
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(WAITIN='0')then
							EXEC<='1';
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(end_EXEC='1')then
							RD_CMD<='1';
							RDDAT_CMD<=ST0;
							datnum<=datnum+1;
						end if;
					when 4=>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST1;
							datnum<=datnum+1;
						end if;
					when 5 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST2;
							datnum<=datnum+1;
						end if;
					when 6 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=C;
							datnum<=datnum+1;
						end if;
					when 7 =>
						if(CPURD_DAT='1')then
							if(hd80='1')then
								if(HD='0')then
									if(C=x"00" and R=x"01")then
										RDDAT_CMD<=x"00";
									else
										RDDAT_CMD<=x"80";
									end if;
								else
									RDDAT_CMD<=x"81";
								end if;
							else
								RDDAT_CMD<=H;
							end if;
							datnum<=datnum+1;
						end if;
					when 8 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=R;
							datnum<=datnum+1;
						end if;
					when 9 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=N;
							datnum<=datnum+1;
						end if;
					when 10 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_FORMATATRACK =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							N<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(CPUWR_DAT='1')then
							SC<=CPUWRDAT;
							datnum<=datnum+1;
						end if;
					when 4 =>
						if(CPUWR_DAT='1')then
							datnum<=datnum+1;
						end if;
					when 5 =>
						if(CPUWR_DAT='1')then
							D<=CPUWRDAT;
							R<=x"01";
							sDIOc<='1';
							RD_CMD<='0';
							datnum<=datnum+1;
						end if;
					when 6 =>
						if(WAITIN='0')then
							EXEC<='1';
							datnum<=datnum+1;
						end if;
					when 7 =>
						if(end_EXEC='1')then
							RD_CMD<='1';
							RDDAT_CMD<=ST0;
							datnum<=datnum+1;
						end if;
					when 8=>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST1;
							datnum<=datnum+1;
						end if;
					when 9 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=ST2;
							datnum<=datnum+1;
						end if;
					when 10 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=C;
							datnum<=datnum+1;
						end if;
					when 11 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=H;
							datnum<=datnum+1;
						end if;
					when 12 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=R;
							datnum<=datnum+1;
						end if;
					when 13 =>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=N;
							datnum<=datnum+1;
						end if;
					when 14 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_RECALIBRATE =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							C<=x"00";
							RD_CMD<='0';
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(WAITIN='0')then
							EXEC<='1';
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(end_EXEC='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_SENSEINTSTATUS =>
					case datnum is
					when 1 =>
						RD_CMD<='1';
						sDIOc<='1';
						if(SISen='1')then
							RDDAT_CMD<=ST0;
							datnum<=datnum+1;
						else
							RDDAT_CMD<=x"80";
							datnum<=4;
						end if;
					when 2=>
						if(CPURD_DAT='1')then
							RDDAT_CMD<=PCN;
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							DxBclr<='1';
							SISclr<='1';
							datnum<=0;
						end if;
					when 4 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_SPECIFY =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							SRT<=CPUWRDAT(7 downto 4);
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							ND<=CPUWRDAT(0);
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_SENSEDRIVESTATUS =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							RD_CMD<='1';
							sDIOc<='1';
							datnum<=datnum+1;
						end if;
					when 2 =>
							RDDAT_CMD<=ST3;
							datnum<=datnum+1;
					when 3 =>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when cmd_SEEK =>
					case datnum is
					when 1 =>
						if(CPUWR_DAT='1')then
							US<=CPUWRDAT(1 downto 0);
							HD<=CPUWRDAT(2);
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							C<=CPUWRDAT;
							RD_CMD<='0';
							datnum<=datnum+1;
						end if;
					when 3 =>
						if(WAITIN='0')then
							EXEC<='1';
							datnum<=datnum+1;
						end if;
					when 4 =>
						if(end_EXEC='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				when others =>		
					case datnum is
					when 1 =>
						RD_CMD<='1';
						RDDAT_CMD<=x"80";
						sDIOc<='1';
						datnum<=datnum+1;
					when 2=>
						if(CPURD_DAT='1')then
							RD_CMD<='1';
							datnum<=0;
						end if;
					when others =>
						datnum<=0;
					end case;
				end case;
			end if;
			if(datnum=0 or CPUWR_DAT='1' or RD_CMD='0' or sDIOc='1')then
				cmdwd<=0;
			elsif(cmdwd<400000)then
				cmdwd<=cmdwd+1;
			else
				cmdwd<=0;
				datnum<=0;
				RD_CMD<='1';
				sDIOc<='0';
			end if;
		end if;
	end process;
	
	sCB<=	'0'	when command=cmd_RECALIBRATE and datnum=2 else
			'0'	when command=cmd_SEEK and datnum=3 else
			'0'	when datnum=0 else
			'1';

	iUS<=conv_integer(US);
	sEXM<='1' when (execstate/=es_IDLE and ND='1') else '0';
	ST0<=sIC &sSE & sEC & sNR & sHD & sUS;
	ST1<=sEN & '0' & sDE & sOR & '0' & sND & sNW & sMA;
	ST2<='0' & sCM & sDD & sWC & sSH & sSN & sBC & sMD;
	ST3<='0' & not WPRT & not READYn & not track0ns & sideb & HD & uselb;
	MSR<=sRQM & sDIO & sEXM & sCB & sDxB;
	
	RDAT<=	RDDAT_DAT when DACKn='0' else
			MSR when A0='0' else
			RDDAT_CMD	when RD_CMD='1' else
			RDDAT_DAT;
	sDIO<=sDIOc when RD_CMD='1' else sDIOd;
	
	sideb<=HD;
	uselb<=US;
	process(dsel)
		variable selected_unit : integer range 0 to 3;
	begin
		unit<=(others=>'0');
		selected_unit:=conv_integer(dsel);
		if(selected_unit<drives)then
			unit(selected_unit)<='1';
		end if;
	end process;
	
	
	process(clk,rstn)
	begin
		if(rstn='0')then
			TCenb<='0';
		elsif(clk' event and clk='1')then
			if(TC='1')then
				TCenb<='1';
			elsif(TCclr='1')then
				TCenb<='0';
			end if;
		end if;
	end process;
	TCen<=TCenb and (not TCclr);
	
	process(clk,rstn)begin
		if(rstn='0')then
			INTn<='1';
		elsif(clk' event and clk='1')then
			if(INTs='1')then
				INTn<='0';
				SISen<='1';
			elsif(INT='1')then
				INTn<='0';
				if(ismode='1')then
					SISen<='1';
				end if;
			elsif(CPURD_DAT='1' and RD_CMD='1' and command/=cmd_SENSEDRIVESTATUS)then
				INTn<='1';
			end if;
			if(SISclr='1')then
				SISen<='0';
			end if;
		end if;
	end process;

	process(clk,rstn)
	variable swait	:integer range 0 to 3;
	begin
		if(rstn='0')then
			execstate<=es_idle;
			end_EXEC<='0';
			seek_bgn<='0';
			seek_init<='0';
			PCN<=(others=>'0');
			cntR<=(others=>'0');
			TCclr<='0';
			INT<='0';
			INTs<='0';
			DMARQ<='0';
			setC<='0';
			incC<='0';
			resH<='0';
			setH<='0';
			setR<='0';
			incR<='0';
			resR<='0';
			wrapR<='0';
			setN<='0';
			setHD<='0';
			resHD<='0';
			sIC<="00";
			sNR<='0';
			sOR<='0';
			sND<='0';
			sDE<='0';
			sEN<='0';
			sDIOd<='0';
			sNW<='0';
			sMA<='0';
			sRQM<='1';
			sCM<='0';
			sWC<='0';
			sDD<='0';
			sMD<='0';
			sSH<='0';
			wrdat<=(others=>'0');
			wrreq<='0';
			rdreq<='0';
			syncreq<='0';
			syncbusy_seen<='0';
			ecommand<=(others=>'0');
			COMPDAT<=(others=>'0');
			scancomp<='0';
			ridcnt<=(others=>'0');
			diag_nomatch<='0';
		elsif(clk' event and clk='1')then
			end_EXEC<='0';
			seek_bgn<='0';
			seek_init<='0';
			TCclr<='0';
			INT<='0';
			INTs<='0';
			DMARQ<='0';
			setC<='0';
			incC<='0';
			resH<='0';
			setH<='0';
			setR<='0';
			incR<='0';
			resR<='0';
			wrapR<='0';
			setN<='0';
			setHD<='0';
			resHD<='0';
			rdreq<='0';
			wrreq<='0';
			if(swait>0)then
				swait:=swait-1;
			elsif(execstate=es_idle)then
				sRQM<='1';
				if(seek_end/="0000")then
					sHD<=HD;
					case seek_end is
					when "0001" =>
						sUS<="00";
						PCN<=PCNx(0);
					when "0010" =>
						sUS<="01";
						PCN<=PCNx(1);
					when "0100" =>
						sUS<="10";
						PCN<=PCNx(2);
					when "1000" =>
						sUS<="11";
						PCN<=PCNx(3);
					when others =>
					end case;
					sIC<="00";
					sHD<=HD;
					sEC<='0';
					sSE<='1';
					sNR<=sREADYn;
					INTs<='1';
				elsif(seek_err/="0000")then
					sIC<="01";
					sHD<=HD;
					case seek_err is
					when "0001" =>
						sUS<="00";
						PCN<=PCNx(0);
					when "0010" =>
						sUS<="01";
						PCN<=PCNx(1);
					when "0100" =>
						sUS<="10";
						PCN<=PCNx(2);
					when "1000" =>
						sUS<="11";
						PCN<=PCNx(3);
					when others =>
					end case;
					sNR<=sREADYn;
					sHD<=HD;
					sEC<='1';
					sSE<='0';
					INTs<='1';
				end if;
				if(EXEC='1')then
					diag_nomatch<='0';
					sIC<="00";
					sNR<=READYn;
					sHD<=HD;
					sUS<=US;
					sOR<='0';
					sND<='0';
					sDE<='0';
					sEN<='0';
					sNW<='0';
					sMA<='0';
					sWC<='0';
					sDD<='0';
					sEN<='0';
					sSH<='0';
					sMD<='0';
					sRQM<='0';
					if(command=cmd_READDELETEDDATA)then
						sCM<='1';
					else
						sCM<='0';
					end if;
					ecommand<=command;
					case command is
					when cmd_READDATA =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_READDELETEDDATA =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_WRITEDATA =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_WRITEDELETEDDATA =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_READATRACK =>
						if(N/=rxN or
						   (is2hs='1' and (conv_integer(R)<10 or
						                    conv_integer(R)>=10+conv_integer(sectspt))) or
						   (is2hs='0' and (conv_integer(R)<1 or
						                    conv_integer(R)>conv_integer(sectspt))))then
							diag_nomatch<='1';
						end if;
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_READID =>
						execstate<=es_wseek;
					when cmd_FORMATATRACK =>
						execstate<=es_wseek;
						cntR<=x"01";
					when cmd_SCANEQUAL =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_SCANLOWEQUAL =>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_SCANHIGHEQUAL	=>
						if(preseek='1')then
							seek_bgn<='1';
							execstate<=es_seek;
						else
							execstate<=es_wseek;
						end if;
					when cmd_RECALIBRATE =>
						if(iUS<drives)then
							seek_init<='1';
							execstate<=es_seek;
						else
							sHD<=HD;
							sUS<=US;
							sIC<="01";
							sNR<='1';
							sEC<='1';
							sSE<='0';
							PCN<=cPCN;
							INTs<='1';
							sRQM<='1';
							end_EXEC<='1';
							execstate<=es_idle;
						end if;
					when cmd_SEEK =>
						execstate<=es_readychk;
					when others=>
						end_EXEC<='1';
						execstate<=es_idle;
						sRQM<='1';
					end case;
				end if;
			elsif(execstate=es_sync)then
				if(sectbusy='1')then
					syncreq<='0';
					syncbusy_seen<='1';
				elsif(syncbusy_seen='1')then
					syncreq<='0';
					syncbusy_seen<='0';
					end_EXEC<='1';
					execstate<=es_idle;
				end if;
			else
				case ecommand is
				when cmd_READDATA | cmd_READDELETEDDATA | cmd_READATRACK  =>
					if(READYn='1')then
						sHD<=HD;
						sUS<=US;
						sIC<="11";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sND<='0';
						sMA<='0';
						PCN<=cPCN;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					end if;
					case execstate is
					when es_seek =>
						if(seek_end(iUS)='1')then
							execstate<=es_wseek;
						elsif(seek_err(iUS)='1')then
							sIC<="01";
							sNR<=READYn;
							sEC<='1';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_idle;
						end if;
					when es_wseek =>
						if(seekbusy='0')then
							if(fmterr='1')then
								sHD<=HD;
								sUS<=US;
								sIC<="01";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sND<='1';
								sMA<='1';
								PCN<=cPCN;
								INT<='1';
								end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(ecommand/=cmd_READATRACK and
						      ((is2hs='1' and
						        not (R=x"01" and cPCN=x"00" and HD='0') and
						        (conv_integer(R)<10 or
						         conv_integer(R)>=10+conv_integer(sectspt))) or
						       (is2hs='0' and
						        (conv_integer(R)<1 or
						         conv_integer(R)>conv_integer(sectspt)))))then
							sHD<=HD;
							sUS<=US;
							sIC<="01";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sND<='1';
							sMA<='0';
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(ecommand=cmd_READATRACK)then
								resR<='1';
								TCclr<='1';
								execstate<=es_DATA;
								rdreq<='1';
								swait:=2;
								bytecount<=Ntolen(N,DTL);
								saddr<=(others=>'0');
							else
								TCclr<='1';
								rdreq<='1';
								swait:=2;
								bytecount<=Ntolen(N,DTL);
								execstate<=es_DATA;
							end if;
						end if;
					when es_DATA =>
						if(TCen='1')then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							if(ecommand=cmd_READATRACK and diag_nomatch='1')then
								sND<='1';
								sDE<='1';
							end if;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(sectbusy='0' and txsft='1')then
							if(ND='0')then
								DMARQ<='1';
							else
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								INT<='1';
							end if;
							RDDAT_DAT<=rddat;
							sDIOd<='1';
							sRQM<='1';
							execstate<=es_DATAw;
						end if;
					when es_DATAw =>
						if(ecommand=cmd_READATRACK and (TCen='1' or TC='1'))then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							if(diag_nomatch='1')then
								sND<='1';
								sDE<='1';
							end if;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(CPURD_DAT='1' or DMARDx='1')then
							sRQM<='0';
							saddr<=saddr+1;
							if(bytecount>1)then
								bytecount<=bytecount-1;
								swait:=2;
								rdreq<='1';
								execstate<=es_DATA;
							else
								execstate<=es_NXT;
							end if;
						end if;
					when es_NXT =>
						bytecount<=Ntolen(N,DTL);
						saddr<=(others=>'0');
						if(R<EOT)then
							incR<='1';
							rdreq<='1';
							swait:=2;
							execstate<=es_DATA;
						elsif(MT='1')then
							if(HD='0')then
								resR<='1';
								setH<='1';
								setHD<='1';
								rdreq<='1';
								swait:=2;
								execstate<=es_DATA;
							else
								resR<='1';
								resH<='1';
								resHD<='1';
								incC<='1';
								TCtcount<=TCtout;
								execstate<=es_waitTC;
							end if;
						else
							wrapR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
						end if;
						sDE<='0';
					when es_waitTC =>
						if(TCen='1' or TCtcount=0)then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<=ismode;
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						else
							TCtcount<=TCtcount-1;
						end if;
					when others =>
						execstate<=es_idle;
					end case;

				when cmd_WRITEDATA | cmd_WRITEDELETEDDATA =>
					if(WPRT='0')then
						sIC<="01";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sNW<='1';
						sHD<=HD;
						sUS<=US;
						PCN<=cPCN;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					elsif(READYn='1')then
						sHD<=HD;
						sUS<=US;
						sIC<="11";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sND<='0';
						sMA<='0';
						PCN<=cPCN;
						INT<='1';
						syncreq<='1';
						syncbusy_seen<='0';
						execstate<=es_sync;
					end if;
					case execstate is
					when es_seek =>
						if(seek_end(iUS)='1')then
							execstate<=es_wseek;
						elsif(seek_err(iUS)='1')then
							sIC<="01";
							sNR<=READYn;
							sEC<='1';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_idle;
						end if;
					when es_wseek =>
						if(seekbusy='0')then
							if(fmterr='1')then
								sHD<=HD;
								sUS<=US;
								sIC<="01";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sND<='1';
								sMA<='1';
								PCN<=cPCN;
								INT<='1';
								end_EXEC<='1';
								execstate<=es_IDLE;
							else
								if(ND='0')then
									DMARQ<='1';
								else
									sHD<=HD;
									sUS<=US;
									sNR<=READYn;
									sEC<='0';
									sSE<='0';
									PCN<=cPCN;
									sIC<="00";
									INT<='1';
								end if;
								sRQM<='1';
								sDIOd<='0';
								TCclr<='1';
								saddr<=(others=>'0');
								bytecount<=Ntolen(N,DTL);
								execstate<=es_DATA;
							end if;
						end if;
					when es_DATA =>
						if(TCen='1')then
							syncreq<='1';
							syncbusy_seen<='0';
							execstate<=es_sync;
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
						elsif(CPUWR_DAT='1' or DMAWRx='1')then
							sRQM<='0';
							wrdat<=CPUWRDAT;
							wrreq<='1';
							swait:=2;
							execstate<=es_DATAw;
						end if;
					when es_DATAw =>
						if(sectbusy='0' and txsft='1')then
							saddr<=saddr+1;
							if(bytecount>1)then
								bytecount<=bytecount-1;
								if(ND='0')then
									DMARQ<='1';
								else
									sHD<=HD;
									sUS<=US;
									sNR<=READYn;
									sEC<='0';
									sSE<='0';
									PCN<=cPCN;
									sIC<="00";
									INT<='1';
								end if;
								sRQM<='1';
								sDIOd<='0';
								execstate<=es_DATA;
							else
								execstate<=es_NXT;
							end if;
						end if;
					when es_NXT =>
						bytecount<=Ntolen(N,DTL);
						saddr<=(others=>'0');
						if(R<EOT)then
							incR<='1';
						elsif(MT='1')then
							if(HD='0')then
								resR<='1';
								setH<='1';
								setHD<='1';
							else
								resR<='1';
								resH<='1';
								resHD<='1';
								incC<='1';
							end if;
							if(ND='0')then
								DMARQ<='1';
							else
								sHD<=HD;
								sUS<=US;
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								PCN<=cPCN;
								sIC<="00";
								INT<='1';
							end if;
							sRQM<='1';
							sDIOd<='0';
							TCclr<='1';
							saddr<=(others=>'0');
							bytecount<=Ntolen(N,DTL);
							execstate<=es_DATA;
						else

							wrapR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
						end if;
					when es_waitTC =>
						if(TCen='1' or TCtcount=0)then
							if(TCtcount=0)then sEN<='1'; end if;
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							syncreq<='1';
							syncbusy_seen<='0';
							execstate<=es_sync;
						else
							TCtcount<=TCtcount-1;
						end if;
					when others=>
						syncreq<='1';
						syncbusy_seen<='0';
						execstate<=es_sync;
						end_EXEC<='1';
					end case;

				when cmd_READID =>
					if(READYn='1')then
						sHD<=HD;
						sUS<=US;
						sIC<="11";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sND<='0';
						sMA<='0';
						PCN<=cPCN;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					end if;
					case execstate is
					when es_wseek =>
						if(seekbusy='0')then
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								INT<='1';
								setC<='1';
								setH<='1';
								setR<='1';
								setN<='1';
								if(conv_integer(ridcnt)+1 >= conv_integer(sectspt))then
									ridcnt<=(others=>'0');
								else
									ridcnt<=ridcnt+1;
								end if;
								end_EXEC<='1';
								execstate<=es_IDLE;
						end if;
					when others =>
						execstate<=es_idle;
					end case;

				when cmd_SCANEQUAL | cmd_SCANLOWEQUAL| cmd_SCANHIGHEQUAL =>
					if(READYn='1')then
						sHD<=HD;
						sUS<=US;
						sIC<="11";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sND<='0';
						sMA<='0';
						PCN<=cPCN;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					end if;
					case execstate is
					when es_seek =>
						if(seek_end(iUS)='1')then
							execstate<=es_wseek;
						elsif(seek_err(iUS)='1')then
							sIC<="01";
							sNR<=READYn;
							sEC<='1';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_idle;
						end if;
					when es_wseek =>
						if(seekbusy='0')then
							if(fmterr='1')then
								sHD<=HD;
								sUS<=US;
								sIC<="01";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sND<='1';
								sMA<='1';
								PCN<=cPCN;
								INT<='1';
								end_EXEC<='1';
								execstate<=es_IDLE;
							else
								bytecount<=Ntolen(N,DTL);
								saddr<=(others=>'0');
								execstate<=es_DATA;
								swait:=2;
								rdreq<='1';
							end if;
						end if;
					when es_DATA =>
						if(TCen='1')then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(sectbusy='0' and txsft='1')then
							if(ND='0')then
								DMARQ<='1';
							else
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								INT<='1';
							end if;
							COMPDAT<=rddat;
							sDIOd<='0';
							sRQM<='1';
							execstate<=es_DATAw;
						end if;
					when es_DATAw =>
						if(CPUWR_DAT='1' or DMAWRx='1')then
							sRQM<='0';
							if(CPUWRDAT=x"ff" or CPUWRDAT=COMPDAT or scancomp='1')then
								saddr<=saddr+1;
								if(bytecount>1)then
									bytecount<=bytecount-1;
									execstate<=es_DATA;
									rdreq<='1';
									swait:=2;
								else
									execstate<=es_NXT;
								end if;
							elsif(COMPDAT<CPUWRDAT and command=cmd_SCANLOWEQUAL)then
								scancomp<='1';
								saddr<=saddr+1;
								if(bytecount>1)then
									bytecount<=bytecount-1;
									execstate<=es_DATA;
								else
									execstate<=es_NXT;
								end if;
							elsif(COMPDAT>CPUWRDAT and command=cmd_SCANHIGHEQUAL)then
								scancomp<='1';
								saddr<=saddr+1;
								if(bytecount>1)then
									bytecount<=bytecount-1;
									execstate<=es_DATA;
								else
									execstate<=es_NXT;
								end if;
							else
								sOR<='0';
								sIC<="01";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								INT<='1';
								end_EXEC<='1';
								execstate<=es_IDLE;
							end if;
						end if;
					when es_NXT =>
						saddr<=(others=>'0');
						bytecount<=Ntolen(N,DTL);
						if(scancomp='0')then
							sSH<='1';
						else
							sSH<='0';
						end if;
						if(R<EOT)then
							incR<='1';
							saddr<=(others=>'0');
							execstate<=es_DATA;
							swait:=2;
							rdreq<='1';
						elsif(MT='1')then
							if(HD='0')then
								resR<='1';
								setH<='1';
								setHD<='1';
								saddr<=(others=>'0');
								execstate<=es_DATA;
								swait:=2;
								rdreq<='1';
							else
								resR<='1';
								resH<='1';
								resHD<='1';
								incC<='1';
								TCtcount<=TCtout;
								execstate<=es_waitTC;
							end if;
						else
							wrapR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
						end if;
						sDE<='0';
					when es_waitTC =>
						if(TCen='1' or TCtcount=0)then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						else
							TCtcount<=TCtcount-1;
						end if;
					when others =>
						execstate<=es_idle;
					end case;

				when cmd_FORMATATRACK =>
					if(WPRT='0')then
						sIC<="01";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sNW<='1';
						sHD<=HD;
						sUS<=US;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					elsif(READYn='1')then
						sHD<=HD;
						sUS<=US;
						sIC<="11";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sND<='0';
						sMA<='0';
						PCN<=cPCN;
						INT<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					end if;
					case execstate is
					when es_wseek =>
						if(seekbusy='0')then
							if(fmterr='1')then
								sHD<=HD;
								sUS<=US;
								sIC<="01";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sND<='1';
								sMA<='1';
								PCN<=cPCN;
								INT<='1';
								end_EXEC<='1';
								execstate<=es_IDLE;
							else
								resR<='1';
								if(ND='0')then
									DMARQ<='1';
								else
									sHD<=HD;
									sUS<=US;
									PCN<=cPCN;
									sIC<="00";
									sNR<=READYn;
									sEC<='0';
									sSE<='0';
									INT<='1';
								end if;
								sRQM<='1';
								sDIOd<='0';
								execstate<=es_C;
							end if;
						end if;
					when es_C | es_H | es_R | es_N =>
						if(CPUWR_DAT='1' or DMAWRx='1')then
							sRQM<='0';
							case execstate is
							when es_C =>
								execstate<=es_Cw;
							when es_H =>
								execstate<=es_Hw;
							when es_R =>
								execstate<=es_Rw;
							when es_N =>
								execstate<=es_Nw;
							when others =>
								end_EXEC<='1';
								execstate<=es_IDLE;
							end case;
						end if;
					when es_Cw | es_Hw | es_Rw =>
						if(txsft='1')then
							if(ND='0')then
								DMARQ<='1';
							else
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								INT<='1';
							end if;
							sRQM<='1';
							sDIOd<='0';
							case execstate is
							when es_Cw =>
								execstate<=es_H;
							when es_Hw =>
								execstate<=es_R;
							when es_Rw =>
								execstate<=es_N;
							when others =>
								end_EXEC<='1';
								execstate<=es_IDLE;
							end case;
						end if;
					when es_Nw =>
						saddr<=(others=>'0');
						bytecount<=Ntolen(N,DTL);
						execstate<=es_DATA;
					when es_DATA =>
						wrdat<=D;
						wrreq<='1';
						swait:=2;
						execstate<=es_DATAw;
					when es_DATAw =>
						if(sectbusy='0' and txsft='1')then
							saddr<=saddr+1;
							if(bytecount>1)then
								bytecount<=bytecount-1;
								execstate<=es_DATA;
							else
								execstate<=es_NXT;
							end if;
						end if;
					when es_NXT =>
						saddr<=(others=>'0');
						bytecount<=Ntolen(N,DTL);
						if(cntR<SC)then
							incR<='1';
							if(ND='0')then
								DMARQ<='1';
							else
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								INT<='1';
							end if;
							sRQM<='1';
							sDIOd<='0';
							cntR<=cntR+x"01";
							execstate<=es_C;
						else
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							INT<='1';
							end_EXEC<='1';
							syncreq<='1';
							syncbusy_seen<='0';
							execstate<=es_sync;
						end if;
					when others=>
						execstate<=es_idle;
					end case;

				when cmd_RECALIBRATE | cmd_SEEK =>
					case execstate is
					when es_readychk =>
						if(READYn='0')then
							case command is
							when cmd_RECALIBRATE =>
								seek_init<='1';
							when cmd_SEEK =>
								seek_bgn<='1';
							when others =>
							end case;
							execstate<=es_seek;
						else
							sHD<=HD;
							sUS<=US;
							sIC<="11";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sND<='0';
							sMA<='0';
							PCN<=cPCN;
							INT<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						end if;
					when es_seek =>
						sRQM<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
					when others=>
						execstate<=es_IDLE;
					end case;
				when others=>
					execstate<=es_idle;
					end_EXEC<='1';
				end case;
			end if;
		end if;
	end process;
	
	sectaddr<=saddr;
	
	sksft	:sftdiv generic map(4) port map(
		sel		=>not SRT,
		sftin	=>hmssft,
		sftout	=>seek_sft,
		clk		=>clk,
		rstn	=>rstn
	);

	iC<=conv_integer(C);

	seekcnt	:seekcont generic map(maxtrack) port map(
		uselin	=>US,
		inireq	=>seek_init,
		seekreq	=>seek_bgn,
		destin	=>iC,
		iniout	=>seek_initv,
		seekout	=>seek_bgnv,
		dest0	=>iCx(0),
		dest1	=>iCx(1),
		dest2	=>iCx(2),
		dest3	=>iCx(3),
		readyin	=>seekReadyin,
		sendin	=>seek_endv,
		serrin	=>seek_errv,
		readyout	=>sREADYn,
		seek_end	=>seek_end,
		seek_err	=>seek_err,
		seek_pend	=>seekpend,
		busy	=>seekbusy,
		uselout	=>seekusel,
		clk		=>clk,
		rstn	=>rstn
	);
	
	dUS<=seekusel when seekbusy='1' else US;
	idUS<=conv_integer(dUS);
	
	iseekusel<=conv_integer(seekusel);
	seeks	:for i in 0 to 3 generate

		seek_cylx(i)<=iCx(i);
		seek_sftx(i)<='1' when seekwait='0' and iseekusel=i else seek_sft when iseekusel=i else '0';
		hdsx	:heademu generic map(maxtrack,30,0) port map(
			desttrack	=>seek_cylx(i),
			destset		=>seek_bgnv(i),
			setwait		=>30,
			curtrack	=>seek_curx(i),
			reachtrack	=>seek_endv(i),
			busy		=>seek_busyv(i),
			track0n		=>track0nb(i),
			init		=>seek_initv(i),
			seekerr		=>seek_errv(i),
			sft			=>seek_sftx(i),
			clk			=>clk,
			rstn		=>rstn
		);
		
		track0n(i)<=track0nb(i) when i<drives else '1';
		PCNx(i)<=conv_std_logic_vector(seek_curx(i),8);

	end generate;

	process(clk,rstn)begin
		if(rstn='0')then
			sDxB<=(others=>'0');
		elsif(clk' event and clk='1')then
			for i in 0 to 3 loop
				if(seek_busyv(i)='1')then
					sDxB(i)<='1';
				end if;
				if(seekpend(i)='1')then
					sDxB(i)<='1';
				end if;
			end loop;
			if(DxBclr='1')then
				sDxB<=(others=>'0');
			end if;
		end if;
	end process;
	cPCN<=	PCNx(iUS);

	track0ns<=track0n(idUS);
	head<=HD;
	
	sect<=	conv_std_logic_vector(0,wsect)                  when (is2hs='1' and R=x"01") else
			conv_std_logic_vector(conv_integer(R)-10,wsect) when (is2hs='1' and R>=x"0A") else
			R(wsect-1 downto 0)-1;
			
	track<=conv_std_logic_vector(seek_curx(iUS),wtrack);
	sectsize<=	"00" when N=x"00" else
				"01" when N=x"01" else
				"10" when N=x"02" else
				"11";
	mfm<=MF;
	rxC<=conv_std_logic_vector(seek_curx(iUS),8);
	rxR<=	conv_std_logic_vector(1,8)  when (is2hs='1' and seek_curx(iUS)=0 and HD='0' and ridcnt=conv_std_logic_vector(0,wsect)) else
			conv_std_logic_vector(conv_integer(ridcnt)+10,8) when is2hs='1' else
			conv_std_logic_vector(conv_integer(ridcnt)+1,8);
	busy<='1' when seekbusy='1'else
			'1' when execstate/=es_IDLE else
			'0';

end rtl;
