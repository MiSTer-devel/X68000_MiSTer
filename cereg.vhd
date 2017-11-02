LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cereg is
generic(
	awidth	:integer	:=8
);
port(
	wraddr	:in std_logic_vector(awidth-1 downto 0);
	wr		:in std_logic;
	wdat	:in std_logic;
	
	rdaddr	:in std_logic_vector(awidth-1 downto 0);
	rd		:out std_logic;
	
	wclk	:in std_logic;
	rclk	:in std_logic
);
end cereg;

architecture rtl of cereg is
constant bits	:integer	:=2**awidth;
signal	flag	:std_logic_vector(bits-1 downto 0);
signal	iaddr	:integer range 0 to bits-1;
signal	lrclk	:std_logic;
signal	mask	:std_logic;
signal	mcount	:integer range 0 to 2;
signal	rdm		:std_logic;
signal	riaddr	:integer range 0 to bits-1;
signal	wrb		:std_logic;
signal	wdatb	:std_logic;
begin

	process(wclk)begin
		if(wclk' event and wclk='1')then
			riaddr<=conv_integer(wraddr);
			wrb<=wr;
			wdatb<=wdat;
		end if;
	end process;
	
	process(wclk)
	begin
		if(wclk' event and wclk='1')then
			if(wrb='1')then
				flag(riaddr)<=wdatb;
			end if;
		end if;
	end process;
	
	process(rclk)
	variable iaddr	:integer range 0 to bits-1;
	begin
		if(rclk' event and rclk='1')then
			iaddr:=conv_integer(rdaddr);
			rd<=flag(iaddr);
		end if;
	end process;
end rtl;
