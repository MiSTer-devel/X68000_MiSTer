LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cacheext is
generic(
	awidth	:integer	:=8
);
port(
	wraddr	:in std_logic_vector(awidth-1 downto 0);
	wr		:in std_logic;
	clr		:in std_logic;
	
	rdaddr	:in std_logic_vector(awidth-1 downto 0);
	rd		:out std_logic;
	masken	:in std_logic;
	
	wclk	:in std_logic;
	rclk	:in std_logic;
	rstn	:in std_logic
);
end cacheext;

architecture rtl of cacheext is
constant bits	:integer	:=2**awidth;
signal	flag	:std_logic_vector(bits-1 downto 0);
signal	iaddr	:integer range 0 to bits-1;
signal	lrclk	:std_logic;
signal	mask	:std_logic;
signal	mcount	:integer range 0 to 2;
signal	rdm		:std_logic;
signal	riaddr	:integer range 0 to bits-1;
signal	wrb		:std_logic;
begin

	process(wclk)begin
		if(wclk' event and wclk='1')then
			riaddr<=conv_integer(wraddr);
			wrb<=wr;
		end if;
	end process;
	
	process(wclk,rstn)
	variable iaddr	:integer range 0 to bits-1;
	begin
		if(rstn='0')then
--			flag<=(others=>'0');
			lrclk<='1';
			mask<='1';
			mcount<=0;
		elsif(wclk' event and wclk='1')then
			lrclk<=rclk;
			if(lrclk='0' and rclk='1')then
				if(mcount>0)then
					mcount<=mcount-1;
				else
					mask<='1';
				end if;
			end if;
			if(clr='1')then
				flag<=(others=>'0');
				mask<='0';
				mcount<=2;
--			elsif(wr='1')then
			elsif(wrb='1')then
--				iaddr:=conv_integer(wraddr);
--				flag(iaddr)<='1';
				flag(riaddr)<='1';
			end if;
		end if;
	end process;
	
	process(wclk,rstn)
	variable iaddr	:integer range 0 to bits-1;
	begin
		if(rstn='0')then
			rdm<='0';
		elsif(wclk' event and wclk='1')then
			iaddr:=conv_integer(rdaddr);
			rdm<=flag(iaddr);
		end if;
	end process;
	rd<=rdm and mask and (not clr) when masken='1' else rdm;
end rtl;
