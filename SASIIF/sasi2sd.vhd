library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity sasi2sd is
port(
	IDAT	:in std_logic_vector(7 downto 0);
	ODAT	:out std_logic_vector(7 downto 0);
	SEL		:in std_logic;
	BSY		:out std_logic;
	REQ		:out std_logic;
	ACK		:in std_logic;
	IO		:out std_logic;
	CD		:out std_logic;
	MSG		:out std_logic;
	RST		:in std_logic;

	
	SCLK	:out std_logic;
	SDI		:in std_logic;
	SDO		:out std_logic;
	SD_CS	:out std_logic;
	
	BUSY	:out std_logic;

	sdsft	:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end sasi2sd;

architecture rtl of sasi2sd is
signal	BSYb		:std_logic;
signal	REQb		:std_logic;
signal	CDb			:std_logic;
signal	IOb			:std_logic;
signal	MSGb		:std_logic;
signal	s_IDSEL		:std_logic_vector(2 downto 0);
signal	s_OPCODE	:std_logic_vector(7 downto 0);
signal	s_UADDR		:std_logic_vector(23 downto 0);
signal	s_BLOCKS	:std_logic_vector(7 downto 0);
signal	s_CONTROL	:std_logic_vector(7 downto 0);
signal	s_DIR		:std_logic;
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

signal	int_sdstate	:integer range 0 to 100;
signal	blkcount	:std_logic_vector(7 downto 0);
signal	bytecount	:integer range 0 to 255;
signal	blkdup		:integer range 1 to 4;
signal	bdupcount	:integer range 0 to 3;

signal	C_SIZE		:std_logic_vector(11 downto 0);
signal	C_SIZE_MULT	:std_logic_vector(2 downto 0);
signal	CAPA8		:std_logic_vector(18 downto 0);
signal	CAPA9		:std_logic_vector(18 downto 0);
signal	CAPA		:std_logic_vector(18 downto 0);
signal	unites		:integer range 0 to 16;

signal	CSD			:std_logic_vector(127 downto 0);
signal	dev_ERRCODE	:std_logic_vector(7 downto 0);
signal	dev_ERRADDR	:std_logic_vector(23 downto 0);

signal	sft		:std_logic;
signal	waitcount	:integer range 0 to 100;

signal	sd_addr_org	:std_logic_vector(31 downto 0);
signal	sd_addr_off	:std_logic_vector(31 downto 0);
signal	sd_addr		:std_logic_vector(31 downto 0);

type sdstate_t is(
	sdst_PINIT,
	sdst_INIT,
	sdst_CHGBSIZE,
	sdst_IDLE,
	sdst_EXEC
);
signal	sdstate	:sdstate_t;

type spstate_t	is(
	spst_IDLE,
	spst_SEL,
	spst_CMD0,
	spst_CMD0A,
	spst_CMD1,
	spst_CMD1A,
	spst_CMD2,
	spst_CMD2A,
	spst_CMD3,
	spst_CMD3A,
	spst_CMD4,
	spst_CMD4A,
	spst_CMD5,
	spst_CMD5A,
	spst_EXEC,
	spst_EXECR,
	spst_EXECW,
	spst_EXECA,
	spst_STA,
	spst_STAA,
	spst_MSG,
	spst_MSGA
);
signal	spstate	:spstate_t;

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

begin


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
			spstate<=spst_IDLE;
			BSYb<='0';
			REQb<='0';
			CDb<='0';
			IOb<='0';
			MSGb<='0';
			s_EXEBGN<='0';
			dev_wdat<=(others=>'0');
			dev_rddone<='0';
			dev_wr<='0';
			ODAT<=(others=>'0');
		elsif(clk' event and clk='1')then
			s_EXEBGN<='0';
			dev_rddone<='0';
			dev_wr<='0';
			if(RST='1')then
				spstate<=spst_IDLE;
				BSYb<='0';
				REQb<='0';
				CDb<='0';
				IOb<='0';
				MSGb<='0';
				dev_wdat<=(others=>'0');
				ODAT<=(others=>'0');
			else
				case spstate is
				when spst_IDLE =>
					BSYb<='0';
					if(SEL='1')then
						if(SD_INSLOT='1')then
							for i in 0 to 7 loop
								if(IDAT(i)='1' and (i*2)<unites)then
									BSYb<='1';
									spstate<=spst_SEL;
									s_IDSEL<=conv_std_logic_vector(i,3);
								end if;
							end loop;
						end if;
					end if;
				when spst_SEL =>
					if(SEL='0')then
						CDb<='1';
						REQb<='1';
						spstate<=spst_CMD0;
					end if;
				when spst_CMD0 =>
					if(ACK='1')then
						s_OPCODE<=IDAT;
						REQb<='0';
						spstate<=spst_CMD0A;
					end if;
				when spst_CMD0A =>
					if(ACK='0')then
						REQb<='1';
						spstate<=spst_CMD1;
					end if;
				when spst_CMD1 =>
					if(ACK='1')then
						s_UADDR(23 downto 16)<=IDAT;
						REQb<='0';
						spstate<=spst_CMD1A;
					end if;
				when spst_CMD1A =>
					if(ACK='0')then
						REQb<='1';
						spstate<=spst_CMD2;
					end if;
				when spst_CMD2 =>
					if(ACK='1')then
						s_UADDR(15 downto 8)<=IDAT;
						REQb<='0';
						spstate<=spst_CMD2A;
					end if;
				when spst_CMD2A =>
					if(ACK='0')then
						REQb<='1';
						spstate<=spst_CMD3;
					end if;
				when spst_CMD3 =>
					if(ACK='1')then
						s_UADDR(7 downto 0)<=IDAT;
						REQb<='0';
						spstate<=spst_CMD3A;
					end if;
				when spst_CMD3A =>
					if(ACK='0')then
						REQb<='1';
						spstate<=spst_CMD4;
					end if;
				when spst_CMD4 =>
					if(ACK='1')then
						s_BLOCKS<=IDAT;
						REQb<='0';
						spstate<=spst_CMD4A;
					end if;
				when spst_CMD4A =>
					if(ACK='0')then
						REQb<='1';
						spstate<=spst_CMD5;
					end if;
				when spst_CMD5 =>
					if(ACK='1')then
						s_CONTROL<=IDAT;
						REQb<='0';
						spstate<=spst_CMD5A;
					end if;
				when spst_CMD5A =>
					if(ACK='0')then
						CDb<='0';
						spstate<=spst_EXEC;
						s_EXEBGN<='1';
					end if;
				when spst_EXEC =>
					if(s_EXECOMP='1')then
						CDb<='1';
						IOb<='1';
						ODAT<=s_STATUS;
						spstate<=spst_STA;
					else
						IOb<=s_DIR;
						if(s_DIR='1')then
							if(dev_rd='1')then
								ODAT<=dev_rdat;
								REQb<='1';
								spstate<=spst_EXECR;
							end if;
						else
							if(dev_wbusy='0')then
								REQb<='1';
								spstate<=spst_EXECW;
							else
								REQb<='0';
							end if;
						end if;
					end if;
				when spst_EXECR =>
					if(ACK='1')then
						dev_rddone<='1';
						REQb<='0';
						spstate<=spst_EXECA;
					end if;
				when spst_EXECW =>
					if(ACK='1')then
						dev_wdat<=IDAT;
						dev_wr<='1';
						REQb<='0';
						spstate<=spst_EXECA;
					end if;
				when spst_EXECA =>
					if(ACK='0' and dev_rd='0')then
						spstate<=spst_EXEC;
					end if;
				when spst_STA =>
					REQb<='1';
					if(ACK='1')then
						spstate<=spst_STAA;
					end if;
				when spst_STAA =>
					REQb<='0';
					if(ACK='0')then
						ODAT<=s_MESSAGE;
						MSGb<='1';
						spstate<=spst_MSG;
					end if;
				when spst_MSG =>
					REQb<='1';
					if(ACK='1')then
						spstate<=spst_MSGA;
					end if;
				when spst_MSGA =>
					REQb<='0';
					if(ACK='0')then
						ODAT<=(others=>'0');
						BSYb<='0';
						IOb<='0';
						CDb<='0';
						MSGb<='0';
						spstate<=spst_IDLE;
					end if;
				when others =>
					spstate<=spst_IDLE;
				end case;
			end if;
		end if;
	end process;

	process(clk,rstn)begin
		if(rstn='0')then
			sdstate<=sdst_PINIT;
			proc_bgn<='0';
			s_EXECOMP<='0';
			blksize<=(others=>'0');
		elsif(clk' event and clk='1')then
			proc_bgn<='0';
			s_EXECOMP<='0';
			case sdstate is
			when sdst_PINIT =>
				sdstate<=sdst_INIT;
				proc_bgn<='1';
			when sdst_INIT =>
				if(proc_end='1')then
					if(CSD(21)='1' and CSD(79)='1')then
						blksize<=x"8";
					else
						blksize<=x"9";
					end if;
					sdstate<=sdst_CHGBSIZE;
					proc_bgn<='1';
				end if;
			when sdst_CHGBSIZE =>
				if(proc_end='1')then
					sdstate<=sdst_IDLE;
				end if;
			when sdst_IDLE =>
				if(s_EXEBGN='1')then
					sdstate<=sdst_EXEC;
					proc_bgn<='1';
				end if;
			when sdst_EXEC =>
				if(proc_end='1')then
					s_EXECOMP<='1';
					sdstate<=sdst_IDLE;
				end if;
			when others =>
				sdstate<=sdst_IDLE;
			end case;
		end if;
	end process;
	
	BUSY<='0' when sdstate=sdst_PINIT or sdstate=sdst_IDLE else '1';
	
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
			int_sdstate<=0;
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
			if(sdstate=sdst_INIT)then
				if(proc_bgn='1')then
					int_sdstate<=1;
					waitcount<=20;
				elsif(waitcount>0)then
					if(sdsft='1')then
						waitcount<=waitcount-1;
					end if;
				else
					case int_sdstate is
					when 1 =>		--dummy clock x 10byte
						SD_CS<='1';
						spi_WRDAT<=(others=>'1');
						bytecount<=10;
						int_sdstate<=2;
					when 2 =>
						spi_TX<='1';
						int_sdstate<=3;
					when 3 =>
						if(spi_BUSY='0')then
							if(bytecount>0)then
								bytecount<=bytecount-1;
								int_sdstate<=2;
							else
								int_sdstate<=10;
								waitcount<=20;
							end if;
						end if;
					when 10 =>				--CMD00
						SD_CS<='0';
						spi_WRDAT<=x"40";
						spi_TX<='1';
						int_sdstate<=11;
					when 11 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=12;
						end if;
					when 12 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=13;
						end if;
					when 13 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=14;
						end if;
					when 14 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=15;
						end if;
					when 15 =>				--CRC
						if(spi_BUSY='0')then
							spi_WRDAT<=x"95";
							spi_TX<='1';
							int_sdstate<=16;
						end if;
					when 16 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"01" =>
								int_sdstate<=17;
								waitcount<=20;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								SD_CS<='1';
								int_sdstate<=1;
								waitcount<=20;
							end case;
						end if;
					when 17 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_sdstate<=20;
					when 20 =>					--cmd1
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"41";
							spi_TX<='1';
							int_sdstate<=21;
						end if;
					when 21 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=22;
						end if;
					when 22 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=23;
						end if;
					when 23 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=24;
						end if;
					when 24 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=25;
						end if;
					when 25 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"f9";
							spi_TX<='1';
							int_sdstate<=26;
						end if;
					when 26=>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								int_sdstate<=27;
								waitcount<=20;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=20;
								waitcount<=40;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								waitcount<=40;
								int_sdstate<=1;
							end case;
						end if;
					when 27 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_sdstate<=30;
					when 30 =>				--CMD9:Read card config
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"49";
							spi_TX<='1';
							int_sdstate<=31;
						end if;
					when 31 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=32;
						end if;
					when 32 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=33;
						end if;
					when 33 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=34;
						end if;
					when 34 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=35;
						end if;
					when 35 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=36;
						end if;
					when 36 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=37;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=30;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								int_sdstate<=1;
							end case;
						end if;
					when 37 =>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"fe" =>			--data token
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=38;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								int_sdstate<=1;
							end case;
						end if;
					when 38 =>
						if(spi_BUSY='0')then		--data0
							CSD(127 downto 120)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=39;
						end if;
					when 39 =>
						if(spi_BUSY='0')then		--data1
							CSD(119 downto 112)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=40;
						end if;
					when 40 =>
						if(spi_BUSY='0')then		--data2
							CSD(111 downto 104)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=41;
						end if;
					when 41 =>
						if(spi_BUSY='0')then		--data3
							CSD(103 downto  96)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=42;
						end if;
					when 42 =>
						if(spi_BUSY='0')then		--data4
							CSD( 95 downto  88)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=43;
						end if;
					when 43 =>
						if(spi_BUSY='0')then		--data5
							CSD( 87 downto  80)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=44;
						end if;
					when 44 =>
						if(spi_BUSY='0')then		--data6
							CSD( 79 downto  72)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=45;
						end if;
					when 45 =>
						if(spi_BUSY='0')then		--data7
							CSD( 71 downto  64)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=46;
						end if;
					when 46 =>
						if(spi_BUSY='0')then		--data8
							CSD( 63 downto  56)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=47;
						end if;
					when 47 =>
						if(spi_BUSY='0')then		--data9
							CSD( 55 downto  48)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=48;
						end if;
					when 48 =>
						if(spi_BUSY='0')then		--data10
							CSD( 47 downto  40)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=49;
						end if;
					when 49 =>
						if(spi_BUSY='0')then		--data11
							CSD( 39 downto  32)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=50;
						end if;
					when 50 =>
						if(spi_BUSY='0')then		--data12
							CSD( 31 downto  24)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=51;
						end if;
					when 51 =>
						if(spi_BUSY='0')then		--data13
							CSD( 23 downto  16)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=52;
						end if;
					when 52 =>
						if(spi_BUSY='0')then		--data14
							CSD( 15 downto   8)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=53;
						end if;
					when 53 =>
						if(spi_BUSY='0')then		--data15
							CSD(  7 downto   0)<=spi_RDDAT;
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=54;
						end if;
					when 54 =>
						if(spi_BUSY='0')then		--CRCh
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=55;
						end if;
					when 55 =>
						if(spi_BUSY='0')then		--CRCl
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=56;
						end if;
					when 56 =>
						if(spi_BUSY='0')then		--ff
							SD_INSLOT<='1';
							SD_CS<='1';
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=57;
						end if;
					when 57 =>
						if(spi_BUSY='0')then
							proc_end<='1';
							int_sdstate<=0;
						end if;
					when others =>
						int_sdstate<=0;
					end case;
				end if;
			elsif(sdstate=sdst_CHGBSIZE)then
				if(proc_bgn='1')then
					int_sdstate<=1;
					waitcount<=20;
				elsif(waitcount>0)then
					if(sdsft='1')then
						waitcount<=waitcount-1;
					end if;
				else
					case int_sdstate is
					when 1 =>					--cmd16
						if(spi_BUSY='0')then
							SD_CS<='0';
							spi_WRDAT<=x"50";
							spi_TX<='1';
							int_sdstate<=2;
						end if;
					when 2 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=3;
						end if;
					when 3 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=4;
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
							int_sdstate<=5;
						end if;
					when 5 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=6;
						end if;
					when 6 =>
						if(spi_BUSY='0')then
							spi_WRDAT<=x"00";
							spi_TX<='1';
							int_sdstate<=7;
						end if;
					when 7=>
						if(spi_BUSY='0')then
							case spi_RDDAT is
							when x"00" =>
								int_sdstate<=8;
								waitcount<=20;
							when x"01" =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=1;
								waitcount<=40;
							when x"ff" =>
								spi_WRDAT<=x"ff";
								spi_TX<='1';
							when others =>
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								waitcount<=40;
								int_sdstate<=1;
							end case;
						end if;
					when 8 =>
						SD_CS<='1';
						spi_WRDAT<=x"ff";
						spi_TX<='1';
						int_sdstate<=9;
					when 9 =>
						if(spi_BUSY='0')then
							proc_end<='1';
							int_sdstate<=0;
						end if;
					when others =>
						int_sdstate<=0;
					end case;
				end if;
			elsif(sdstate=sdst_EXEC)then
				if(proc_bgn='1')then
					int_sdstate<=1;
				else
					case s_OPCODE is
					when x"00" =>			--Test drive ready
						case int_sdstate is
						when 1 =>
							if(SD_INSLOT='1')then
								s_STATUS<=x"00";
							else
								s_STATUS<=x"ff";
							end if;
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_sdstate<=0;
						when others =>
							int_sdstate<=0;
						end case;
					when x"01" =>			--Recalibrate
						case int_sdstate is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_sdstate<=0;
						when others =>
							int_sdstate<=0;
						end case;
					when x"03" =>			--Request sense status
						case int_sdstate is
						when 1 =>
							s_DIR<='1';
							dev_rdat<=dev_ERRCODE;
							int_sdstate<=2;
						when 2 =>
							dev_rd<='1';
							dev_rdat<=dev_ERRADDR(23 downto 16);
							int_sdstate<=3;
						when 3 =>
							if(dev_rddone='1')then
								dev_rdat<=dev_ERRADDR(15 downto 8);
								int_sdstate<=4;
							end if;
						when 4 =>
							if(dev_rddone='1')then
								dev_rdat<=dev_ERRADDR(7 downto 0);
								int_sdstate<=5;
							end if;
						when 5 =>
							if(dev_rddone='1')then
								dev_rd<='0';
								proc_end<='1';
								int_sdstate<=0;
							end if;
						when others =>
							int_sdstate<=0;
						end case;
					when x"04" =>			--Format Unit
						case int_sdstate is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_sdstate<=0;
						when others =>
							int_sdstate<=0;
						end case;
					when x"06" =>			--Format Track
						case int_sdstate is
						when 1 =>
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_sdstate<=0;
						when others =>
							int_sdstate<=0;
						end case;
					when x"08" =>			--Read
						case int_sdstate is
						when 1 =>
							s_DIR<='1';
							blkcount<=(others=>'0');
							int_sdstate<=2;
							dev_rd<='0';
						when 2 =>
							if(blkcount=s_BLOCKS)then
								int_sdstate<=90;
							else
								int_sdstate<=3;
							end if;
						when 3 =>
							if(spi_BUSY='0')then
								SD_CS<='0';
								spi_WRDAT<=x"51";
								spi_TX<='1';
								int_sdstate<=4;
							end if;
						when 4 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(31 downto 24);
								spi_TX<='1';
								int_sdstate<=5;
							end if;
						when 5 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(23 downto 16);
								spi_TX<='1';
								int_sdstate<=6;
							end if;
						when 6 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(15 downto 8);
								spi_TX<='1';
								int_sdstate<=7;
							end if;
						when 7 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(7 downto 0);
								spi_TX<='1';
								int_sdstate<=8;
							end if;
						when 8 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(dummy)
								spi_TX<='1';
								int_sdstate<=9;
							end if;
						when 9=>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"00" =>
									int_sdstate<=10;
									waitcount<=20;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									waitcount<=40;
									int_sdstate<=1;
								end case;
							end if;
						when 10 =>
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							int_sdstate<=11;
						when 11 =>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"fe" =>
									int_sdstate<=20;
									waitcount<=20;
									bytecount<=255;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									if(spi_RDDAT(7 downto 5)="000")then
										int_sdstate<=80;
									else
										waitcount<=40;
										int_sdstate<=1;
									end if;
								end case;
							end if;
						when 20 =>
							bdupcount<=blkdup-1;
							spi_WRDAT<=x"ff";	--read
							spi_TX<='1';
							int_sdstate<=21;
						when 21 =>
							if(spi_BUSY='0')then
								if(bdupcount>0)then
									spi_WRDAT<=x"ff";	--read
									spi_TX<='1';
									bdupcount<=bdupcount-1;
								else
									dev_rd<='1';
									dev_rdat<=spi_RDDAT;
									int_sdstate<=22;
								end if;
							end if;
						when 22 =>
							if(dev_rddone='1')then
								dev_rd<='0';
								int_sdstate<=23;
							end if;
						when 23 =>
							spi_WRDAT<=x"ff";
							spi_TX<='1';
							if(bytecount>0)then
								bytecount<=bytecount-1;
								int_sdstate<=20;
							else
								int_sdstate<=24;
							end if;
						when 24 =>
							if(spi_BUSY='0')then	--CRC(H)
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=25;
							end if;
						when 25 =>
							if(spi_BUSY='0')then	--CRC(L)
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=26;
							end if;
						when 26 =>
							if(spi_BUSY='0')then	--dummy
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								int_sdstate<=30;
							end if;
						when 30 =>
							if(spi_BUSY='0')then
								int_sdstate<=31;
							end if;
						when 31 =>
							blkcount<=blkcount+x"01";
							int_sdstate<=2;
						when 80 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"02";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_sdstate<=0;
							end if;
						when 90 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"00";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_sdstate<=0;
							end if;
						when others =>
							int_sdstate<=0;
						end case;
					when x"0a" =>		---Write
						case int_sdstate is
						when 1 =>
							s_DIR<='0';
							dev_wbusy<='1';
							blkcount<=(others=>'0');
							int_sdstate<=2;
						when 2 =>
							if(blkcount=s_BLOCKS)then
								int_sdstate<=90;
							else
								int_sdstate<=3;
							end if;
						when 3 =>
							if(spi_BUSY='0')then
								SD_CS<='0';
								spi_WRDAT<=x"58";	--cmd24
								spi_TX<='1';
								int_sdstate<=4;
							end if;
						when 4 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(31 downto 24);
								spi_TX<='1';
								int_sdstate<=5;
							end if;
						when 5 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(23 downto 16);
								spi_TX<='1';
								int_sdstate<=6;
							end if;
						when 6 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(15 downto 8);
								spi_TX<='1';
								int_sdstate<=7;
							end if;
						when 7 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=sd_addr(7 downto 0);
								spi_TX<='1';
								int_sdstate<=8;
							end if;
						when 8 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(dummy)
								spi_TX<='1';
								int_sdstate<=9;
							end if;
						when 9=>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"00" =>
									int_sdstate<=10;
									waitcount<=20;
								when x"ff" =>
									spi_WRDAT<=x"ff";
									spi_TX<='1';
								when others =>
									waitcount<=40;
									int_sdstate<=1;
								end case;
							end if;
						when 10 =>
							spi_WRDAT<=x"fe";	--start byte
							dev_wbusy<='0';
							spi_TX<='1';
							bytecount<=255;
							int_sdstate<=20;
						when 20 =>
							if(dev_wr='1')then
								dev_wbusy<='1';
								bdupcount<=blkdup-1;
								int_sdstate<=21;
							end if;
						when 21 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=dev_wdat;
								spi_TX<='1';
								int_sdstate<=22;
							end if;
						when 22 =>
							if(bdupcount>0)then
								bdupcount<=bdupcount-1;
								int_sdstate<=21;
							else
								int_sdstate<=23;
							end if;
						when 23 =>
							if(bytecount>0)then
								bytecount<=bytecount-1;
								dev_wbusy<='0';
								int_sdstate<=20;
							else
								int_sdstate<=24;
							end if;
						when 24 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(H)
								spi_TX<='1';
								int_sdstate<=25;
							end if;
						when 25 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"00";	--CRC(L)
								spi_TX<='1';
								int_sdstate<=26;
							end if;
						when 26 =>
							if(spi_BUSY='0')then
								spi_WRDAT<=x"ff";	--read
								spi_TX<='1';
								int_sdstate<=30;
							end if;
						when 30 =>
							if(spi_BUSY='0')then
								if(spi_RDDAT(4 downto 0)="00101")then
									spi_WRDAT<=x"ff";	--read
									spi_TX<='1';
									int_sdstate<=31;
								else
									int_sdstate<=80;	--error
								end if;
							end if;
						when 31 =>
							if(spi_BUSY='0')then
								case spi_RDDAT is
								when x"ff" =>
									int_sdstate<=32;
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
								int_sdstate<=33;
							end if;
						when 33 =>
							blkcount<=blkcount+x"01";
							int_sdstate<=2;
						when 80 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"02";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_sdstate<=0;
							end if;
						when 90 =>
							if(spi_BUSY='0')then
								SD_CS<='1';
								spi_WRDAT<=x"ff";
								spi_TX<='1';
								s_STATUS<=x"00";
								s_MESSAGE<=x"00";
								proc_end<='1';
								int_sdstate<=0;
							end if;
						when others =>
							int_sdstate<=0;
						end case;
					when x"c2" =>			--vendor
						case int_sdstate is
						when 1 =>
							s_DIR<='0';
							dev_wbusy<='0';
							int_sdstate<=2;
						when 2 =>
							if(dev_wr='1')then
								int_sdstate<=3;
							end if;
						when 3 =>
							if(dev_wr='1')then
								int_sdstate<=4;
							end if;
						when 4 =>
							if(dev_wr='1')then
								int_sdstate<=5;
							end if;
						when 5 =>
							if(dev_wr='1')then
								int_sdstate<=6;
							end if;
						when 6 =>
							if(dev_wr='1')then
								int_sdstate<=7;
							end if;
						when 7 =>
							if(dev_wr='1')then
								int_sdstate<=8;
							end if;
						when 8 =>
							if(dev_wr='1')then
								int_sdstate<=9;
							end if;
						when 9 =>
							if(dev_wr='1')then
								int_sdstate<=10;
							end if;
						when 10 =>
							if(dev_wr='1')then
								int_sdstate<=11;
							end if;
						when 11 =>
							if(dev_wr='1')then
								int_sdstate<=12;
							end if;
						when 12 =>
							dev_wbusy<='1';
							s_STATUS<=x"00";
							s_MESSAGE<=x"00";
							proc_end<='1';
							int_sdstate<=0;
						when others =>
							int_sdstate<=0;
						end case;
					when others =>
						s_STATUS<=x"00";
						s_MESSAGE<=x"00";
						proc_end<='1';
						int_sdstate<=0;
					end case;
				end if;
			end if;
		end if;
	end process;
	C_SIZE<=CSD(73 downto 62);
	C_SIZE_MULT<=CSD(49 downto 47);
	CAPA9<=	"0000000" & C_SIZE		when C_SIZE_MULT="000" else
			"000000" & C_SIZE & '0'	when C_SIZE_MULT="001" else
			"00000" & C_SIZE & "00"	when C_SIZE_MULT="010" else
			"0000" & C_SIZE & "000"	when C_SIZE_MULT="011" else
			"000" & C_SIZE & "0000"	when C_SIZE_MULT="100" else
			"00" & C_SIZE & "00000"	when C_SIZE_MULT="101" else
			'0' & C_SIZE & "000000"	when C_SIZE_MULT="110" else
			     C_SIZE & "0000000"	when C_SIZE_MULT="111" else
			(others=>'0');
	CAPA8<=	"000000" & C_SIZE & '0'	when C_SIZE_MULT="000" else
			"00000" & C_SIZE & "00"	when C_SIZE_MULT="001" else
			"0000" & C_SIZE & "000"	when C_SIZE_MULT="010" else
			"000" & C_SIZE & "0000"	when C_SIZE_MULT="011" else
			"00" & C_SIZE & "00000"	when C_SIZE_MULT="100" else
			'0' & C_SIZE & "000000"	when C_SIZE_MULT="101" else
			     C_SIZE & "0000000"	when C_SIZE_MULT="110" else
			C_SIZE(10 downto 0) & "00000000"	when C_SIZE_MULT="111"  and C_SIZE(11)='0' else
			(others=>'1');
	CAPA<=CAPA8 when blksize=x"8" else CAPA9;
	
	process(CAPA)begin
		if   (CAPA>"1111110000000000000")then
			unites<=16;
		elsif(CAPA>"1111000000000000000")then
			unites<=15;
		elsif(CAPA>"1110000000000000000")then
			unites<=14;
		elsif(CAPA>"1101000000000000000")then
			unites<=13;
		elsif(CAPA>"1100000000000000000")then
			unites<=12;
		elsif(CAPA>"1011000000000000000")then
			unites<=11;
		elsif(CAPA>"1010000000000000000")then
			unites<=10;
		elsif(CAPA>"1001000000000000000")then
			unites<=9;
		elsif(CAPA>"1000000000000000000")then
			unites<=8;
		elsif(CAPA>"0111000000000000000")then
			unites<=7;
		elsif(CAPA>"0110000000000000000")then
			unites<=6;
		elsif(CAPA>"0101000000000000000")then
			unites<=5;
		elsif(CAPA>"0100000000000000000")then
			unites<=4;
		elsif(CAPA>"0011000000000000000")then
			unites<=3;
		elsif(CAPA>"0010000000000000000")then
			unites<=2;
		elsif(CAPA>"0001000000000000000")then
			unites<=1;
		else
			unites<=0;
		end if;
	end process;
	
	BSY<=BSYb;
	REQ<=REQb;
	CD<=CDb;
	IO<=IOb;
	MSG<=MSGb;
	
end rtl;
