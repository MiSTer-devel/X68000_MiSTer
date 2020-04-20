LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity delayon is
generic(
	delay	:integer	:=100
);
port(
	delayin	:in std_logic;
	delayout:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end delayon;

architecture rtl of delayon is
signal	count	:integer range 0 to delay;
begin
	process(clk,rstn)begin
		if(rstn='0')then
			delayout<='0';
			count<=delay;
		elsif(clk' event and clk='1')then
			if(delayin='0')then
				delayout<='0';
				count<=delay;
			elsif(count>0)then
				count<=count-1;
				delayout<='0';
			else
				delayout<='1';
			end if;
		end if;
	end process;
end rtl;