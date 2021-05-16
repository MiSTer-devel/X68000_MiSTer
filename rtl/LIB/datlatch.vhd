LIBRARY	IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;

entity datlatch is
generic(
	datwidth	:integer	:=8
);
port(
	datin		:in std_logic_vector(datwidth-1 downto 0);
	wr			:in std_logic;
	datout	:out std_logic_vector(datwidth-1 downto 0);
	
	clk		:in std_logic;
	rstn		:in std_logic
);
end datlatch;

architecture rtl of datlatch is
begin
	process(clk,rstn)begin
		if(rstn='0')then
			datout<=(others=>'0');
		elsif(clk' event and clk='1')then
			if(wr='1')then
				datout<=datin;
			end if;
		end if;
	end process;
end rtl;
