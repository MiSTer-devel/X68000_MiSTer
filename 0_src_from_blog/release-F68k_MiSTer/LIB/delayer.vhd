library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity delayer is
generic(
	counts	:integer	:=5
);
port(
	a		:in std_logic;
	q		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end delayer;
architecture MAIN of delayer is
signal	fifo	:std_logic_vector(counts-1 downto 0);
begin
	process(clk,rstn)begin
		if(rstn='0')then
			fifo<=(others=>'0');
			q<='0';
		elsif(clk' event and clk='1')then
			q<=fifo(0);
			fifo<=a & fifo(counts-1 downto 1);
		end if;
	end process;
end MAIN;
