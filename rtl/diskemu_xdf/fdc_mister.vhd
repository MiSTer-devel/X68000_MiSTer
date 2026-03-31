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
	ready		:in std_logic;
	
	rxN		:in std_logic_vector(7 downto 0);
	
	seekwait	:std_logic;
	txwait		:std_logic;
	ismode	:in std_logic	:='1';
	busy		:out std_logic;

	hmssft	:in std_logic;		--0.5msec
	bitsft	:in std_logic;
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
signal	track0n		:std_logic_vector(3 downto 0);
signal	track0nb		:std_logic_vector(3 downto 0);
signal	track0ns		:std_logic;
signal	READYn		:std_logic;

signal	IOWR_DAT	:std_logic;
signal	IORD_DAT	:std_logic;
signal	IORD_STA	:std_logic;
signal	lIOWR_DAT	:std_logic;
signal	lIORD_DAT	:std_logic;
signal	lIORD_STA	:std_logic;
signal	datnum		:integer range 0 to 20;
signal	CPUWR_DAT	:std_logic;
signal	CPURD_DAT	:std_logic;
signal	CPURD_STA	:std_logic;
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
signal	DETSECT		:std_logic;
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
signal	GPL		:std_logic_vector(7 downto 0);
signal	HD		:std_logic;
signal	H		:std_logic_vector(7 downto 0);
signal	HLT		:std_logic_vector(6 downto 0);
signal	HUT		:std_logic_vector(3 downto 0);
signal	MF		:std_logic;
signal	MT		:std_logic;
signal	N		:std_logic_vector(7 downto 0);
signal	Nf		:std_logic_vector(7 downto 0);
signal	NCN		:integer range 0 to maxtrack;
signal	ND		:std_logic;
signal	R		:std_logic_vector(7 downto 0);
signal	cntR	:std_logic_vector(7 downto 0);
signal	RW		:std_logic;
signal	SC		:std_logic_vector(7 downto 0);
signal	SK		:std_logic;
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
signal	STP		:std_logic_vector(1 downto 0);
signal	RDDAT_DAT	:std_logic_vector(7 downto 0);
signal	saddr	:std_logic_vector(9 downto 0);

--status bit
signal	sIC		:std_logic_vector(1 downto 0);	--Interrupt Code
signal	sSE		:std_logic;						--Seek End
signal	sEC		:std_logic;						--Equipment Check
signal	sNR		:std_logic;						--Not Ready
signal	sHD		:std_logic;						--Head Address(when interrupt)
signal	sUS		:std_logic_vector(1 downto 0);	--Unit Select(when interrupt)
signal	sEN		:std_logic;						--End of Cylinder
signal	sDE		:std_logic;						--Data Error
signal	sOR		:std_logic;						--Over Run
signal	sND		:std_logic;						--No Data
signal	sNW		:std_logic;						--Not Writable
signal	sMA		:std_logic;						--Missing Address Mark
signal	sCM		:std_logic;						--Control Mark
signal	sDD		:std_logic;						--Data error in Data field(CRC)
signal	sWC		:std_logic;						--Wrong Cylinder
signal	sSH		:std_logic;						--Scan Equal Hit
signal	sSN		:std_logic;						--Scan Not Satisfied
signal	sBC		:std_logic;						--Bad Cylinder
signal	sMD		:std_logic;						--Missing Address Mark in Data Field

signal	sDxB	:std_logic_vector(3 downto 0);
signal	sCB		:std_logic;
signal	sEXM	:std_logic;
signal	sDIO	:std_logic;
signal	sRQM	:std_logic;
signal	MSR		:std_logic_vector(7 downto 0);

signal	sideb	:std_logic;
signal	uselb	:std_logic_vector(1 downto 0);
signal	DxBclr	:std_logic;
signal	SEclr	:std_logic;
signal	iSE		:std_logic;
signal	SISen	:std_logic;
signal	SISclr	:std_logic;
signal	dUS		:std_logic_Vector(1 downto 0);
signal	idUS		:integer range 0 to 3;

signal	sDIOc	:std_logic;
signal	sDIOd	:std_logic;

signal	TCclr		:std_logic;
signal	TCen,TCenb		:std_logic;


signal	INT		:std_logic;		--interrupt start
signal	INTs		:std_logic;		--interrput at seek/re-carib.
signal	DMARQ		:std_logic;		--DMA request start
signal	setC		:std_logic;
signal	incC		:std_logic;
signal	resH		:std_logic;
signal	setH		:std_logic;
signal	setR		:std_logic;
signal	incR		:std_logic;
signal	resR		:std_logic;
signal	setN		:std_logic;
signal	setHD		:std_logic;
signal	resHD		:std_logic;

signal	rxC			:std_logic_vector(7 downto 0);
signal	rxH			:std_logic_vector(7 downto 0);
signal	rxR			:std_logic_vector(7 downto 0);

signal	bytecount	:integer range 0 to 16384;

signal	seek_bgn	:std_logic;
signal	seek_end	:std_logic_vector(3 downto 0);
signal	seek_busy	:std_logic;
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
	setwait		:in integer range 0 to maxset;		--settling time
	
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
	READYn<=not ready;
	txsft<=	'1' when txwait='0' else bitsft;

	process(clk,rstn)
	begin
		if(rstn='0')then
			lIOWR_DAT<='0';
			lIORD_DAT<='0';
			lIORD_STA<='0';
			CPUWRDAT<=(others=>'0');
			CPUWR_DAT<='0';
			CPURD_DAT<='0';
			CPURD_STA<='0';
			DRQ<='0';
		elsif(clk' event and clk='1')then
			CPUWR_DAT<='0';
			CPURD_DAT<='0';
			CPURD_STA<='0';
			DMARDx<='0';
			DMAWRx<='0';
			if(IOWR_DAT='1')then
				CPUWRDAT<=WDAT;
			elsif(IOWR_DAT='0' and lIOWR_DAT='1')then
				CPUWR_DAT<='1';
			end if;
			if(IORD_DAT='0' and lIORD_DAT='1')then
				CPURD_DAT<='1';
			end if;
			if(IORD_STA='0' and lIORD_STA='1')then
				CPURD_STA<='1';
			end if;
			if(DMAWR='1')then
				CPUWRDAT<=WDAT;
			elsif(DMAWR='0' and lDMAWR='1')then
				DMAWRx<='1';
			end if;
			if(DMARD='0' and lDMARD='1')then
				DMARDx<='1';
			end if;
			if(DMARQ='1')then
				DRQ<='1';
			elsif(DACKn='0' or IORD_DAT='1' or IOWR_DAT='1')then
				DRQ<='0';
			end if;
			lIOWR_DAT<=IOWR_DAT;
			lIORD_DAT<=IORD_DAT;
			lIORD_STA<=IORD_STA;
			lDMAWR<=DMAWR;
			lDMARD<=DMARD;
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
			GPL		<=(others=>'0');
			HD		<='0';
			HLT		<=(others=>'0');
			HUT		<=(others=>'0');
			MF		<='0';
			MT		<='0';
			N		<=(others=>'0');
			NCN		<=0;
			ND		<='0';
			H		<=(others=>'0');
			R		<=(others=>'0');
			RW		<='0';
			SC		<=(others=>'0');
			SK		<='0';
			SRT		<=(others=>'0');
			STP		<=(others=>'0');
			US		<=(others=>'0');
			datnum	<=0;
			EXEC	<='0';
			RD_CMD	<='1';
			RDDAT_CMD<=(others=>'0');
			sDIOc	<='0';
			DxBclr	<='0';
			SEclr	<='0';
			SISclr	<='0';
		elsif(clk' event and clk='1')then 
			EXEC<='0';
			DxBclr	<='0';
			SEclr	<='0';
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
			elsif(resR='1')then
				R<=x"01";
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
						SK<=CPUWRDAT(5);
					when cmd_READDELETEDDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
						SK<=CPUWRDAT(5);
					when cmd_WRITEDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_WRITEDELETEDDATA =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
					when cmd_READATRACK =>
						MF<=CPUWRDAT(6);
						SK<=CPUWRDAT(5);
					when cmd_READID =>
						MF<=CPUWRDAT(6);
					when cmd_FORMATATRACK =>
						MF<=CPUWRDAT(6);
						R<=x"00";
					when cmd_SCANEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
						SK<=CPUWRDAT(5);
					when cmd_SCANLOWEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
						SK<=CPUWRDAT(5);
					when cmd_SCANHIGHEQUAL =>
						MT<=CPUWRDAT(7);
						MF<=CPUWRDAT(6);
						SK<=CPUWRDAT(5);
					when others=>
					end case;
					datnum<=1;
				end if;
			else
				case command is
				when cmd_READDATA | cmd_READDELETEDDATA | cmd_WRITEDATA | cmd_WRITEDELETEDDATA | cmd_READATRACK |
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
							GPL<=CPUWRDAT;
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
--							SEclr<='1';
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
--							SEclr<='1';
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
							RDDAT_CMD<=H;
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
							GPL<=CPUWRDAT;
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
--							SEclr<='1';
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
--							HD<='0';
							NCN<=0;
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
							SEclr<='1';
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
							HUT<=CPUWRDAT(3 downto 0);
							SRT<=CPUWRDAT(7 downto 4);
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							HLT<=CPUWRDAT(7 downto 1);
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
--							HD<='0';
							datnum<=datnum+1;
						end if;
					when 2 =>
						if(CPUWR_DAT='1')then
							NCN<=conv_integer(CPUWRDAT);
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
				when others =>		--Invalid
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
	ST3<='0' & not WPRT & READY & not track0ns & sideb & HD & uselb;
	MSR<=sRQM & sDIO & sEXM & sCB & sDxB;
	
	RDAT<=	RDDAT_DAT when DACKn='0' else
			MSR when A0='0' else
			RDDAT_CMD	when RD_CMD='1' else
			RDDAT_DAT;
	
	sDIO<=sDIOc when RD_CMD='1' else sDIOd;
	
	sideb<=HD;
	uselb<=US;
	process(idUS)begin
		unit<=(others=>'0');
		unit(idUS)<='1';
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
			elsif(CPUWR_DAT='1' or CPURD_DAT='1')then	-- or CPURD_STA='1' or DMARDx='1' or DMAWRx='1'
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
			iSE<='0';
			sSH<='0';
			wrdat<=(others=>'0');
			wrreq<='0';
			rdreq<='0';
			syncreq<='0';
			Nf<=(others=>'0');
			ecommand<=(others=>'0');
			COMPDAT<=(others=>'0');
			scancomp<='0';
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
					iSE<='1';
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
					iSE<='1';
				end if;
				if(EXEC='1')then
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
					sCM<='0';
					DETSECT<='0';
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
						seek_init<='1';
						execstate<=es_seek;
--						execstate<=es_readychk;
					when cmd_SEEK =>
--						seek_bgn<='1';
--						execstate<=es_seek;
						execstate<=es_readychk;
					when others=>
						end_EXEC<='1';
						execstate<=es_idle;
						sRQM<='1';
					end case;
				end if;
			elsif(execstate=es_sync)then
				if(sectbusy='0')then
					syncreq<='0';
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
						iSE<='0';
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
							iSE<='1';
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
								iSE<='0';
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
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
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
								iSE<='0';
							end if;
							RDDAT_DAT<=rddat;
							sDIOd<='1';
							sRQM<='1';
							execstate<=es_DATAw;
						end if;
					when es_DATAw =>
						if(CPURD_DAT='1' or DMARDx='1')then
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
								TCtcount<=TCtout;
								execstate<=es_waitTC;
								incC<='1';
							end if;
						else
							resR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
							incC<='1';
						end if;
						sDE<='0';
					when es_waitTC =>
						if(TCen='1')then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(TCtcount=0)then
							sEN<='1';
							sIC<="01";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
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
						iSE<='0';
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
						iSE<='0';
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
							iSE<='1';
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
								iSE<='0';
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
									iSE<='0';
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
							execstate<=es_sync;
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
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
									iSE<='0';
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
								iSE<='0';
							end if;
							sRQM<='1';
							sDIOd<='0';
							TCclr<='1';
							saddr<=(others=>'0');
							bytecount<=Ntolen(N,DTL);
							execstate<=es_DATA;
						else
							resR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
						end if;
					when es_waitTC =>
						if(TCen='1')then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(TCtcount=0)then
							sEN<='1';
							sIC<="01";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						else
							TCtcount<=TCtcount-1;
						end if;
					when others=>
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
						iSE<='0';
						end_EXEC<='1';
						execstate<=es_IDLE;
					end if;
					case execstate is
					when es_wseek =>
						if(seekbusy='0')then
--							if(fmterr='1')then
--								sHD<=HD;
--								sUS<=US;
--								sIC<="01";
--								sNR<=READYn;
--								sEC<='0';
--								sSE<='0';
--								sND<='1';
--								sMA<='1';
--								PCN<=cPCN;
--								INT<='1';
--								iSE<='0';
--								end_EXEC<='1';
--								execstate<=es_IDLE;
--							else
								sIC<="00";
								sNR<=READYn;
								sEC<='0';
								sSE<='0';
								sHD<=HD;
								sUS<=US;
								PCN<=cPCN;
								INT<='1';
								iSE<='0';
								setC<='1';
								setR<='1';
								setN<='1';
								end_EXEC<='1';
								execstate<=es_IDLE;
--							end if;
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
						iSE<='0';
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
							iSE<='1';
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
								iSE<='0';
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
							iSE<='1';
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
								iSE<='0';
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
								iSE<='0';
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
							resR<='1';
							incC<='1';
							TCtcount<=TCtout;
							execstate<=es_waitTC;
						end if;
						sDE<='0';
					when es_waitTC =>
						if(TCen='1')then
							sIC<="00";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						elsif(TCtcount=0)then
							sEN<='1';
							sIC<="01";
							sNR<=READYn;
							sEC<='0';
							sSE<='0';
							sHD<=HD;
							sUS<=US;
							PCN<=cPCN;
							INT<='1';
							iSE<='1';
							end_EXEC<='1';
							execstate<=es_IDLE;
						else
							TCtcount<=TCtcount-1;
						end if;
					when others =>
						execstate<=es_idle;
					end case;

				when cmd_FORMATATRACK =>		--Format a Track
					if(WPRT='0')then
						sIC<="01";
						sNR<=READYn;
						sEC<='0';
						sSE<='0';
						sNW<='1';
						sHD<=HD;
						sUS<=US;
						INT<='1';
						iSE<='0';
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
						iSE<='0';
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
								iSE<='0';
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
									iSE<='0';
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
								Nf<=CPUWRDAT;
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
								iSE<='0';
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
								iSE<='0';
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
							iSE<='0';
							end_EXEC<='1';
							execstate<=es_IDLE;
						end if;
					when others=>
						execstate<=es_idle;
					end case;
				when cmd_RECALIBRATE | cmd_SEEK =>		--re-calibrate  / seek
					case execstate is
					when es_readychk =>
						if(ready='1')then
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
							iSE<='0';
							end_EXEC<='1';
							execstate<=es_IDLE;
						end if;
					when es_seek =>
						sRQM<='1';
						end_EXEC<='1';
						execstate<=es_IDLE;
--						if(seek_end(iUS)='1')then
--							execstate<=es_IDLE;
--							sHD<=HD;
--							sUS<=US;
--							PCN<=cPCN;
--							sIC<="00";
--							sNR<=READYn;
--							sEC<='0';
--							sSE<='1';
--							INTs<='1';
--							iSE<='1';
--							sRQM<='1';
--							end_EXEC<='1';
--						elsif(seek_err(iUS)='1')then
--							sIC<="01";
--							sNR<=READYn;
--							sEC<='1';
--							sSE<='0';
--							sHD<=HD;
--							sUS<=US;
--							PCN<=cPCN;
--							INTs<='1';
--							iSE<='1';
--							sRQM<='1';
--							end_EXEC<='1';
--							execstate<=es_idle;
--						end if;
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
		readyin	=>READYn,
		
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
	
--	process(seek_sft,iUS)begin
--		for i in 0 to drives-1 loop
--			if(iUS=i)then
--				seek_sft(i)<=seel_sft;
--			else
--				seek_sft(i)<='0';
--			end if;
--		end loop;
--	end process;
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
	seek_busy<=	seek_busyv(iseekusel);

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
	head<=H(0);
	sect<=R(wsect-1 downto 0)-1;
	track<=conv_std_logic_vector(seek_curx(iUS),wtrack);
	sectsize<=	"00" when N=x"00" else
				"01" when N=x"01" else
				"10" when N=x"02" else
				"11";
	mfm<=MF;
	rxC<=conv_std_logic_vector(seek_curx(iUS),8);
	rxH<=	x"00" when HD='0' else x"01";
	rxR<=x"01";
	
	busy<='1' when seekbusy='1'else
			'1' when execstate/=es_IDLE else
			'0';
	
end rtl;
