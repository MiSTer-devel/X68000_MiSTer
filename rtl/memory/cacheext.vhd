LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cacheext is
generic(
	awidth	:integer	:=8;
	cdcfilt	:integer	:=1
);
port(
	wraddr	:in std_logic_vector(awidth-1 downto 0);
	wr		:in std_logic;
	clr		:in std_logic;
	busy	:out std_logic;

	rdaddr	:in std_logic_vector(awidth-1 downto 0);
	rd		:out std_logic;
	masken	:in std_logic;

	wclk	:in std_logic;
	ram_ce  :in std_logic := '1';
	rclk	:in std_logic;
	sys_ce  :in std_logic := '1';
	rstn	:in std_logic
);
end cacheext;

architecture rtl of cacheext is
constant len	:integer 	:=2**awidth;
signal	wrote	:std_logic_vector(len-1 downto 0);
signal	rdaddr_l	:std_logic_vector(awidth-1 downto 0);
signal	rdb1	:std_logic;
signal	mask	:std_logic;
signal	mcount	:integer range 0 to 3;
signal	srclk	:std_logic;
signal	lrclk	:std_logic;
signal	rdb	:std_logic;
begin

	process(wclk,rstn)
	variable iwaddr	:integer range 0 to len-1;
	begin
		if rising_edge(wclk) then
			if(rstn='0')then
				wrote<=(others=>'0');
			elsif(ram_ce = '1')then
				if(clr='1')then
					wrote<=(others=>'0');
				elsif(wr='1')then
					iwaddr:=conv_integer(wraddr);
					wrote(iwaddr)<='1';
				end if;
			end if;
		end if;
	end process;

	process(wclk,rstn)begin
		if rising_edge(wclk) then
			if(rstn='0')then
				mask<='1';
				mcount<=0;
				srclk<='1';
				lrclk<='1';
			elsif(ram_ce = '1')then
				srclk<=rclk;
				lrclk<=srclk;
				if(clr='1')then
					mask<='0';
					mcount<=2;
				elsif(lrclk='0' and srclk='1')then
					if(mcount>0)then
						mcount<=mcount-1;
					else
						mask<='1';
					end if;
				end if;
			end if;
		end if;
	end process;

	gen_cdc: if cdcfilt/=0 generate
		process(rclk,rstn)
		variable iraddr	:integer range 0 to len-1;
		begin
			if rising_edge(rclk) then
				if(rstn='0')then
					rdaddr_l<=(others=>'0');
					rdb1<='0';
					rdb<='0';
				elsif(sys_ce = '1')then
					iraddr:=conv_integer(rdaddr);
					rdaddr_l<=rdaddr;
					rdb1<=wrote(iraddr);
					if(rdaddr_l=rdaddr)then
						rdb<=rdb1 and wrote(iraddr);
					else
						rdb<='0';
					end if;
				end if;
			end if;
		end process;
	end generate;

	gen_seq: if cdcfilt=0 generate
		process(rclk,rstn)
		variable iraddr	:integer range 0 to len-1;
		begin
			if rising_edge(rclk) then
				if(rstn='0')then
					rdb<='0';
				elsif(sys_ce = '1')then
					iraddr:=conv_integer(rdaddr);
					rdb<=wrote(iraddr);
				end if;
			end if;
		end process;
	end generate;

	busy<='0';

	rd<=	(rdb and (not clr) and mask) when masken='1' else (rdb and (not clr));
end rtl;
