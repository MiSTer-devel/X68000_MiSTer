library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity rastercopy is
generic(
	arange	:integer	:=14
);
port(
	src		:in std_logic_vector(7 downto 0);
	dst		:in std_logic_vector(7 downto 0);
	prane	:in std_logic_vector(3 downto 0);
	start	:in std_logic;
	stop	:in std_logic;
	busy	:out std_logic;

	t_base	:in std_logic_vector(arange-1 downto 0);	
	srcaddr	:out std_logic_vector(arange-1 downto 0);
	dstaddr	:out std_logic_vector(arange-1 downto 0);
	cpy		:out std_logic_vector(3 downto 0);
	ack		:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end rastercopy;
architecture rtl of rastercopy is
type state_t is (
	st_IDLE,
	st_RAS0,
	st_RAS1,
	st_RAS2,
	st_RAS3
);
signal	STATE	:state_t;
signal	eack	:std_logic;
signal	lack	:std_logic;
begin
	srcaddr(arange-1 downto 10)<=t_base(arange-1 downto 10);
	srcaddr(1 downto 0)<=
		"00" when STATE=st_RAS0 else
		"01" when STATE=st_RAS1 else
		"10" when STATE=st_RAS2 else
		"11" when STATE=st_RAS3 else
		"00";
		
	dstaddr(arange-1 downto 10)<=t_base(arange-1 downto 10);
	dstaddr(1 downto 0)<=
		"00" when STATE=st_RAS0 else
		"01" when STATE=st_RAS1 else
		"10" when STATE=st_RAS2 else
		"11" when STATE=st_RAS3 else
		"00";

	process(clk,rstn)begin
		if(rstn='0')then
			lack<='0';
			eack<='0';
		elsif(clk' event and clk='1')then
			if(lack='0' and ack='1')then
				eack<='1';
			else
				eack<='0';
			end if;
			lack<=ack;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			cpy<=(others=>'0');
			srcaddr(9 downto 2)<=(others=>'0');
			dstaddr(9 downto 2)<=(others=>'0');
		elsif(clk' event and clk='1')then
			case STATE is
			when st_IDLE=>
				if(start='1')then
					srcaddr(9 downto 2)<=src;
					dstaddr(9 downto 2)<=dst;
					cpy<=prane;
					STATE<=st_RAS0;
				end if;
			when st_RAS0 =>
				if(eack='1')then
					STATE<=st_RAS1;
				end if;
			when st_RAS1 =>
				if(eack='1')then
					STATE<=st_RAS2;
				end if;
			when st_RAS2 =>
				if(eack='1')then
					STATE<=st_RAS3;
				end if;
			when st_RAS3 =>
				if(eack='1')then
					cpy<=(others=>'0');
					STATE<=st_IDLE;
				end if;
			when others =>
			end case;
			if(stop='1')then
				cpy<=(others=>'0');
				STATE<=st_IDLE;
			end if;
		end if;
	end process;
	
	busy<='0' when STATE=st_IDLE else '1';
end rtl;

			
