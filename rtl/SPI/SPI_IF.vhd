LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SPI_IF is
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
end SPI_IF;

architecture rtl of SPI_IF is
signal	CLKST		:std_logic;
signal	bitcount	:integer range 0 to 8;
signal	txsft		:std_logic_vector(7 downto 0);
signal	rxsft		:std_logic_vector(7 downto 0);
type state_t is (
	st_IDLE,
	st_WAIT,
	st_BUSY
);
signal	state	:state_t;

begin

	SCLK<=CLKST xor MODE(1);
	
	process(clk,rstn)begin
		if(rstn='0')then
			CLKST<='0';
			bitcount<=0;
			txsft<=(others=>'0');
			rxsft<=(others=>'0');
			state<=st_IDLE;
			SDO<='0';
		elsif(clk' event and clk='1')then
			case state is
			when st_IDLE =>
				if(TX='1')then
					txsft<=WRDAT;
					rxsft<=(others=>'0');
					bitcount<=8;
					state<=st_WAIT;
				end if;
			when st_WAIT =>
				if(SFT='1')then
					SDO<=txsft(7);
					txsft(7 downto 1)<=txsft(6 downto 0);
					if(MODE(0)='1')then
						CLKST<='1';
					end if;
					state<=st_BUSY;
				end if;
			when st_BUSY =>
				if(SFT='1')then
					CLKST<=not CLKST;
					if((CLKST xor MODE(0))='0')then
						rxsft<=rxsft(6 downto 0) & SDI;
						if(bitcount>1 or (bitcount>0 and mode(0)='0'))then
							bitcount<=bitcount-1;
						else
							CLKST<='0';
							state<=st_IDLE;
						end if;
					else
						SDO<=txsft(7);
						txsft(7 downto 1)<=txsft(6 downto 0);
					end if;
				end if;
			when others =>
				state<=st_IDLE;
			end case;
		end if;
	end process;
	
	RDDAT<=rxsft;
	BUSY<=	'1' when TX='1' else
			'0' when state=st_IDLE else
			'1';
end rtl;
						
					
					