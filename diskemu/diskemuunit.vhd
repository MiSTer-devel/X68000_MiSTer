LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE IEEE.STD_LOGIC_ARITH.ALL;
	use work.FDC_timing.all;

entity diskemuunit is
generic(
	clkfreq		:integer	:=30000;
	VLwidth		:integer	:=6;
	VCwidth		:integer	:=7;
	motordly	:integer	:=500;		--motor rotate delay(msec)	
	FDDs		:integer	:=4
);
port(
--video
	vaddr		:in std_logic_vector(12 downto 0);
	vdata		:out std_logic_vector(7 downto 0);
	vcursor_L	:out std_logic_vector(VLwidth-1 downto 0);
	vcursor_C	:out std_logic_vector(VCwidth-1 downto 0);
	vcursoren	:out std_logic;

--Keyboard
	kbdat		:in std_logic_vector(7 downto 0);
	kbrx		:in std_logic;

--SDcard
	sdc_miso	:in std_logic;
	sdc_mosi	:out std_logic;
	sdc_sclk	:out std_logic;
	sdc_cs		:out std_logic;
	
--SASI
	sasi_din	:in std_logic_vector(7 downto 0)	:=(others=>'0');
	sasi_dout	:out std_logic_vector(7 downto 0);
	sasi_sel	:in std_logic						:='0';
	sasi_bsy	:out std_logic;
	sasi_req	:out std_logic;
	sasi_ack	:in std_logic						:='0';
	sasi_io		:out std_logic;
	sasi_cd		:out std_logic;
	sasi_msg	:out std_logic;
	sasi_rst	:in std_logic						:='0';

--FDD
	fdc_useln	:in std_logic_vector(FDDs-1 downto 0)	:=(others=>'1');
	fdc_motorn	:in std_logic_vector(FDDs-1 downto 0)	:=(others=>'1');
	fdc_readyn	:out std_logic;
	fdc_wrenn	:in std_logic						:='1';
	fdc_wrbitn	:in std_logic						:='1';
	fdc_rdbitn	:out std_logic;
	fdc_stepn	:in std_logic						:='1';
	fdc_sdirn	:in std_logic						:='1';
	fdc_track0n	:out std_logic;
	fdc_indexn	:out std_logic;
	fdc_siden	:in std_logic						:='1';
	fdc_wprotn	:out std_logic;
	fdc_eject	:in std_logic_vector(FDDs-1 downto 0)	:=(others=>'0');
	fdc_indisk	:out std_logic_vector(FDDs-1 downto 0)	:=(others=>'0');
	fdc_trackwid:in std_logic						:='1';	--1:2HD/2DD 0:2D
	fdc_dencity	:in std_logic						:='1';	--1:2HD 0:2DD/2D
	fdc_rpm		:in std_logic						:='0';	--1:360rpm 0:300rpm
	fdc_mfm		:in std_logic						:='1';
	
	fdd_useln	:out std_logic_vector(1 downto 0);
	fdd_motorn	:out std_logic_vector(1 downto 0);
	fdd_readyn	:in std_logic						:='1';
	fdd_wrenn	:out std_logic;
	fdd_wrbitn	:out std_logic;
	fdd_rdbitn	:in std_logic						:='1';
	fdd_stepn	:out std_logic;
	fdd_sdirn	:out std_logic;
	fdd_track0n	:in std_logic						:='1';
	fdd_indexn	:in std_logic						:='1';
	fdd_siden	:out std_logic;
	fdd_wprotn	:in std_logic						:='1';
	fdd_eject	:out std_logic_vector(1 downto 0);
	fdd_indisk	:in std_logic_vector(1 downto 0)	:=(others=>'0');

--SRAM
	sram_cs		:in std_logic						:='0';
	sram_addr	:in std_logic_vector(12 downto 0)	:=(others=>'0');
	sram_rdat	:out std_logic_vector(15 downto 0);
	sram_wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	sram_rd		:in std_logic						:='0';
	sram_wr		:in std_logic_vector(1 downto 0)	:="00";
	sram_wp		:in std_logic						:='0';
	
--common
	model		:in std_logic_vector(7 downto 0);
	initdone	:out std_logic;
	busy		:out std_logic;
	vclk		:in std_logic;
	fclk		:in std_logic;
	mclk		:in std_logic;
	rstn		:in std_logic
);
end diskemuunit;

architecture rtl of diskemuunit is
signal	HS_MISO,LS_MISO	:std_logic;
signal	HS_MOSI,LS_MOSI	:std_logic;
signal	HS_SCLK,LS_SCLK	:std_logic;
signal	SPI_HS			:std_logic;
signal	vcursor_Lw		:std_logic_vector(5 downto 0);
signal	vcursor_Cw		:std_logic_vector(6 downto 0);
signal	sram_wren		:std_logic;
signal	sram_ben		:std_logic_vector(1 downto 0);
signal	sram_rdatx		:std_logic_vector(15 downto 0);

signal	sasi_bsyb		:std_logic;

signal	fdtram_addr		:std_logic_vector(13 downto 0);
signal	fdtram_wr		:std_logic;
signal	fdtram_wdat		:std_logic_vector(7 downto 0);
signal	fdtram_rdat		:std_logic_vector(7 downto 0);
signal	fdmcram_addr	:std_logic_vector(10 downto 0);
signal	fdmcram_wr		:std_logic;
signal	fdmcram_wdat	:std_logic_vector(7 downto 0);
signal	fdmcram_rdat	:std_logic_vector(7 downto 0);

signal	fde_trackside	:std_logic_vector(7 downto 0);
signal	fde_wrmode		:std_logic_vector(1 downto 0);
signal	fde_rdmode		:std_logic_vector(1 downto 0);
signal	fde_wrmfm		:std_logic;
signal	fde_rdmfm		:std_logic;
signal	fde_wrote		:std_logic;
signal	fde_dsel0		:std_logic_vector(3 downto 0);
signal	fde_dsel1		:std_logic_vector(3 downto 0);
signal	fde_tracklen	:std_logic_vector(13 downto 0);
signal	fde_ready		:std_logic;
signal	fde_wprot		:std_logic;
signal	fdmodem_mode	:std_logic_vector(1 downto 0);
signal	fdmodem_usel	:std_logic_vector(1 downto 0);
signal	fdmodem_mfm		:std_logic;
signal	fde_rdbitn		:std_logic;
signal	fde_track0n		:std_logic;
signal	fde_indexn		:std_logic;
signal	fde_emuen		:std_logic_vector(3 downto 0);
signal	fde_indisk		:std_logic_vector(3 downto 0);

signal	fdc_usel		:std_logic_vector(3 downto 0);
signal 	fde_motorrdyw	:std_logic_vector(3 downto 0);
signal 	fde_motorrdy	:std_logic_vector(FDDs-1 downto 0);
signal	fde_busy		:std_logic;

signal	fdc_uselnw		:std_logic_vector(3 downto 0);
signal	fdc_motornw		:std_logic_vector(3 downto 0);
signal	fdc_ejectw		:std_logic_vector(3 downto 0);
signal	fdc_indiskw		:std_logic_vector(3 downto 0);
signal	fddselw			:std_logic_vector(3 downto 0);
signal	fddsel			:std_logic_vector(FDDs-1 downto 0);

signal	dsmask		:std_logic;

component diskemu
	port (
		clk_clk              : in  std_logic                     := '0';             --             clk.clk
		spi_sdcard_slow_MISO : in  std_logic                     := '0';             -- spi_sdcard_slow.MISO
		spi_sdcard_slow_MOSI : out std_logic;                                        --                .MOSI
		spi_sdcard_slow_SCLK : out std_logic;                                        --                .SCLK
		spi_sdcard_slow_SS_n : out std_logic;                                        --                .SS_n
		reset_reset_n        : in  std_logic                     := '0';             --           reset.reset_n
		spi_sdcard_fast_MISO : in  std_logic                     := '0';             -- spi_sdcard_fast.MISO
		spi_sdcard_fast_MOSI : out std_logic;                                        --                .MOSI
		spi_sdcard_fast_SCLK : out std_logic;                                        --                .SCLK
		spi_sdcard_fast_SS_n : out std_logic;                                        --                .SS_n
		sasidin_export       : in  std_logic_vector(7 downto 0)  := (others => '0'); --         sasidin.export
		sasidout_export      : out std_logic_vector(7 downto 0);                     --        sasidout.export
		sasisel_export       : in  std_logic                     := '0';             --         sasisel.export
		sasibsy_export       : out std_logic;                                        --         sasibsy.export
		sasireq_export       : out std_logic;                                        --         sasireq.export
		sasiack_export       : in  std_logic                     := '0';             --         sasiack.export
		sasiio_export        : out std_logic;                                        --          sasiio.export
		sasicd_export        : out std_logic;                                        --          sasicd.export
		sasimsg_export       : out std_logic;                                        --         sasimsg.export
		sasirst_export       : in  std_logic                     := '0';             --         sasirst.export
		spihs_export         : out std_logic;                                        --           spihs.export
		vram_address         : in  std_logic_vector(12 downto 0) := (others => '0'); --            vram.address
		vram_chipselect      : in  std_logic                     := '0';             --                .chipselect
		vram_clken           : in  std_logic                     := '0';             --                .clken
		vram_write           : in  std_logic                     := '0';             --                .write
		vram_readdata        : out std_logic_vector(7 downto 0);                     --                .readdata
		vram_writedata       : in  std_logic_vector(7 downto 0)  := (others => '0'); --                .writedata
		vclk_clk             : in  std_logic                     := '0';             --            vclk.clk
		kbdat_export         : in  std_logic_vector(7 downto 0)  := (others => '0'); --           kbdat.export
		kbrx_export          : in  std_logic                     := '0';             --            kbrx.export
		model_export         : in  std_logic_vector(7 downto 0)  := (others => '0'); --           model.export
		sdcs_export          : out std_logic;                                        --            sdcs.export
		nvsram_address       : in  std_logic_vector(12 downto 0) := (others => '0'); --          nvsram.address
		nvsram_chipselect    : in  std_logic                     := '0';             --                .chipselect
		nvsram_clken         : in  std_logic                     := '0';             --                .clken
		nvsram_write         : in  std_logic                     := '0';             --                .write
		nvsram_readdata      : out std_logic_vector(15 downto 0);                    --                .readdata
		nvsram_writedata     : in  std_logic_vector(15 downto 0) := (others => '0'); --                .writedata
		nvsram_byteenable    : in  std_logic_vector(1 downto 0)  := (others => '0'); --                .byteenable
		mclk_clk             : in  std_logic                     := '0';             --            mclk.clk
		nvsave_export        : in  std_logic                     := '0';             --          nvsave.export
		fdclk_clk            : in  std_logic                     := '0';             --           fdclk.clk
		fdtram_address       : in  std_logic_vector(13 downto 0) := (others => '0'); --          fdtram.address
		fdtram_chipselect    : in  std_logic                     := '0';             --                .chipselect
		fdtram_clken         : in  std_logic                     := '0';             --                .clken
		fdtram_write         : in  std_logic                     := '0';             --                .write
		fdtram_readdata      : out std_logic_vector(7 downto 0);                     --                .readdata
		fdtram_writedata     : in  std_logic_vector(7 downto 0)  := (others => '0'); --                .writedata
		initdone_export      : out std_logic;                                        --        initdone.export
		fdmcram_address      : in  std_logic_vector(10 downto 0) := (others => '0'); --         fdmcram.address
		fdmcram_chipselect   : in  std_logic                     := '0';             --                .chipselect
		fdmcram_clken        : in  std_logic                     := '0';             --                .clken
		fdmcram_write        : in  std_logic                     := '0';             --                .write
		fdmcram_readdata     : out std_logic_vector(7 downto 0);                     --                .readdata
		fdmcram_writedata    : in  std_logic_vector(7 downto 0)  := (others => '0'); --                .writedata
		fdtrackside_export   : in  std_logic_vector(7 downto 0)  := (others => '0'); --     fdtrackside.export
		fdmodein_export      : in  std_logic_vector(1 downto 0)  := (others => '0'); --        fdmodein.export
		fdmfmin_export       : in  std_logic                     := '0';             --         fdmfmin.export
		fdmfmout_export      : out std_logic;                                        --        fdmfmout.export
		fdwrote_export       : in  std_logic                     := '0';             --         fdwrote.export
		fddsel_export        : in  std_logic_vector(3 downto 0)  := (others => '0'); --          fddsel.export
		fdsel0_export        : out std_logic_vector(3 downto 0);                     --          fdsel0.export
		fdsel1_export        : out std_logic_vector(3 downto 0);                     --          fdsel1.export
		fdeject_export       : in  std_logic_vector(3 downto 0)  := (others => '0'); --         fdeject.export
		fdindisk_export      : out std_logic_vector(3 downto 0);                     --        fdindisk.export
		fdtracklen_export    : out std_logic_vector(13 downto 0);                    --      fdtracklen.export
		fdmodeout_export     : out std_logic_vector(1 downto 0);                     --       fdmodeout.export
		fdready_export       : out std_logic;                                        --         fdready.export
		fdwprot_export       : out std_logic;                                         --         fdqprot.export
		curc_export          : out std_logic_vector(6 downto 0);                     --            curc.export
		curl_export          : out std_logic_vector(5 downto 0);                     --            curl.export
		curen_export         : out std_logic;                                        --           curen.export
		fdemuen_export       : out std_logic_vector(3 downto 0);                     --         fdemuen.export
		fdebusy_export       : out std_logic                                         --         fdebusy.export
	);
end component;

component FDemu
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
end component;

component delayon
generic(
	delay	:integer	:=100
);
port(
	delayin	:in std_logic;
	delayout:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin

	mpu	:diskemu port map(
		clk_clk					=>fclk,
		reset_reset_n			=>rstn,
		model_export			=>model,
		initdone_export			=>initdone,
		spi_sdcard_slow_MISO	=>LS_MISO,
		spi_sdcard_slow_MOSI	=>LS_MOSI,
		spi_sdcard_slow_SCLK	=>LS_SCLK,
		spi_sdcard_slow_SS_n	=>open,
		spi_sdcard_fast_MISO	=>HS_MISO,
		spi_sdcard_fast_MOSI	=>HS_MOSI,
		spi_sdcard_fast_SCLK	=>HS_SCLK,
		spi_sdcard_fast_SS_n	=>open,
		spihs_export			=>SPI_HS,
		sdcs_export				=>sdc_cs,
		sasidin_export			=>sasi_din,
		sasidout_export			=>sasi_dout,
		sasisel_export			=>sasi_sel,
		sasibsy_export			=>sasi_bsyb,
		sasireq_export			=>sasi_req,
		sasiack_export			=>sasi_ack,
		sasiio_export			=>sasi_io,
		sasicd_export			=>sasi_cd,
		sasimsg_export			=>sasi_msg,
		sasirst_export			=>sasi_rst,
		vram_address			=>vaddr,
		vram_chipselect			=>'1',
		vram_clken				=>'1',
		vram_write				=>'0',
		vram_readdata			=>vdata,
		vram_writedata			=>(others=>'0'),
		vclk_clk				=>vclk,
		kbdat_export			=>kbdat,
		kbrx_export				=>kbrx,
		nvsram_address			=>sram_addr,
		nvsram_chipselect		=>sram_cs,
		nvsram_clken			=>'1',
		nvsram_write			=>sram_wren,
		nvsram_readdata			=>sram_rdatx,
		nvsram_writedata		=>sram_wdat(7 downto 0) & sram_wdat(15 downto 8),
		nvsram_byteenable		=>sram_ben,
		mclk_clk				=>mclk,
		fdclk_clk				=>fclk,
		fdtram_address			=>fdtram_addr,
		fdtram_chipselect		=>'1',
		fdtram_clken			=>'1',
		fdtram_write			=>fdtram_wr,
		fdtram_readdata			=>fdtram_rdat,
		fdtram_writedata		=>fdtram_wdat,
		fdmcram_address			=>fdmcram_addr,
		fdmcram_chipselect 		=>'1',
		fdmcram_clken			=>'1',
		fdmcram_write			=>fdmcram_wr,
		fdmcram_readdata		=>fdmcram_rdat,
		fdmcram_writedata		=>fdmcram_wdat,
		fdtrackside_export		=>fde_trackside,
		fdmodein_export			=>fde_wrmode,
		fdmfmin_export			=>fde_wrmfm,
		fdmfmout_export			=>fde_rdmfm,
		fdwrote_export			=>fde_wrote,
		fddsel_export			=>fddselw and (dsmask & dsmask & dsmask & dsmask),
		fdsel0_export			=>fde_dsel0,
		fdsel1_export			=>fde_dsel1,
		fdeject_export			=>fdc_ejectw,
		fdindisk_export			=>fde_indisk,
		fdtracklen_export		=>fde_tracklen,
		fdmodeout_export		=>fde_rdmode,
		fdready_export			=>fde_ready,
		fdwprot_export			=>fde_wprot,
		fdemuen_export			=>fde_emuen,
		fdebusy_export			=>fde_busy,
		curc_export				=>vcursor_Cw,
		curl_export				=>vcursor_Lw,
		curen_export			=>vcursoren
	);
	sasi_bsy<=sasi_bsyb;
	fde_wrmfm<=fdc_mfm;
	fdmodem_mfm<=fdc_mfm when fdc_wrenn='0' else fde_rdmfm;
	
	sdc_sclk<=	HS_SCLK	when SPI_HS='1' else LS_SCLK;
	sdc_mosi<=	HS_MOSI	when SPI_HS='1' else LS_MOSI;
	HS_MISO<=	sdc_miso when SPI_HS='1' else '1';
	LS_MISO<=	sdc_miso when SPI_HS='0' else '1';
	
	vcursor_L<=vcursor_Lw(VLwidth-1 downto 0);
	vcursor_C<=vcursor_Cw(VCwidth-1 downto 0);
	fdmcram_addr<=fdtram_addr(13 downto 3);
	
	fdmodem_usel<=	"00" when fdc_usel="0001" else
					"01" when fdc_usel="0010" else
					"10" when fdc_usel="0100" else
					"11" when fdc_usel="1000" else
					"00";
	fde_wrmode<=	"00" when fdc_trackwid='0' else
					"01" when fdc_dencity='0' else
					"10" when fdc_rpm='0' else
					"11";
	fdmodem_mode<=	fde_wrmode when fdc_wrenn='0' else fde_rdmode;
	sram_wren<=	'0' when sram_cs='0' else
				'0' when sram_wp='0' else
				'1' when sram_wr/="00" else
				'0';
	sram_ben<=(sram_rd or sram_wr(0)) & (sram_rd or sram_wr(1));
	sram_rdat<=sram_rdatx(7 downto 0) & sram_rdatx(15 downto 8);
	
	fde	:FDemu generic map(clkfreq) port map(
		ADDR		=>fdtram_addr,
		RDDAT		=>fdtram_rdat,
		WRDAT		=>fdtram_wdat,
		DATWR		=>fdtram_wr,
		RDMC		=>fdmcram_rdat,
		WRMC		=>fdmcram_wdat,
		MCWR		=>fdmcram_wr,
		TRACKLEN	=>fde_tracklen,
		TRACKSIDE	=>fde_trackside,
		FDMODE		=>fdmodem_mode,
		MFM			=>fdmodem_mfm,
		
		USEL		=>fdmodem_usel,
		READY		=>fde_ready,
		WRENn		=>fdc_wrenn,
		WRBITn		=>fdc_wrbitn,
		RDBITn		=>fde_rdbitn,
		STEPn		=>fdc_stepn,
		SDIRn		=>fdc_sdirn,
		track0n		=>fde_track0n,
		indexn		=>fde_indexn,
		siden		=>fdc_siden,

		clk			=>fclk,
		rstn		=>rstn
	);
	
	delay0	:delayon generic map(clkfreq*motordly) port map(not fdc_motornw(0),fde_motorrdyw(0),fclk,rstn);
	delay1	:delayon generic map(clkfreq*motordly) port map(not fdc_motornw(1),fde_motorrdyw(1),fclk,rstn);
	delay2	:delayon generic map(clkfreq*motordly) port map(not fdc_motornw(2),fde_motorrdyw(2),fclk,rstn);
	delay3	:delayon generic map(clkfreq*motordly) port map(not fdc_motornw(3),fde_motorrdyw(3),fclk,rstn);

	process(fdc_useln)begin
		fdc_uselnw<=(others=>'1');
		fdc_uselnw(FDDs-1 downto 0)<=fdc_useln;
	end process;
	
	process(fdc_motorn)begin
		fdc_motornw<=(others=>'1');
		fdc_motornw(FDDs-1 downto 0)<=fdc_motorn;
	end process;
	
	process(fdc_eject)begin
		fdc_ejectw<=(others=>'0');
		fdc_ejectw(FDDs-1 downto 0)<=fdc_eject;
	end process;
	
	fddsel<=not (fdc_useln or fdc_motorn);
	process(fddsel)begin
		fddselw<=(others=>'0');
		fddselw(FDDs-1 downto 0)<=fddsel;
	end process;
	
	fde_motorrdy<=fde_motorrdyw(FDDs-1 downto 0);
	
	fdd_useln(0)<=	'0' when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					'0' when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					'0' when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					'0' when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_useln(1)<=	'0' when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					'0' when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					'0' when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					'0' when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_motorn(0)<=	'0' when fde_dsel0(0)='1' and fdc_motornw(0)='0' else
					'0' when fde_dsel0(1)='1' and fdc_motornw(1)='0' else
					'0' when fde_dsel0(2)='1' and fdc_motornw(2)='0' else
					'0' when fde_dsel0(3)='1' and fdc_motornw(3)='0' else
					'1';
	fdd_motorn(1)<=	'0' when fde_dsel1(0)='1' and fdc_motornw(0)='0' else
					'0' when fde_dsel1(1)='1' and fdc_motornw(1)='0' else
					'0' when fde_dsel1(2)='1' and fdc_motornw(2)='0' else
					'0' when fde_dsel1(3)='1' and fdc_motornw(3)='0' else
					'1';
	fdd_wrenn<=		fdc_wrenn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdc_wrenn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdc_wrenn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdc_wrenn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdc_wrenn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdc_wrenn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdc_wrenn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdc_wrenn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_wrbitn<=	fdc_wrbitn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdc_wrbitn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdc_wrbitn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdc_wrbitn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdc_wrbitn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdc_wrbitn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdc_wrbitn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdc_wrbitn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_stepn<=		fdc_stepn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdc_stepn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdc_stepn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdc_stepn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdc_stepn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdc_stepn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdc_stepn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdc_stepn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_sdirn<=		fdc_sdirn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdc_sdirn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdc_sdirn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdc_sdirn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdc_sdirn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdc_sdirn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdc_sdirn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdc_sdirn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_siden<=		fdc_siden when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdc_siden when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdc_siden when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdc_siden when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdc_siden when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdc_siden when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdc_siden when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdc_siden when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdd_eject(0)<=	(fdc_ejectw(0) and fde_dsel0(0)) or
					(fdc_ejectw(1) and fde_dsel0(1)) or
					(fdc_ejectw(2) and fde_dsel0(2)) or
					(fdc_ejectw(3) and fde_dsel0(3));
	fdd_eject(1)<=	(fdc_ejectw(0) and fde_dsel1(0)) or
					(fdc_ejectw(1) and fde_dsel1(1)) or
					(fdc_ejectw(2) and fde_dsel1(2)) or
					(fdc_ejectw(3) and fde_dsel1(3));
	fdc_rdbitn<=	fdd_rdbitn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdd_rdbitn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdd_rdbitn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdd_rdbitn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdd_rdbitn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdd_rdbitn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdd_rdbitn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdd_rdbitn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					fde_rdbitn when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
					fde_rdbitn when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
					fde_rdbitn when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
					fde_rdbitn when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdc_track0n<=	fdd_track0n when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdd_track0n when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdd_track0n when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdd_track0n when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdd_track0n when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdd_track0n when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdd_track0n when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					fde_track0n when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
					fde_track0n when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
					fde_track0n when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
					fde_track0n when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdc_indexn<=	fdd_indexn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdd_indexn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdd_indexn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdd_indexn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdd_indexn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdd_indexn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdd_indexn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdd_indexn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					fde_indexn when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
					fde_indexn when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
					fde_indexn when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
					fde_indexn when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdc_wprotn<=	fdd_wprotn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdd_wprotn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdd_wprotn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdd_wprotn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdd_wprotn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdd_wprotn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdd_wprotn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdd_wprotn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
					not fde_wprot when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
					not fde_wprot when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
					not fde_wprot when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
					not fde_wprot when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fdc_readyn<=	fdd_readyn when fde_dsel0(0)='1' and fdc_uselnw(0)='0' else
					fdd_readyn when fde_dsel0(1)='1' and fdc_uselnw(1)='0' else
					fdd_readyn when fde_dsel0(2)='1' and fdc_uselnw(2)='0' else
					fdd_readyn when fde_dsel0(3)='1' and fdc_uselnw(3)='0' else
					fdd_readyn when fde_dsel1(0)='1' and fdc_uselnw(0)='0' else
					fdd_readyn when fde_dsel1(1)='1' and fdc_uselnw(1)='0' else
					fdd_readyn when fde_dsel1(2)='1' and fdc_uselnw(2)='0' else
					fdd_readyn when fde_dsel1(3)='1' and fdc_uselnw(3)='0' else
--					not fde_ready when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
--					not fde_ready when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
--					not fde_ready when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
--					not fde_ready when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					not fde_motorrdyw(0) when fde_emuen(0)='1' and fde_indisk(0)='1' and fdc_uselnw(0)='0' else
					not fde_motorrdyw(1) when fde_emuen(1)='1' and fde_indisk(1)='1' and fdc_uselnw(1)='0' else
					not fde_motorrdyw(2) when fde_emuen(2)='1' and fde_indisk(2)='1' and fdc_uselnw(2)='0' else
					not fde_motorrdyw(3) when fde_emuen(3)='1' and fde_indisk(3)='1' and fdc_uselnw(3)='0' else
					'1';
	fde_wrote<=		not fdc_wrenn when fde_emuen(0)='1' and fdc_uselnw(0)='0' else
					not fdc_wrenn when fde_emuen(1)='1' and fdc_uselnw(1)='0' else
					not fdc_wrenn when fde_emuen(2)='1' and fdc_uselnw(2)='0' else
					not fdc_wrenn when fde_emuen(3)='1' and fdc_uselnw(3)='0' else
					'0';
	fdc_indiskw(0)<=	fde_indisk(0) when fde_emuen(0)='1' else
					fdd_indisk(0) when fde_dsel0(0)='1' else
					fdd_indisk(1) when fde_dsel1(0)='1' else
					'0';
	fdc_indiskw(1)<=	fde_indisk(1) when fde_emuen(1)='1' else
					fdd_indisk(0) when fde_dsel0(1)='1' else
					fdd_indisk(1) when fde_dsel1(1)='1' else
					'0';
	fdc_indiskw(2)<=	fde_indisk(2) when fde_emuen(2)='1' else
					fdd_indisk(0) when fde_dsel0(2)='1' else
					fdd_indisk(1) when fde_dsel1(2)='1' else
					'0';
	fdc_indiskw(3)<=	fde_indisk(3) when fde_emuen(3)='1' else
					fdd_indisk(0) when fde_dsel0(3)='1' else
					fdd_indisk(1) when fde_dsel1(3)='1' else
					'0';
	fdc_indisk<=fdc_indiskw(FDDs-1 downto 0);
	busy<=fde_busy or sasi_bsyb;

	process(mclk,rstn)
	variable	ltrackside	:std_logic_vector(7 downto 0);
	variable	dswait		:integer range 0 to 5*clkfreq;
	begin
		if(rstn='0')then
			dswait:=0;
			ltrackside:=(others=>'0');
			dsmask<='1';
		elsif(mclk' event and mclk='1')then
			if(fde_trackside/=ltrackside)then
				dsmask<='0';
				dswait:=5*clkfreq;
			elsif(dswait>0)then
				dswait:=dswait-1;
				dsmask<='0';
			else
				dsmask<='1';
			end if;
			ltrackside:=fde_trackside;
		end if;
	end process;

end rtl;					
