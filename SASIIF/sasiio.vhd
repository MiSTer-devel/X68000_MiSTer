library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity sasiio is
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
end sasiio;

architecture rtl of sasiio is
signal	iowdat	:std_logic_vector(7 downto 0);
signal	CMDWR	:std_logic;
signal	IDWR	:std_logic;
signal	IDCLR	:std_logic;
signal	BUSRST	:std_logic;
signal	BUSY	:std_logic;
signal	REQ		:std_logic;
signal	adrwr,ladrwr	:std_logic_vector(3 downto 0);
signal	adrrd,ladrrd	:std_logic_vector(3 downto 0);
signal	CMDRD	:std_logic;
signal	C_Dn	:std_logic;
signal	MSG		:std_logic;
signal	I_On	:std_logic;
signal	RDDAT_DAT	:std_logic_vector(7 downto 0);
signal	RDDAT_STA	:std_logic_vector(7 downto 0);
type state_t	is(
	st_IDLE,
	st_SEL,
	st_SELA,
	st_CMD0,
	st_CMD1,
	st_CMD2,
	st_CMD3,
	st_CMD4,
	st_CMD5,
	st_EXEC,
	st_EXECD,
	st_EXECW,
	st_STA,
	st_MSG
);
signal	STATE	:state_t;

begin
	process(clk,rstn)begin
		if(rstn='0')then
			ladrwr<=(others=>'0');
			iowdat<=(others=>'0');
			ladrrd<=(others=>'0');
		elsif(clk' event and clk='1')then
			ladrwr<=adrwr;
			ladrrd<=adrrd;
			if(cs='1' and wr='1')then
				iowdat<=wdat;
			end if;
		end if;
	end process;
	
--	process(clkcs,rd,wr,addr)begin
	process(clk)begin
		if(clk' event and clk='1')then
			if(cs='1' and wr='1')then
				case addr is
				when "00" =>
					adrwr<="0001";
				when "01" =>
					adrwr<="0010";
				when "10" =>
					adrwr<="0100";
				when "11" =>
					adrwr<="1000";
				when others =>
					adrwr<="0000";
				end case;
			else
				adrwr<="0000";
			end if;
			if(cs='1' and rd='1')then
				case addr is
				when "00" =>
					adrrd<="0001";
				when "01" =>
					adrrd<="0010";
				when "10" =>
					adrrd<="0100";
				when "11" =>
					adrrd<="1000";
				when others =>
					adrrd<="0000";
				end case;
			else
				adrrd<="0000";
			end if;
		end if;
	end process;
	
	IDWR<=	'1' when adrwr(3)='0' and ladrwr(3)='1' else '0';
	BUSRST<='1' when adrwr(2)='0' and ladrwr(2)='1' else '0';
	IDCLR<=	'1' when adrwr(1)='0' and ladrwr(1)='1' else '0';
	CMDWR<=	'1' when adrwr(0)='0' and ladrwr(0)='1' else '0';
	CMDRD<=	'1' when adrrd(0)='0' and ladrrd(0)='1' else '0';

	process(clk,rstn)begin
		if(rstn='0')then
			STATE<=st_IDLE;
			IDSEL<=(others=>'0');
			OPCODE<=(others=>'0');
			UADDR<=(others=>'0');
			BLOCKS<=(others=>'0');
			CONTROL<=(others=>'0');
			EXEBGN<='0';
			I_On<='0';
			C_Dn<='0';
			MSG<='0';
			REQ<='0';
			dev_wr<='0';
			dev_rddone<='0';
			drq<='0';
		elsif(clk' event and clk='1')then
			IDSET<='0';
			EXEBGN<='0';
			dev_wr<='0';
			dev_rddone<='0';
			if(BUSRST='1')then
				STATE<=st_IDLE;
				I_On<='0';
				C_Dn<='0';
				MSG<='0';
				REQ<='0';
				drq<='0';
			elsif(IDWR='1')then
				IDSEL<=(others=>'0');
				for i in 7 downto 0 loop
					if(iowdat(i)='1')then
						IDSEL<=conv_std_logic_vector(i,3);
						IDSET<='1';
						STATE<=st_SEL;
					end if;
				end loop;
				I_On<='0';
				C_Dn<='0';
				MSG<='0';
				REQ<='0';
			else
				case STATE is
				when st_SEL =>
					if(IDACK='1')then
						STATE<=st_SELA;
					end if;
				when st_SELA =>
					if(IDCLR='1')then
						STATE<=st_CMD0;
						C_Dn<='1';
						REQ<='1';
					end if;
				when st_CMD0 =>
					if(CMDWR='1')then
						OPCODE<=iowdat;
						STATE<=st_CMD1;
					end if;
				when st_CMD1 =>
					if(CMDWR='1')then
						UADDR(23 downto 16)<=iowdat;
						STATE<=st_CMD2;
					end if;
				when st_CMD2 =>
					if(CMDWR='1')then
						UADDR(15 downto 8)<=iowdat;
						STATE<=st_CMD3;
					end if;
				when st_CMD3 =>
					if(CMDWR='1')then
						UADDR(7 downto 0)<=iowdat;
						STATE<=st_CMD4;
					end if;
				when st_CMD4 =>
					if(CMDWR='1')then
						BLOCKS<=iowdat;
						STATE<=st_CMD5;
					end if;
				when st_CMD5 =>
					if(CMDWR='1')then
						CONTROL<=iowdat;
						EXEBGN<='1';
						C_Dn<='0';
						REQ<='0';
						STATE<=st_EXEC;
					end if;
				when st_EXEC =>
					if(EXECOMP='1')then
						C_Dn<='1';
						I_On<='1';
						REQ<='1';
						STATE<=st_STA;
					else
						I_On<=DIR;
						case DIR is
						when '0' =>
							if(dev_wbusy='1')then
								REQ<='0';
								drq<='0';
							else
								REQ<='1';
								drq<='1';
								if(CMDWR='1')then
									REQ<='0';
									drq<='0';
									dev_wr<='1';
									STATE<=st_EXECD;
								end if;
							end if;
						when '1' =>
							if(dev_rd='1')then
								REQ<='1';
								drq<='1';
								STATE<=st_EXECD;
							else
								REQ<='0';
								drq<='0';
							end if;
						when others =>
						end case;
					end if;
				when st_EXECD =>
					if(EXECOMP='1')then
						C_Dn<='1';
						I_On<='1';
						REQ<='1';
						STATE<=st_STA;
					else
						case DIR is
						when '0' =>
							if(dev_wbusy='0')then
								STATE<=st_EXECW;
							end if;
						when '1' =>
							if(CMDRD='1')then
								dev_rddone<='1';
								REQ<='0';
								drq<='0';
								STATE<=st_EXECW;
							end if;
						when others =>
						end case;
					end if;
				when st_EXECW =>
					if(EXECOMP='1')then
						C_Dn<='1';
						I_On<='1';
						REQ<='1';
						STATE<=st_STA;
					else
						STATE<=st_EXEC;
					end if;
				when st_STA =>
					if(CMDRD='1')then
						MSG<='1';
						STATE<=st_MSG;
					end if;
				when st_MSG =>
					if(CMDRD='1')then
						I_On<='0';
						C_Dn<='0';
						MSG<='0';
						REQ<='0';
						STATE<=st_IDLE;
					end if;
				when others =>
					I_On<='0';
					C_Dn<='0';
					MSG<='0';
					REQ<='0';
					STATE<=st_IDLE;
				end case;
			end if;
		end if;
	end process;
	
	dev_wdat<=iowdat;
	RDDAT_DAT<=	dev_rdat	when STATE=st_EXEC or STATE=st_EXECD else
				STATUS		when STATE=st_STA else
				MESSAGE		when STATE=st_MSG else
				(others=>'0');
	BUSY<=	'0' when STATE=st_IDLE else
			'0' when STATE=st_SEL else
			'1';
	RDDAT_STA<=	"000" & MSG & C_Dn & I_On & BUSY & REQ;
	rdat<=	RDDAT_DAT when adrrd="0001" else
			RDDAT_STA when adrrd="0010" else
			(others=>'0');
	
	doe<=	'1' when adrrd="0001" else
			'1' when adrrd="0010" else
			'0';
	int<='1' when STATE=st_STA else '0';
	
end rtl;
