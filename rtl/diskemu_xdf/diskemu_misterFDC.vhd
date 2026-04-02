LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity diskemu_misterFDC is
generic(
	sclkfreq		:integer	:=10000;
	fdc_TCtout		:integer	:=100;
	fdc_wtrack		:integer	:=7;
	fdc_wsect	:integer	:=5
);
port(

--SASI
	sasi_din	:in std_logic_vector(7 downto 0)	:=(others=>'0');
	sasi_dout:out std_logic_vector(7 downto 0);
	sasi_sel	:in std_logic						:='0';
	sasi_bsy	:out std_logic;
	sasi_req	:out std_logic;
	sasi_ack	:in std_logic						:='0';
	sasi_io	:out std_logic;
	sasi_cd	:out std_logic;
	sasi_msg	:out std_logic;
	sasi_rst	:in std_logic						:='0';

--FDD
	fdc_tracks	:in std_logic_vector(fdc_wtrack-1 downto 0);
	fdc_sects	:in std_logic_vector(fdc_wsect-1 downto 0);
	
	fdc_RDn		:in std_logic;
	fdc_WRn		:in std_logic;
	fdc_CSn		:in std_logic;
	fdc_A0		:in std_logic;
	fdc_WDAT	:in std_logic_vector(7 downto 0);
	fdc_RDAT	:out std_logic_vector(7 downto 0);
	fdc_DATOE	:out std_logic;
	fdc_DACKn	:in std_logic;
	fdc_DRQ		:out std_logic;
	fdc_TC		:in std_logic;
	fdc_INTn	:out std_logic;
	fdc_WAITIN	:in std_logic	:='0';
	
	fdc_indisk	:out std_logic_vector(1 downto 0);
	fdc_usel		:out std_logic_vector(1 downto 0);
	fdc_mfm		:out std_logic;
	fdc_sectsize:out std_logic_vector(1 downto 0);
	fdc_ready	:in std_logic;
	fdc_hmssft	:in std_logic;
	fdc_bitsft	:in std_logic;
	fdc_fmterr	:in std_logic;
	fdc_eject	:in std_logic_Vector(1 downto 0)	:=(others=>'0');
	fdc_seekwait:in std_logic;
	fdc_txwait	:in std_logic;
	fdc_ismode	:in std_logic	:='1';
	
	fdc_rxN		:in std_logic_Vector(7 downto 0);

	
--SRAM
	sram_cs		:in std_logic						:='0';
	sram_addr	:in std_logic_vector(12 downto 0)	:=(others=>'0');
	sram_rdat	:out std_logic_vector(15 downto 0);
	sram_wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	sram_rd		:in std_logic						:='0';
	sram_wr		:in std_logic_vector(1 downto 0)	:="00";
	sram_wp		:in std_logic						:='0';
	
	sram_ld		:in std_logic;
	sram_st		:in std_logic;

--MiSTer diskimage
	mist_mounted	:in std_logic_vector(3 downto 0);	--SRAM & HDD & FDD1 &FDD0
	mist_readonly	:in std_logic_vector(3 downto 0);
	mist_imgsize	:in std_logic_vector(63 downto 0);

	mist_lba		:out std_logic_vector(31 downto 0);
	mist_rd		:out std_logic_vector(3 downto 0);
	mist_wr		:out std_logic_vector(3 downto 0);
	mist_ack		:in std_logic_vector(3 downto 0);

	mist_buffaddr	:in std_logic_vector(8 downto 0);
	mist_buffdout	:in std_logic_vector(7 downto 0);
	mist_buffdin	:out std_logic_vector(7 downto 0);
	mist_buffwr		:in std_logic;
	
--common
	initdone	:out std_logic;
	busy		:out std_logic;
	sclk		:in std_logic;
	prstn		:in std_logic;
	srstn		:in std_logic
);
end diskemu_misterFDC;

architecture rtl of diskemu_misterFDC is

type emustate_t is (
	es_IDLE,
	es_fdc,
	es_sasi,
	es_sload,
	es_ssave
);
signal	emustate	:emustate_t;


constant allzero	:std_logic_vector(63 downto 0)	:=(others=>'0');

signal	fdcdone	:std_logic;
signal	sasidone :std_logic;
signal	sramdone :std_logic;
signal	proc_begin	:std_logic;

constant bit_fd0	:integer	:=0;
constant bit_fd1	:integer	:=1;
constant bit_sasi	:integer	:=2;
constant bit_sram	:integer	:=3;


type sbufstate_t is (
	ss_idle,
	ss_rwrite,
	ss_rwrite2,
	ss_read,
	ss_read2,
	ss_wread,
	ss_wread2,
	ss_write,
	ss_write2,
	ss_sync,
	ss_sync2,
	ss_dimhdr,
	ss_dimhdr2,
	ss_dimhdr2b,
	ss_dimhdr3
);
signal	fdcbufstate	:sbufstate_t;
signal	sasibufstate:sbufstate_t;
--FDC
signal	fdc_bufodat	:std_logic_vector(7 downto 0);
signal	fdc_indiskb	:std_logic_vector(1 downto 0);
signal	fdc_bufbusy	:std_logic;
signal	fdc_rdreq	:std_logic;
signal	fdc_wrreq	:std_logic;
signal	fdc_syncreq	:std_logic;
signal	fdc_unit	:std_logic_Vector(1 downto 0);
signal	fdc_track	:std_logic_Vector(fdc_wtrack-1 downto 0);
signal	fdc_head	:std_logic;
signal	fdc_sect	:std_logic_vector(fdc_wsect-1 downto 0);
signal	fdc_sectsizeb:std_logic_vector(1 downto 0);
signal	fdc_sectaddr:std_logic_vector(9 downto 0);
signal	fdc_sectwrdat	:std_logic_vector(7 downto 0);
signal	fdc_sectrddat	:std_logic_vector(7 downto 0);
signal	fdc_rdreq2	:std_logic_vector(1 downto 0);
signal	fdc_wrreq2	:std_logic_vector(1 downto 0);
signal	fdc_syreq2	:std_logic_vector(1 downto 0);
signal	fdc_readonly:std_logic_vector(1 downto 0);
signal	fdc_readonlys:std_logic;
signal	fdcbufwr	:std_logic;

signal	fdc_lba		:std_logic_vector(31 downto 0);
signal	fdc_lbapos	:std_logic_vector(8 downto 0);
signal	fdc_lba_raw	:std_logic_vector(31 downto 0);
signal	fdc_lbapos_raw	:std_logic_vector(8 downto 0);
signal	is_dim		:std_logic_vector(1 downto 0);
signal	dim_active	:std_logic;
signal	dim_byte_addr	:std_logic_vector(20 downto 0);
signal	dim_hdr_req2	:std_logic_vector(1 downto 0);
signal	dim_hdr_reading	:std_logic;
signal	dim_hdr_funit	:integer range 0 to 1;
signal	dim_sects_0		:std_logic_vector(fdc_wsect-1 downto 0);
signal	dim_sects_1		:std_logic_vector(fdc_wsect-1 downto 0);
signal	dim_rxN_0		:std_logic_vector(7 downto 0);
signal	dim_rxN_1		:std_logic_vector(7 downto 0);
signal	active_sects	:std_logic_vector(fdc_wsect-1 downto 0);
signal	active_rxN		:std_logic_vector(7 downto 0);
signal	buf_addr2		:std_logic_vector(8 downto 0);
signal	fdcsectwr	:std_logic;
signal	fdc_sectamod	:std_logic_vector(8 downto 0);
signal	lba_fdc			:std_logic_vector(31 downto 0);
signal	cur_flba		:std_logic_vector(31 downto 0);
signal	fdc_lunit		:integer range 0 to 2;
signal	fdc_punit		:integer range 0 to 2;
signal	fdc_cunit		:integer range 0 to 2;

signal	fdc_busy		:std_logic;
--SASI
signal	sasien		:std_logic;
signal	sasi_idsel	:std_logic_vector(7 downto 0);
signal	sasi_cap		:std_logic_vector(63 downto 0);
signal	sasi_lba		:std_logic_vector(20 downto 0);
signal	sasi_sectaddr	:std_logic_vector(7 downto 0);
signal	sasisectwr	:std_logic;
signal	sasibufwr	:std_logic;
signal	sasi_rdreq	:std_logic;
signal	sasi_wrreq	:std_logic;
signal	sasi_syncreq:std_logic;
signal	sasi_bufbusy	:std_logic;
signal	sasi_sectwrdat	:std_logic_vector(7 downto 0);
signal	sasi_sectrddat	:std_logic_vector(7 downto 0);
signal	sasi_rdreq2	:std_logic;
signal	sasi_wrreq2	:std_logic;
signal	sasi_syreq2	:std_logic;
signal	sasi_bufodat	:std_logic_vector(7 downto 0);
signal	lba_sasi		:std_logic_vector(31 downto 0);
signal	cur_slba		:std_logic_vector(31 downto 0);

--SRAM
signal	lba_sram		:std_logic_vector(31 downto 0);
signal	sram_bufwr	:std_logic;
signal	sram_bufout	:std_logic_Vector(7 downto 0);
signal	sramwr	:std_logic_vector(1 downto 0);
signal	sram_ldreq	:std_logic;
signal	sram_streq	:std_logic;
signal	sramen	:std_logic;


component dpssram is
generic(
	awidth	:integer	:=8;
	dwidth	:integer	:=8
);
port(
	addr1	:in std_logic_vector(awidth-1 downto 0);
	wdat1	:in std_logic_vector(dwidth-1 downto 0);
	wr1	:in std_logic;
	rdat1	:out std_logic_vector(dwidth-1 downto 0);
	
	addr2	:in std_logic_vector(awidth-1 downto 0);
	wdat2	:in std_logic_vector(dwidth-1 downto 0);
	wr2	:in std_logic;
	rdat2	:out std_logic_vector(dwidth-1 downto 0);
	
	clk	:in std_logic
);
end component;

component fdc_mister
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
	
	seekwait		:in std_logic;
	txwait		:in std_logic;
	ismode	:in std_logic	:='1';
	
	busy		:out std_logic;

	hmssft	:in std_logic;		--0.5msec
	bitsft	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component fdc_calclba
generic(
	wtrack	:integer	:=7;
	wsect	:integer	:=5;
	wssize	:integer	:=10
);
port(
	tracks	:in std_logic_vector(wtrack-1 downto 0);
	sectsize:in std_logic_vector(1 downto 0);	--00:128 01:256 10:512 11:1024
	sects	:in std_logic_vector(wsect-1 downto 0);
	
	track	:in std_logic_vector(wtrack-1 downto 0);
	head	:in std_logic;
	sect	:in std_logic_vector(wsect-1 downto 0);
	spos	:in std_logic_vector(wssize-1 downto 0);
	
	lba		:out std_logic_vector(31 downto 0);
	lbapos	:out std_logic_vector(8 downto 0)
);
end component;

component sasidev
port(
	IDAT		:in std_logic_vector(7 downto 0);
	ODAT		:out std_logic_vector(7 downto 0);
	SEL		:in std_logic;
	BSY		:out std_logic;
	REQ		:out std_logic;
	ACK		:in std_logic;
	IO			:out std_logic;
	CD			:out std_logic;
	MSG		:out std_logic;
	RST		:in std_logic;
	
	idsel		:in std_logic_vector(7 downto 0);
	
	id			:out std_logic_vector(2 downto 0);
	unit		:out std_logic_vector(2 downto 0);
	capacity	:in std_logic_vector(63 downto 0);
	lba		:out std_logic_vector(20 downto 0);
	rdreq		:out std_logic;
	wrreq		:out std_logic;
	syncreq	:out std_logic;
	sectaddr	:out std_logic_vector(7 downto 0);
	rddat		:in std_logic_vector(7 downto 0);
	wrdat		:out std_logic_vector(7 downto 0);
	sectbusy	:in std_logic;
	
	clk		:in std_logic;
	rstn		:in std_logic
);
end component;

component sramcont
port(
	addr	:in std_logic_vector(12 downto 0);
	rdat	:out std_logic_vector(15 downto 0);
	wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	wr		:in std_logic_vector(1 downto 0)	:="00";
	
	ldreq	:in std_logic;
	streq	:in std_logic;
	done	:out std_logic;

	mist_rd	:out std_logic;
	mist_wr	:out std_logic;
	mist_ack:in std_logic;
	
	mist_lba	:out std_logic_vector(31 downto 0);
	mist_addr	:in std_logic_vector(8 downto 0);
	mist_wdat	:in std_logic_vector(7 downto 0);
	mist_rdat	:out std_logic_vector(7 downto 0);
	mist_we		:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin
	

	initdone<=srstn;
	
	mist_lba<=	lba_fdc when emustate=es_fdc else
				lba_sasi when emustate=es_sasi else
				lba_sram when emustate=es_sload else
				lba_sram when emustate=es_ssave else
				(others=>'0');
	
	
	sasi_idsel<=	"00000001" when sasien='1' else
						"00000000";
	
	fdc		:fdc_mister generic map(
		maxtrack	=>85,
		preseek		=>'0',
		drives		=>2,
		wtrack		=>fdc_wtrack,
		wsect		=>fdc_wsect,
		TCtout	=>fdc_TCtout,
		sfreq		=>sclkfreq/1000
	)port map(
		RDn		=>fdc_RDn,
		WRn		=>fdc_WRn,
		CSn		=>fdc_CSn,
		A0		=>fdc_A0,
		WDAT	=>fdc_WDAT,
		RDAT	=>fdc_RDAT,
		DATOE	=>fdc_DATOE,
		DACKn	=>fdc_DACKn,
		DRQ		=>fdc_DRQ,
		TC		=>fdc_TC,
		INTn	=>fdc_INTn,
		WAITIN	=>fdc_WAITIN,

		unit		=>fdc_unit,
		track		=>fdc_track,
		head		=>fdc_head,
		sect		=>fdc_sect,
		sectsize	=>fdc_sectsizeb,
		rdreq		=>fdc_rdreq,
		wrreq		=>fdc_wrreq,
		syncreq		=>fdc_syncreq,
		sectaddr	=>fdc_sectaddr,
		rddat		=>fdc_sectrddat,
		wrdat		=>fdc_sectwrdat,
		mfm			=>fdc_mfm,
		sectbusy	=>fdc_bufbusy,
		readonly	=>fdc_readonlys,
		fmterr		=>fdc_fmterr,
		ready		=>fdc_ready,

		rxN		=>active_rxN,
	
		seekwait	=>fdc_seekwait,
		txwait		=>fdc_txwait,
		ismode		=>fdc_ismode,
		
		busy		=>fdc_busy,

		hmssft	=>fdc_hmssft,
		bitsft	=>fdc_bitsft,
		clk		=>sclk,
		rstn	=>prstn
	);
	
	fdc_readonlys<=	fdc_readonly(0) when fdc_unit(0)='1' else
					fdc_readonly(1) when fdc_unit(1)='1' else
					'0';
	
	active_sects <= dim_sects_0 when is_dim(0)='1' and fdc_unit(0)='1' else
	                dim_sects_1 when is_dim(1)='1' and fdc_unit(1)='1' else
	                fdc_sects;
	active_rxN <= dim_rxN_0 when is_dim(0)='1' and fdc_unit(0)='1' else
	              dim_rxN_1 when is_dim(1)='1' and fdc_unit(1)='1' else
	              fdc_rxN;
	buf_addr2 <= (others=>'0') when dim_hdr_reading='1' else fdc_lbapos;

	fdclba	:fdc_calclba generic map(
		wtrack	=>fdc_wtrack,
		wsect	=>fdc_wsect
	)port map(
		tracks	=>fdc_tracks,
		sectsize=>fdc_sectsizeb,
		sects	=>active_sects,
		
		track	=>fdc_track,
		head	=>fdc_head,
		sect	=>fdc_sect,
		spos	=>fdc_sectaddr,
		
		lba		=>fdc_lba_raw,
		lbapos	=>fdc_lbapos_raw
	);
	dim_active <= (fdc_unit(0) and is_dim(0)) or (fdc_unit(1) and is_dim(1));
	dim_byte_addr <= (fdc_lba_raw(11 downto 0) & fdc_lbapos_raw) + ("000000000000" & dim_active & "00000000");
	fdc_lba <= x"00000" & dim_byte_addr(20 downto 9);
	fdc_lbapos <= dim_byte_addr(8 downto 0);

	fdc_usel<=	"00" when fdc_unit="01" else
					"01" when fdc_unit="10" else
					"11";
	
	fdc_sectsize<=fdc_sectsizeb;

	fdcsectwr<=		mist_buffwr when emustate=es_fdc else '0';
	fdc_sectamod<=	fdc_sectaddr(8 downto 0);
	fdcbuf	:dpssram generic map(9,8)port map(
		addr1	=>mist_buffaddr,
		wdat1	=>mist_buffdout,
		wr1	=>fdcsectwr,
		rdat1	=>fdc_bufodat,

		addr2	=>buf_addr2,
		wdat2	=>fdc_sectwrdat,
		wr2	=>fdcbufwr,
		rdat2	=>fdc_sectrddat,
		
		clk		=>sclk
	);

	fdc_cunit<=	0	when fdc_rdreq2="01" else
				0	when fdc_wrreq2="01" else
				0	when fdc_syreq2="01" else
				1	when fdc_rdreq2="10" else
				1	when fdc_wrreq2="10" else
				1	when fdc_syreq2="10" else
				2;

	process(sclk,srstn)
	variable wrote	:std_logic;
	variable swait	:integer range 0 to 2;
	begin
		if(srstn='0')then
			fdcbufstate<=ss_idle;
			lba_fdc<=(others=>'0');
			cur_flba<=(others=>'1');
			wrote:='0';
			mist_rd(bit_fd1 downto bit_fd0)<=(others=>'0');
			mist_wr(bit_fd0 downto bit_fd0)<=(others=>'0');
			fdcbufwr<='0';
			fdcdone<='0';
			swait:=0;
			fdc_lunit<=2;
			dim_hdr_reading<='0';
			dim_hdr_funit<=0;
			dim_sects_0<="01000";
			dim_sects_1<="01000";
			dim_rxN_0<=x"03";
			dim_rxN_1<=x"03";
		elsif(sclk' event and sclk='1')then
			fdcbufwr<='0';
			fdcdone<='0';
			if(swait>0)then
				swait:=swait-1;
			else
				case fdcbufstate is
				when ss_idle =>
					if(dim_hdr_req2/="00")then
						-- DIM header read: read LBA 0 to get type byte
						wrote:='0';
						cur_flba<=(others=>'1');
						fdc_lunit<=2;
						lba_fdc<=(others=>'0');
						if(dim_hdr_req2(0)='1')then
							mist_rd(bit_fd0)<='1';
							dim_hdr_funit<=0;
						else
							mist_rd(bit_fd1)<='1';
							dim_hdr_funit<=1;
						end if;
						fdcbufstate<=ss_dimhdr;
					elsif(fdc_rdreq2/="00")then
						fdc_punit<=fdc_cunit;
						if(fdc_lba/=cur_flba or fdc_cunit/=fdc_lunit)then
							if(wrote='1')then
								case fdc_lunit is
								when 0 =>
									mist_wr(bit_fd0)<='1';
								when 1 =>
									mist_wr(bit_fd1)<='1';
								when others =>
								end case;
								fdcbufstate<=ss_rwrite;
							else
								cur_flba<=fdc_lba;
								fdc_lunit<=fdc_cunit;
								lba_fdc<=fdc_lba;
								case fdc_cunit is
								when 0 =>
									mist_rd(bit_fd0)<='1';
								when 1 =>
									mist_rd(bit_fd1)<='1';
								when others =>
								end case;
								fdcbufstate<=ss_read;
							end if;
						else
							fdcdone<='1';
						end if;
					elsif(fdc_wrreq2/="00")then
						fdc_punit<=fdc_cunit;
						if(fdc_lba=cur_flba and fdc_cunit=fdc_lunit)then
							fdcbufwr<='1';
							fdcdone<='1';
						else
							if(wrote='1')then
								case fdc_lunit is
								when 0 =>
									mist_wr(bit_fd0)<='1';
								when 1 =>
									mist_wr(bit_fd1)<='1';
								when others =>
								end case;
								fdcbufstate<=ss_write;
							else
								cur_flba<=fdc_lba;
								lba_fdc<=fdc_lba;
								fdc_lunit<=fdc_cunit;
								case fdc_cunit is
								when 0 =>
									mist_rd(bit_fd0)<='1';
								when 1 =>
									mist_rd(bit_fd1)<='1';
								when others =>
								end case;
								fdcbufstate<=ss_wread;
							end if;
						end if;
					elsif(fdc_syreq2/="00")then
						fdc_punit<=fdc_cunit;
						if(wrote='1')then
							case fdc_lunit is
							when 0 =>
								mist_wr(bit_fd0)<='1';
							when 1 =>
								mist_wr(bit_fd1)<='1';
							when others =>
							end case;
							fdcbufstate<=ss_sync;
						else
							fdcdone<='1';
						end if;
					end if;
				when ss_rwrite =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case fdc_lunit is
						when 0 =>
							mist_wr(bit_fd0)<='0';
						when 1 =>
							mist_wr(bit_fd1)<='0';
						when others =>
						end case;
						fdcbufstate<=ss_rwrite2;
					end if;
				when ss_rwrite2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						wrote:='0';
						cur_flba<=fdc_lba;
						lba_fdc<=fdc_lba;
						fdc_lunit<=fdc_punit;
						case fdc_punit is
						when 0 =>
							mist_rd(bit_fd0)<='1';
						when 1 =>
							mist_rd(bit_Fd1)<='1';
						when others =>
						end case;
						fdcbufstate<=ss_read;
					end if;
				when ss_read =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case fdc_punit is
						when 0 =>
							mist_rd(bit_fd0)<='0';
						when 1 =>
							mist_rd(bit_fd1)<='0';
						when others =>
						end case;
						fdcbufstate<=ss_read2;
					end if;
				when ss_read2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						fdcdone<='1';
						fdcbufstate<=ss_idle;
					end if;
				when ss_write =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case fdc_lunit is
						when 0 =>
							mist_wr(bit_fd0)<='0';
						when 1 =>
							mist_wr(bit_fd1)<='0';
						when others =>
						end case;
						fdcbufstate<=ss_write2;
					end if;
				when ss_write2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						cur_flba<=fdc_lba;
						lba_fdc<=fdc_lba;
						fdc_lunit<=fdc_punit;
						case fdc_punit is
						when 0 =>
							mist_rd(bit_fd0)<='1';
						when 1 =>
							mist_rd(bit_fd1)<='1';
						when others =>
						end case;
						wrote:='0';
						fdcbufstate<=ss_wread;
					end if;
				when ss_wread =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case fdc_lunit is
						when 0 =>
							mist_rd(bit_fd0)<='0';
						when 1 =>
							mist_rd(bit_fd1)<='0';
						when others =>
						end case;
						fdcbufstate<=ss_wread2;
					end if;
				when ss_wread2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						fdcbufwr<='1';
						wrote:='1';
						fdcdone<='1';
						fdcbufstate<=ss_idle;
					end if;
				when ss_sync =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case fdc_lunit is
						when 0 =>
							mist_wr(bit_fd0)<='0';
						when 1 =>
							mist_wr(bit_fd1)<='0';
						when others =>
						end case;
						fdcbufstate<=ss_sync2;
					end if;
				when ss_sync2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						wrote:='0';
						fdcdone<='1';
						fdcbufstate<=ss_idle;
					end if;
				when ss_dimhdr =>
					if(mist_ack(bit_fd1 downto bit_fd0)/="00")then
						case dim_hdr_funit is
						when 0 => mist_rd(bit_fd0)<='0';
						when 1 => mist_rd(bit_fd1)<='0';
						end case;
						fdcbufstate<=ss_dimhdr2;
					end if;
				when ss_dimhdr2 =>
					if(mist_ack(bit_fd1 downto bit_fd0)="00")then
						dim_hdr_reading<='1';
						fdcbufstate<=ss_dimhdr2b;
					end if;
				when ss_dimhdr2b =>
					fdcbufstate<=ss_dimhdr3;
				when ss_dimhdr3 =>
					dim_hdr_reading<='0';
					-- Decode DIM type from header byte 0
					case fdc_sectrddat is
					when x"00" =>	-- 2HD: 8 spt, 1024B, N=3
						if(dim_hdr_funit=0)then
							dim_sects_0<="01000"; dim_rxN_0<=x"03";
						else
							dim_sects_1<="01000"; dim_rxN_1<=x"03";
						end if;
					when x"01" =>	-- 2HS: 9 spt, 1024B, N=3
						if(dim_hdr_funit=0)then
							dim_sects_0<="01001"; dim_rxN_0<=x"03";
						else
							dim_sects_1<="01001"; dim_rxN_1<=x"03";
						end if;
					when x"02" =>	-- 2HC: 15 spt, 512B, N=2
						if(dim_hdr_funit=0)then
							dim_sects_0<="01111"; dim_rxN_0<=x"02";
						else
							dim_sects_1<="01111"; dim_rxN_1<=x"02";
						end if;
					when x"03" =>	-- 2HD (9 spt): 9 spt, 1024B, N=3
						if(dim_hdr_funit=0)then
							dim_sects_0<="01001"; dim_rxN_0<=x"03";
						else
							dim_sects_1<="01001"; dim_rxN_1<=x"03";
						end if;
					when x"09" =>	-- 2HQ: 18 spt, 512B, N=2
						if(dim_hdr_funit=0)then
							dim_sects_0<="10010"; dim_rxN_0<=x"02";
						else
							dim_sects_1<="10010"; dim_rxN_1<=x"02";
						end if;
					when x"11" =>	-- 2HDE: 26 spt, 256B, N=1
						if(dim_hdr_funit=0)then
							dim_sects_0<="11010"; dim_rxN_0<=x"01";
						else
							dim_sects_1<="11010"; dim_rxN_1<=x"01";
						end if;
					when others =>	-- default to 2HD
						if(dim_hdr_funit=0)then
							dim_sects_0<="01000"; dim_rxN_0<=x"03";
						else
							dim_sects_1<="01000"; dim_rxN_1<=x"03";
						end if;
					end case;
					fdcdone<='1';
					fdcbufstate<=ss_idle;
				when others =>
					fdcbufstate<=ss_idle;
				end case;
			end if;
		end if;
	end process;
	
	
	sasi	:sasidev port map(
		IDAT	=>sasi_din,
		ODAT	=>sasi_dout,
		SEL	=>sasi_sel,
		BSY	=>sasi_bsy,
		REQ	=>sasi_req,
		ACK	=>sasi_ack,
		IO		=>sasi_io,
		CD		=>sasi_cd,
		MSG	=>sasi_msg,
		RST	=>sasi_rst,
		
		idsel	=>sasi_idsel,
		
		id		=>open,
		unit	=>open,
		capacity	=>sasi_cap,
		lba		=>sasi_lba,
		rdreq		=>sasi_rdreq,
		wrreq		=>sasi_wrreq,
		syncreq	=>sasi_syncreq,
		sectaddr	=>sasi_sectaddr,
		rddat		=>sasi_sectrddat,
		wrdat		=>sasi_sectwrdat,
		sectbusy	=>sasi_bufbusy,
		
		clk			=>sclk,
		rstn		=>prstn
	);
	
	sasisectwr<=	mist_buffwr when emustate=es_sasi else '0';
	
	sasibuf	:dpssram generic map(9,8)port map(
		addr1	=>mist_buffaddr,
		wdat1	=>mist_buffdout,
		wr1	=>sasisectwr,
		rdat1	=>sasi_bufodat,

		addr2	=>sasi_lba(0) & sasi_sectaddr,
		wdat2	=>sasi_sectwrdat,
		wr2	=>sasibufwr,
		rdat2	=>sasi_sectrddat,
		
		clk		=>sclk
	);
	
	mist_buffdin<=		fdc_bufodat		when emustate=es_fdc else
						sasi_bufodat	when emustate=es_sasi else
						sram_bufout		when emustate=es_sload else
						sram_bufout		when emustate=es_ssave else
						(others=>'0');
						
	process(sclk,prstn)
	variable wrote	:std_logic;
	variable swait	:integer range 0 to 2;
	begin
		if(prstn='0')then
			sasibufstate<=ss_idle;
			lba_sasi<=(others=>'0');
			cur_slba<=(others=>'1');
			wrote:='0';
			mist_rd(bit_sasi)<='0';
			mist_wr(bit_sasi)<='0';
			sasibufwr<='0';
			sasidone<='0';
			swait:=0;
		elsif(sclk' event and sclk='1')then
			sasibufwr<='0';
			sasidone<='0';
			if(swait>0)then
				swait:=swait-1;
			else
				case sasibufstate is
				when ss_idle =>
					if(sasi_rdreq2='1')then
						if(sasi_lba(20 downto 1)/=cur_slba(19 downto 0))then
							if(wrote='1')then
								mist_wr(bit_sasi)<='1';
								sasibufstate<=ss_rwrite;
							else
								cur_slba<=(others=>'0'); cur_slba(19 downto 0)<=sasi_lba(20 downto 1);
								lba_sasi<=(others=>'0'); lba_sasi(19 downto 0)<=sasi_lba(20 downto 1);
								mist_rd(bit_sasi)<='1';
								sasibufstate<=ss_read;
							end if;
						else
							sasidone<='1';
						end if;
					elsif(sasi_wrreq2='1')then
						if(sasi_lba(20 downto 1)=cur_slba(19 downto 0))then
							sasibufwr<='1';
							sasidone<='1';
						else
							if(wrote='1')then
								mist_wr(bit_sasi)<='1';
								sasibufstate<=ss_write;
							else
								cur_slba<=(others=>'0'); cur_slba(19 downto 0)<=sasi_lba(20 downto 1);
								lba_sasi<=(others=>'0'); lba_sasi(19 downto 0)<=sasi_lba(20 downto 1);
								mist_rd(bit_sasi)<='1';
								sasibufstate<=ss_wread;
							end if;
						end if;
					elsif(sasi_syreq2='1')then
						if(wrote='1')then
							mist_wr(bit_sasi)<='1';
							sasibufstate<=ss_sync;
						else
							sasidone<='1';
						end if;
					end if;
				when ss_rwrite =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_rwrite2;
					end if;
				when ss_rwrite2 =>
					if(mist_ack(bit_sasi)='0')then
						wrote:='0';
						cur_slba<=(others=>'0'); cur_slba(19 downto 0)<=sasi_lba(20 downto 1);
						lba_sasi<=(others=>'0'); lba_sasi(19 downto 0)<=sasi_lba(20 downto 1);
						mist_rd(bit_sasi)<='1';
						sasibufstate<=ss_read;
					end if;
				when ss_read =>
					if(mist_ack(bit_sasi)='1')then
						mist_rd(bit_sasi)<='0';
						sasibufstate<=ss_read2;
					end if;
				when ss_read2 =>
					if(mist_ack(bit_sasi)='0')then
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when ss_write =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_write2;
					end if;
				when ss_write2 =>
					if(mist_ack(bit_sasi)='0')then
						cur_slba<=(others=>'0'); cur_slba(19 downto 0)<=sasi_lba(20 downto 1);
						lba_sasi<=(others=>'0'); lba_sasi(19 downto 0)<=sasi_lba(20 downto 1);
						mist_rd(bit_sasi)<='1';
						wrote:='0';
						sasibufstate<=ss_wread;
					end if;
				when ss_wread =>
					if(mist_ack(bit_sasi)='1')then
						mist_rd(bit_sasi)<='0';
						sasibufstate<=ss_wread2;
					end if;
				when ss_wread2 =>
					if(mist_ack(bit_sasi)='0')then
						sasibufwr<='1';
						wrote:='1';
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when ss_sync =>
					if(mist_ack(bit_sasi)='1')then
						mist_wr(bit_sasi)<='0';
						sasibufstate<=ss_sync2;
					end if;
				when ss_sync2 =>
					if(mist_ack(bit_sasi)='0')then
						wrote:='0';
						sasidone<='1';
						sasibufstate<=ss_idle;
					end if;
				when others =>
					sasibufstate<=ss_idle;
				end case;
			end if;
		end if;
	end process;
	
	sramwr<=	"00" when sram_wp='0' else
				"00" when sram_cs='0' else
				sram_wr;
	
	sram_bufwr<=	mist_buffwr when emustate=es_sload else
						mist_buffwr	when emustate=es_ssave else
						'0';
	
	sram	:sramcont port map(
		addr	=>sram_addr,
		rdat	=>sram_rdat,
		wdat	=>sram_wdat,
		wr		=>sramwr,
		
		ldreq		=>sram_ldreq,
		streq		=>sram_streq,
		done		=>sramdone,

		mist_rd	=>mist_rd(bit_sram),
		mist_wr	=>mist_wr(bit_sram),
		mist_ack	=>mist_ack(bit_sram),
		
		mist_lba	=>lba_sram,
		mist_addr	=>mist_buffaddr,
		mist_wdat	=>mist_buffdout,
		mist_rdat	=>sram_bufout,
		mist_we		=>sram_bufwr,
		
		clk		=>sclk,
		rstn		=>prstn
	);
	
	process(sclk,srstn)
	variable lmount		:std_logic_vector(3 downto 0);
	variable fdrpend	:std_logic_vector(1 downto 0);
	variable fdwpend	:std_logic_vector(1 downto 0);
	variable fdspend	:std_logic_vector(1 downto 0);
	variable sstore		:std_logic;
	variable sload		:std_logic;
	variable sasiwpend	:std_logic;
	variable sasirpend	:std_logic;
	variable sasispend	:std_logic;
	variable dim_hdr_pend	:std_logic_vector(1 downto 0);
	variable dim_hdr_active	:std_logic;
	variable dim_hdr_drv	:integer range 0 to 1;
	begin
		if(srstn='0')then
			lmount:=(others=>'0');
			emustate<=es_IDLE;
			proc_begin<='0';
			fdrpend:=(others=>'0');
			fdwpend:=(others=>'0');
			fdc_bufbusy<='0';
			fdc_rdreq2<=(others=>'0');
			fdc_wrreq2<=(others=>'0');
			fdc_syreq2<=(others=>'0');
			sstore:='0';
			sload:='0';
			fdc_indiskb<="00";
			is_dim<="00";
			dim_hdr_pend:="00";
			dim_hdr_active:='0';
			dim_hdr_drv:=0;
			dim_hdr_req2<=(others=>'0');
			sasiwpend:='0';
			sasirpend:='0';
			sasispend:='0';
			sasi_bufbusy<='0';
			sasi_rdreq2<='0';
			sasi_wrreq2<='0';
			sasi_syreq2<='0';
			sram_ldreq<='0';
			sram_streq<='0';
			sramen<='0';
			sasien<='0';
			fdc_readonly<=(others=>'0');
		elsif(sclk' event and sclk='1')then
			proc_begin<='0';
			fdc_rdreq2<=(others=>'0');
			fdc_wrreq2<=(others=>'0');
			fdc_syreq2<=(others=>'0');
			dim_hdr_req2<=(others=>'0');
			sasi_rdreq2<='0';
			sasi_wrreq2<='0';
			sasi_syreq2<='0';
			sram_ldreq<='0';
			sram_streq<='0';
			if(mist_mounted(bit_fd0)='1' and lmount(bit_fd0)='0')then
				if(mist_imgsize(31 downto 0)=x"00000000")then
					fdc_indiskb(0)<='0';
					is_dim(0)<='0';
				elsif(mist_imgsize(8 downto 0)="100000000")then
					is_dim(0)<='1';
					dim_hdr_pend(0):='1';
					fdc_readonly(0)<=mist_readonly(bit_fd0);
				else
					fdc_indiskb(0)<='1';
					is_dim(0)<='0';
					fdc_readonly(0)<=mist_readonly(bit_fd0);
				end if;
			elsif(fdc_eject(0)='1')then
				fdc_indiskb(0)<='0';
				is_dim(0)<='0';
			end if;
			if(mist_mounted(bit_fd1)='1' and lmount(bit_fd1)='0')then
				if(mist_imgsize(31 downto 0)=x"00000000")then
					fdc_indiskb(1)<='0';
					is_dim(1)<='0';
				elsif(mist_imgsize(8 downto 0)="100000000")then
					is_dim(1)<='1';
					dim_hdr_pend(1):='1';
					fdc_readonly(1)<=mist_readonly(bit_fd1);
				else
					fdc_indiskb(1)<='1';
					is_dim(1)<='0';
					fdc_readonly(1)<=mist_readonly(bit_fd1);
				end if;
			elsif(fdc_eject(1)='1')then
				fdc_indiskb(1)<='0';
				is_dim(1)<='0';
			end if;
			
			if(mist_mounted(bit_sasi)='1' and lmount(bit_sasi)='0')then
				if(mist_imgsize=x"00000000")then
					sasien<='0';
				else
					sasien<='1';
				end if;
				sasi_cap<=mist_imgsize;
			end if;
			
			if(mist_mounted(bit_sram)='1' and lmount(bit_sram)='0')then
				if(mist_imgsize=x"00000000")then
					sramen<='0';
				else
					sramen<='1';
				end if;
			end if;
			
			if(fdc_rdreq='1')then
				if(fdc_unit(0)='1')then
					fdrpend(0):='1';
					fdc_bufbusy<='1';
				end if;
				if(fdc_unit(1)='1')then
					fdrpend(1):='1';
					fdc_bufbusy<='1';
				end if;
			end if;
			
			if(fdc_wrreq='1')then
				if(fdc_unit(0)='1')then
					fdwpend(0):='1';
					fdc_bufbusy<='1';
				end if;
				if(fdc_unit(1)='1')then
					fdwpend(1):='1';
					fdc_bufbusy<='1';
				end if;
			end if;
			
			if(fdc_syncreq='1')then
				if(fdc_unit(0)='1')then
					fdspend(0):='1';
					fdc_bufbusy<='1';
				end if;
				if(fdc_unit(1)='1')then
					fdspend(1):='1';
					fdc_bufbusy<='1';
				end if;
			end if;

			
			if(sram_ld='1' and sramen='1')then
				sload:='1';
			end if;
			if(sram_st='1' and sramen='1')then
				sstore:='1';
			end if;
			
			if(sasi_rdreq='1')then
				sasirpend:='1';
				sasi_bufbusy<='1';
			elsif(sasi_wrreq='1')then
				sasiwpend:='1';
				sasi_bufbusy<='1';
			elsif(sasi_syncreq='1')then
				sasispend:='1';
			end if;
			
			lmount:=mist_mounted;
			case emustate is
			when es_IDLE =>
				if(dim_hdr_pend(0)='1')then
					dim_hdr_pend(0):='0';
					dim_hdr_active:='1';
					dim_hdr_drv:=0;
					emustate<=es_fdc;
					dim_hdr_req2(0)<='1';
				elsif(dim_hdr_pend(1)='1')then
					dim_hdr_pend(1):='0';
					dim_hdr_active:='1';
					dim_hdr_drv:=1;
					emustate<=es_fdc;
					dim_hdr_req2(1)<='1';
				elsif(sasirpend='1')then
					sasirpend:='0';
					emustate<=es_sasi;
					sasi_rdreq2<='1';
				elsif(sasiwpend='1')then
					sasiwpend:='0';
					emustate<=es_sasi;
					sasi_wrreq2<='1';
				elsif(sasispend='1')then
					sasispend:='0';
					emustate<=es_sasi;
					sasi_syreq2<='1';
				elsif(fdrpend(0)='1')then
					fdrpend(0):='0';
					emustate<=es_fdc;
					fdc_rdreq2(0)<='1';
				elsif(fdrpend(1)='1')then
					fdrpend(1):='0';
					emustate<=es_fdc;
					fdc_rdreq2(1)<='1';
				elsif(fdwpend(0)='1')then
					fdwpend(0):='0';
					emustate<=es_fdc;
					fdc_wrreq2(0)<='1';
				elsif(fdwpend(1)='1')then
					fdwpend(1):='0';
					emustate<=es_fdc;
					fdc_wrreq2(1)<='1';
				elsif(fdspend(0)='1')then
					fdspend(0):='0';
					emustate<=es_fdc;
					fdc_syreq2(0)<='1';
				elsif(fdspend(1)='1')then
					fdspend(1):='0';
					emustate<=es_fdc;
					fdc_syreq2(1)<='1';
				elsif(sload='1')then
					emustate<=es_sload;
					sram_ldreq<='1';
					sload:='0';
				elsif(sstore='1')then
					emustate<=es_ssave;
					sram_streq<='1';
					sstore:='0';
				end if;
			when es_fdc =>
				if(fdcdone='1')then
					if(dim_hdr_active='1')then
						dim_hdr_active:='0';
						fdc_indiskb(dim_hdr_drv)<='1';
					else
						fdc_bufbusy<='0';
					end if;
					emustate<=es_IDLE;
				end if;
			when es_sasi =>
				if(sasidone='1')then
					sasi_bufbusy<='0';
					emustate<=es_IDLE;
				end if;
			when es_sload | es_ssave =>
				if(sramdone='1')then
					emustate<=es_IDLE;
				end if;
			when others =>
				emustate<=es_IDLE;
			end case;
		end if;
	end process;
	
	fdc_indisk<=fdc_indiskb;
	busy<=	sasi_bufbusy or fdc_bufbusy or fdc_busy;
						
end rtl;
	

