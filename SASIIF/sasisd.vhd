library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity sasisd is
port(
	cs		:in std_logic;
	addr	:in std_logic_vector(1 downto 0);
	rd		:in std_logic;
	wr		:in std_logic;
	wdat	:in std_logic_vector(7 downto 0);
	rdat	:out std_logic_vector(7 downto 0);
	doe		:out std_logic;
	int		:out std_logic;
	iack	:in std_logic;
	drq		:out std_logic;
	dack	:in std_logic;
	
	SCLK	:out std_logic;
	SDI		:in std_logic;
	SDO		:out std_logic;
	SD_CS	:out std_logic;
	
	BUSY	:out std_logic;

	sdsft	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end sasisd;

architecture rtl of sasisd is
signal	s_IDSEL		:std_logic_vector(2 downto 0);
signal	s_IDSET		:std_logic;
signal	s_IDACK		:std_logic;
signal	s_DIR		:std_logic;
	
signal	s_OPCODE	:std_logic_vector(7 downto 0);
signal	s_UADDR		:std_logic_vector(23 downto 0);
signal	s_BLOCKS	:std_logic_vector(7 downto 0);
signal	s_CONTROL	:std_logic_vector(7 downto 0);
signal	s_EXEBGN	:std_logic;
signal	s_EXECOMP	:std_logic;
	
signal	s_STATUS	:std_logic_vector(7 downto 0);
signal	s_MESSAGE	:std_logic_vector(7 downto 0);

signal	dev_wdat	:std_logic_vector(7 downto 0);
signal	dev_wr		:std_logic;
signal	dev_wbusy	:std_logic;
signal	dev_rdat	:std_logic_vector(7 downto 0);
signal	dev_rd		:std_logic;
signal	dev_rddone	:std_logic;

signal	spi_WRDAT	:std_logic_vector(7 downto 0);
signal	spi_RDDAT	:std_logic_vector(7 downto 0);
signal	spi_TX		:std_logic;
signal	spi_BUSY	:std_logic;

signal	SD_INSLOT	:std_logic;

signal	int_state	:integer range 0 to 100;
signal	blkcount	:std_logic_vector(7 downto 0);
signal	bytecount	:integer range 0 to 255;
signal	blkdup		:integer range 1 to 4;
signal	bdupcount	:integer range 0 to 3;

signal	C_SIZE		:std_logic_vector(11 downto 0);
signal	C_SIZE_MULT	:std_logic_vector(2 downto 0);

signal	CSD			:std_logic_vector(127 downto 0);
signal	dev_ERRCODE	:std_logic_vector(7 downto 0);
signal	dev_ERRADDR	:std_logic_vector(23 downto 0);

signal	sft		:std_logic;
signal	waitcount	:integer range 0 to 100;

signal	sd_addr_org	:std_logic_vector(31 downto 0);
signal	sd_addr_off	:std_logic_vector(31 downto 0);
signal	sd_addr		:std_logic_vector(31 downto 0);

type state_t is(
	st_PINIT,
	st_INIT,
	st_CHGBSIZE,
	st_IDLE,
	st_EXEC
);
signal	state	:state_t;

signal	proc_bgn	:std_logic;
signal	proc_end	:std_logic;

signal	blksize		:std_logic_vector(3 downto 0);

component SPI_IF
port(
	MODE	:in std_logic_vector(1 downto 0);
	WRDAT	:in std_logic_vector(7 downto 0);
	RDDAT	:out std_logic_vector(7 downto 0);
	TX		:in std_logic;
	BUSY	:out std_logic;
	
	SCLK	:out std_logic;
	SDI		:in std_logic;
	SDO		:out std_logic;
	
	SFT		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component sasiio
port(
	cs		:in std_logic;
	addr	:in std_logic_vector(1 downto 0);
	rd		:in std_logic;
	wr		:in std_logic;
	wdat	:in std_logic_vector(7 downto 0);
	rdat	:out std_logic_vector(7 downto 0);
	doe		:out std_logic;
	int		:out std_logic;
	iack	:in std_logic;
	drq		:out std_logic;
	dack	:in std_logic;
	
	IDSEL	:out std_logic_vector(2 downto 0);
	IDSET	:out std_logic;
	IDACK	:in std_logic;
	DIR		:in std_logic;
	
	OPCODE	:out std_logic_vector(7 downto 0);
	UADDR	:out std_logic_vector(23 downto 0);
	BLOCKS	:out std_logic_vector(7 downto 0);
	CONTROL	:out std_logic_vector(7 downto 0);
	EXEBGN	:out std_logic;
	
	dev_wdat:out std_logic_vector(7 downto 0);
	dev_wr	:out std_logic;
	dev_wbusy:in std_logic;
	dev_rdat:in std_logic_vector(7 downto 0);
	dev_rd	:in std_logic;
	dev_rddone:out std_logic;
	
	EXECOMP	:in std_logic;
	
	STATUS	:in std_logic_vector(7 downto 0);
	MESSAGE	:in std_logic_vector(7 downto 0);
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

begin

	sasi	:sasiio port map(
		cs			=>cs,
		addr		=>addr,
		rd			=>rd,
		wr			=>wr,
		wdat		=>wdat,
		rdat		=>rdat,
		doe			=>doe,
		int			=>int,
		iack		=>iack,
		drq			=>drq,
		dack		=>dack,
		
		IDSEL		=>s_IDSEL,
		IDSET		=>s_IDSET,
		IDACK		=>s_IDACK,
		DIR			=>s_DIR,
		
		OPCODE		=>s_OPCODE,
		UADDR		=>s_UADDR,
		BLOCKS		=>s_BLOCKS,
		CONTROL		=>s_CONTROL,
		EXEBGN		=>s_EXEBGN,
		
		dev_wdat	=>dev_wdat,
		dev_wr		=>dev_wr,
		dev_wbusy	=>dev_wbusy,
		dev_rdat	=>dev_rdat,
		dev_rd		=>dev_rd,
		dev_rddone	=>dev_rddone,
		
		EXECOMP		=>s_EXECOMP,
		
		STATUS		=>s_STATUS,
		MESSAGE		=>s_MESSAGE,
		
		clk			=>clk,
		rstn		=>rstn
	);
	
	sft<='1' when (CSD(98 downto 96)="010" or CSD(98 downto 96)="011") and SD_INSLOT='1' else sdsft;
--	sft<=sdsft;
	
	SDC	:SPI_IF port map(
		MODE	=>"11",
		WRDAT	=>spi_WRDAT,
		RDDAT	=>spi_RDDAT,
		TX		=>spi_TX,
		BUSY	=>spi_BUSY,
		
		SCLK	=>SCLK,
		SDI		=>SDI,
		SDO		=>SDO,
		
		SFT		=>sft,
		clk		=>clk,
		rstn	=>rstn
	);

	
	process(clk,rstn)begin
		if(rstn='0')then
			s_IDACK<='0';
		elsif(clk' event and clk='1')then
			if(s_IDSET='1')then
				if(s_IDSEL="000" and SD_INSLOT='1')then
					s_IDACK<='1';
				else
					s_IDACK<='0';
				end if;
			end if;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			state<=st_PINIT;
			proc_bgn<='0';
			s_EXECOMP<='0';
			blksize<=(others=>'0');
		elsif(clk' event and clk='1')then
			proc_bgn<='0';
			s_EXECOMP<='0';
			case state is
			when st_PINIT =>
				state<=st_INIT;
				proc_bgn<='1';
			when st_INIT =>
				if(proc_end='1')then
					if(CSD(21)='1' and CSD(79)='1')then
						blksize<=x"8";
					else
						blksize<=x"9";
					end if;
					state<=st_CHGBSIZE;
					proc_bgn<='1';
				end if;
			when st_CHGBSIZE =>
				if(proc_end='1')then
					state<=st_IDLE;
				end if;
			when st_IDLE =>
				if(s_EXEBGN='1')then
					state<=st_EXEC;
					proc_bgn<='1';
				end if;
			when st_EXEC =>
				if(proc_end='1')then
					s_EXECOMP<='1';
					state<=st_IDLE;
				end if;
			when others =>
				state<=st_IDLE;
			end case;
		end if;
	end process;
	
	BUSY<='0' when state=st_PINIT or state=st_IDLE else '1';
	
	sd_addr_org<=	"00" & s_IDSEL & s_UADDR(21) & s_UADDR(17 downto 0) & "00000000" when blksize=x"8" else
					'0' & s_IDSEL & s_UADDR(21) & s_UADDR(17 downto 0) & "000000000" when blksize=x"9" else
						s_IDSEL & s_UADDR(21) & s_UADDR(17 downto 0) & "0000000000" when blksize=x"a" else
				(others=>'0');
	sd_addr_off<=	"0000000000000000" & blkcount & "00000000" when blksize=x"8" else
					"000000000000000" & blkcount & "000000000" when blksize=x"9" else
					"00000000000000" & blkcount & "0000000000" when blksize=x"a" else
					(others=>'0');
	sd_addr<=sd_addr_org + sd_addr_off;
	blkdup<=	1 when blksize=x"8" else
				2 when blksize=x"9" else
				4 when blksize=x"a" else
				1;
	process(clk,rstn)begin
		if(rstn='0')then
			int_state<=0;
			blkcount<=(others=>'0');
			bytecount<=0;
			s_STATUS<=(others=>'0');
			s_MESSAGE<=(others=>'0');
			s_DIR<='0';
			SD_INSLOT<='0';
			proc_end<='0';
			spi_WRDAT<=(others=>'0');
			spi_TX<='0';
			dev_ERRCODE<=(others=>'0');
			dev_ERRADDR<=(others=>'0');
			CSD<=(others=>'0');
			SD_CS<='1';
			waitcount<=0;
			blkcount<=(others=>'0');
			bytecount<=0;
			bdupcount<=0;
			dev_wbusy<='1';
			dev_rd<='0';
		elsif(clk' event and clk='1')then
			proc_end<='0';
			spi_TX<='0';
			if(state=st_INIT)then
				if(proc_bgn='1')then
					int_state<=1;
					waitcount<=20;
				elsif(waitcount>0)then
					if(sdsft='1')then
						waitcount<=waitcount-1;
					end if;
				else
					case int_state is
					when 1 =>		--dummy clock x 10byte
						SD_CS<='1';
						spi_WRDAT<=(others=>'1');
						bytecount<=10;
						int_state<=2;
					when 2 =>
						spi_TX<='1';
						int_state<=3;
					when 3 =>
						if(spi_BUSY='0')then
							if(bytecount>0)then
								bytecount<=bytecount-1;
								int_state<=2;
							else
								int_state<=10;
								waitcount<=20;
							end if;
						end if;
					when 10 =>				--CMD00
						SD_CS<='0';
						spi_WRDAT<=x"40";
						spi_TX<='1';
						int_state<=11;
					when 11 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=12;
						end if;
					when 12 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=13;
						end if;
					when 13 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=14;
						end if;
					when 14 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=15;
						end if;
					when 15 =>				--CRC
						if(spi_BUSY='0')then
							spi_WRDAT<=x"95";
							spi_TX<='1';
							int_state<=16;
						end if;
					when 16 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"01" =>
								int_state<=17;
								waitcount<=20;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								SD_CS<='1';
								int_state<=1;
								waitcount<=20;
							end case;
						end if;
					when 17 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_state<=20;
					when 20 =>					--cmd1
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"41";
							spi_TX<='1';
							int_state<=21;
						end if;
					when 21 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=22;
						end if;
					when 22 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=23;
						end if;
					when 23 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=24;
						end if;
					when 24 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=25;
						end if;
					when 25 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"f9";
							spi_TX<='1';
							int_state<=26;
						end if;
					when 26=>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								int_state<=27;
								waitcount<=20;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=20;
								waitcount<=40;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								waitcount<=40;
								int_state<=1;
							end case;
						end if;
					when 27 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_state<=30;
					when 30 =>				--CMD9:Read card config
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"49";
							spi_TX<='1';
							int_state<=31;
						end if;
					when 31 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=32;
						end if;
					when 32 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=33;
						end if;
					when 33 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=34;
						end if;
					when 34 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=35;
						end if;
					when 35 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=36;
						end if;
					when 36 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=37;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=30;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								int_state<=1;
							end case;
						end if;
					when 37 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"fe" =>			--data token
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=38;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								int_state<=1;
							end case;
						end if;
					when 38 =>
						if(spi_BUSY='0')then		--data0
							CSD(127 downto 120)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=39;
						end if;
					when 39 =>
						if(spi_BUSY='0')then		--data1
							CSD(119 downto 112)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=40;
						end if;
					when 40 =>
						if(spi_BUSY='0')then		--data2
							CSD(111 downto 104)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=41;
						end if;
					when 41 =>
						if(spi_BUSY='0')then		--data3
							CSD(103 downto  96)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=42;
						end if;
					when 42 =>
						if(spi_BUSY='0')then		--data4
							CSD( 95 downto  88)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=43;
						end if;
					when 43 =>
						if(spi_BUSY='0')then		--data5
							CSD( 87 downto  80)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=44;
						end if;
					when 44 =>
						if(spi_BUSY='0')then		--data6
							CSD( 79 downto  72)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=45;
						end if;
					when 45 =>
						if(spi_BUSY='0')then		--data7
							CSD( 71 downto  64)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=46;
						end if;
					when 46 =>
						if(spi_BUSY='0')then		--data8
							CSD( 63 downto  56)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=47;
						end if;
					when 47 =>
						if(spi_BUSY='0')then		--data9
							CSD( 55 downto  48)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=48;
						end if;
					when 48 =>
						if(spi_BUSY='0')then		--data10
							CSD( 47 downto  40)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=49;
						end if;
					when 49 =>
						if(spi_BUSY='0')then		--data11
							CSD( 39 downto  32)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=50;
						end if;
					when 50 =>
						if(spi_BUSY='0')then		--data12
							CSD( 31 downto  24)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=51;
						end if;
					when 51 =>
						if(spi_BUSY='0')then		--data13
							CSD( 23 downto  16)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=52;
						end if;
					when 52 =>
						if(spi_BUSY='0')then		--data14
							CSD( 15 downto   8)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=53;
						end if;
					when 53 =>
						if(spi_BUSY='0')then		--data15
							CSD(  7 downto   0)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=54;
						end if;
					when 54 =>
						if(spi_BUSY='0')then		--CRCh
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=55;
						end if;
					when 55 =>
						if(spi_BUSY='0')then		--CRCl
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=56;
						end if;
					when 56 =>
						if(spi_BUSY='0')then		--ff
							SD_INSLOT<='1';
							SD_CS<='1';
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=57;
						end if;
					when 57 =>
						if(spi_BUSY='0')then
							proc_end<='1';
							int_state<=0;
						end if;
					when others =>
						int_state<=0;
					end case;
				end if;
			elsif(state=st_CHGBSIZE)then
				if(proc_bgn='1')then
					int_state<=1;
					waitcount<=20;
				elsif(waitcount>0)then
					if(sdsft='1')then
						waitcount<=waitcount-1;
					end if;
				else
					case int_state is
					when 1 =>					--cmd16
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"50";
							spi_TX<='1';
							int_state<=2;
						end if;
					when 2 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=3;
						end if;
					when 3 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=4;
						end if;
					when 4 =>
						if(spi_BUSY='0')then
							case blksize is
							when x"8" =>
								spi_WRDAT<=x"01";
							when x"9" =>
								spi_WRDAT<=x"02";
							when x"a" =>
								spi_WRDAT<=x"04";
							when others =>
								spi_WRDAT<=x"01";
							end case;
							spi_TX<='1';
							int_state<=5;
						end if;
					when 5 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=6;
						end if;
					when 6 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_state<=7;
						end if;
					when 7=>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								int_state<=8;
								waitcount<=20;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=1;
								waitcount<=40;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								waitcount<=40;
								int_state<=1;
							end case;
						end if;
					when 8 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_state<=9;
					when 9 =>
						if(spi_BUSY='0')then
							proc_end<='1';
							int_state<=0;
						end if;
					when others =>
						int_state<=0;
					end case;
				end if;
			elsif(state=st_EXEC)then
				if(proc_bgn='1')then
					int_state<=1;
				else
					case s_OPCODE is
					when x"00" =>			--Test drive ready
						case int_state is
						when 1 =>
							if(SD_INSLOT='1')then
								s_STATUS<=x"00";
							else
								s_STATUS<=x"ff";
							end if;
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_state<=0;
						when others =>
							int_state<=0;
						end case;
					when x"01" =>			--Recalibrate
						case int_state is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_state<=0;
						when others =>
							int_state<=0;
						end case;
					when x"03" =>			--Request sense status
						case int_state is
						when 1 =>
							s_DIR<='1';
							dev_rdat<=dev_ERRCODE;
							int_state<=2;
						when 2 =>
							dev_rd<='1';
							dev_rdat<=dev_ERRADDR(23 downto 16);
							int_state<=3;
						when 3 =>
							if(dev_rddone='1')then
								dev_rdat<=dev_ERRADDR(15 downto 8);
								int_state<=4;
							end if;
						when 4 =>
							if(dev_rddone='1')then
								dev_rdat<=dev_ERRADDR(7 downto 0);
								int_state<=5;
							end if;
						when 5 =>
							if(dev_rddone='1')then
								dev_rd<='0';
								proc_end<='1';
								int_state<=0;
							end if;
						when others =>
							int_state<=0;
						end case;
					when x"04" =>			--Format Unit
						case int_state is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_state<=0;
						when others =>
							int_state<=0;
						end case;
					when x"06" =>			--Format Track
						case int_state is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_state<=0;
						when others =>
							int_state<=0;
						end case;
					when x"08" =>			--Read
						case int_state is
						when 1 =>
							s_DIR<='1';
							blkcount<=(others=>'0');
							int_state<=2;
							dev_rd<='0';
						when 2 =>
							if(blkcount=s_BLOCKS)then
								int_state<=90;
							else
								int_state<=3;
							end if;
						when 3 =>
							if(spi_BUSY='0')then
								SD_CS<='0';
								spi_WRDAT<=x"51";
								spi_TX<='1';
								int_state<=4;
							end if;
						when 4 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(31 downto 24);
								spi_TX<='1';
								int_state<=5;
							end if;
						when 5 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(23 downto 16);
								spi_TX<='1';
								int_state<=6;
							end if;
						when 6 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(15 downto 8);
								spi_TX<='1';
								int_state<=7;
							end if;
						when 7 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(7 downto 0);
								spi_TX<='1';
								int_state<=8;
							end if;
						when 8 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(dummy)
								spi_TX<='1';
								int_state<=9;
							end if;
						when 9=>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"00" =>
									int_state<=10;
									waitcount<=20;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									waitcount<=40;
									int_state<=1;
								end case;
							end if;
						when 10 =>
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_state<=11;
						when 11 =>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"fe" =>
									int_state<=20;
									waitcount<=20;
									bytecount<=255;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									if(spi_RDDAT(7 downto 5)="000")then
										int_state<=80;
									else
										waitcount<=40;
										int_state<=1;
									end if;
								end case;
							end if;
						when 20 =>
							bdupcount<=blkdup-1;
							spi_WRDAT<=x"ff";	--read
							spi_TX<='1';
							int_state<=21;
						when 21 =>
							if(spi_BUSY='0')then
								if(bdupcount>0)then
									spi_WRDAT<=x"ff";	--read
									spi_TX<='1';
									bdupcount<=bdupcount-1;
								else
									dev_rd<='1';
									dev_rdat<=spi_RDDAT;
									int_state<=22;
								end if;
							end if;
						when 22 =>
							if(dev_rddone='1')then
								dev_rd<='0';
								int_state<=23;
							end if;
						when 23 =>
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							if(bytecount>0)then
								bytecount<=bytecount-1;
								int_state<=20;
							else
								int_state<=24;
							end if;
						when 24 =>
							if(spi_BUSY='0')then	--CRC(H)
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=25;
							end if;
						when 25 =>
							if(spi_BUSY='0')then	--CRC(L)
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=26;
							end if;
						when 26 =>
							if(spi_BUSY='0')then	--dummy
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=30;
							end if;
						when 30 =>
							if(spi_BUSY='0')then
								int_state<=31;
							end if;
						when 31 =>
							blkcount<=blkcount+x"01";
							int_state<=2;
						when 80 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"02";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_state<=0;
							end if;
						when 90 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"00";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_state<=0;
							end if;
						when others =>
							int_state<=0;
						end case;
					when x"0a" =>		---Write
						case int_state is
						when 1 =>
							s_DIR<='0';
							dev_wbusy<='1';
							blkcount<=(others=>'0');
							int_state<=2;
						when 2 =>
							if(blkcount=s_BLOCKS)then
								int_state<=90;
							else
								int_state<=3;
							end if;
						when 3 =>
							if(spi_BUSY='0')then
								SD_CS<='0';
								spi_WRDAT<=x"58";	--cmd24
								spi_TX<='1';
								int_state<=4;
							end if;
						when 4 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(31 downto 24);
								spi_TX<='1';
								int_state<=5;
							end if;
						when 5 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(23 downto 16);
								spi_TX<='1';
								int_state<=6;
							end if;
						when 6 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(15 downto 8);
								spi_TX<='1';
								int_state<=7;
							end if;
						when 7 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(7 downto 0);
								spi_TX<='1';
								int_state<=8;
							end if;
						when 8 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(dummy)
								spi_TX<='1';
								int_state<=9;
							end if;
						when 9=>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"00" =>
									int_state<=10;
									waitcount<=20;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									waitcount<=40;
									int_state<=1;
								end case;
							end if;
						when 10 =>
							spi_WRDAT<=x"fe";	--start byte
							dev_wbusy<='0';
							spi_TX<='1';
							bytecount<=255;
							int_state<=20;
						when 20 =>
							if(dev_wr='1')then
								dev_wbusy<='1';
								bdupcount<=blkdup-1;
								int_state<=21;
							end if;
						when 21 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=dev_wdat;
								spi_TX<='1';
								int_state<=22;
							end if;
						when 22 =>
							if(bdupcount>0)then
								bdupcount<=bdupcount-1;
								int_state<=21;
							else
								int_state<=23;
							end if;
						when 23 =>
							if(bytecount>0)then
								bytecount<=bytecount-1;
								dev_wbusy<='0';
								int_state<=20;
							else
								int_state<=24;
							end if;
						when 24 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(H)
								spi_TX<='1';
								int_state<=25;
							end if;
						when 25 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(L)
								spi_TX<='1';
								int_state<=26;
							end if;
						when 26 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"ff";	--read
								spi_TX<='1';
								int_state<=30;
							end if;
						when 30 =>
							if(spi_BUSY='0')then
								if(spi_RDDAT(4 downto 0)="00101")then
									spi_WRDAT<=x"ff";	--read
									spi_TX<='1';
									int_state<=31;
								else
									int_state<=80;	--error
								end if;
							end if;
						when 31 =>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"ff" =>
									int_state<=32;
								when others =>
									spi_WRDAT<=x"ff";	--read
									spi_TX<='1';
								end case;
							end if;
						when 32 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_state<=33;
							end if;
						when 33 =>
							blkcount<=blkcount+x"01";
							int_state<=2;
						when 80 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"02";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_state<=0;
							end if;
						when 90 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"00";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_state<=0;
							end if;
						when others =>
							int_state<=0;
						end case;
					when x"c2" =>			--vendor
						case int_state is
						when 1 =>
							s_DIR<='0';
							dev_wbusy<='0';
							int_state<=2;
						when 2 =>
							if(dev_wr='1')then
								int_state<=3;
							end if;
						when 3 =>
							if(dev_wr='1')then
								int_state<=4;
							end if;
						when 4 =>
							if(dev_wr='1')then
								int_state<=5;
							end if;
						when 5 =>
							if(dev_wr='1')then
								int_state<=6;
							end if;
						when 6 =>
							if(dev_wr='1')then
								int_state<=7;
							end if;
						when 7 =>
							if(dev_wr='1')then
								int_state<=8;
							end if;
						when 8 =>
							if(dev_wr='1')then
								int_state<=9;
							end if;
						when 9 =>
							if(dev_wr='1')then
								int_state<=10;
							end if;
						when 10 =>
							if(dev_wr='1')then
								int_state<=11;
							end if;
						when 11 =>
							if(dev_wr='1')then
								int_state<=12;
							end if;
						when 12 =>
							dev_wbusy<='1';
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_state<=0;
						when others =>
							int_state<=0;
						end case;
					when others =>
						s_STATUS<=x"00";
						s_MESSAGE<=x"00";
						proc_end<='1';
						int_state<=0;
					end case;
				end if;
			end if;
		end if;
	end process;
	C_SIZE<=CSD(73 downto 62);
	C_SIZE_MULT<=CSD(49 downto 47);
end rtl;
