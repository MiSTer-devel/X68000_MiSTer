-----------------------------------
-- Delta-Sigma D/A signal generator  ---
-----------------------------------

library IEEE,work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity deltasigmas is
	generic(
		width	:integer	:=8
	);
	port(
		data	:in	std_logic_vector(width-1 downto 0);
		datum	:out std_logic;
		
		sft		:in std_logic;
		clk		:in std_logic;
		rstn	:in std_logic
	);
end deltasigmas;

architecture main of deltasigmas is
signal	count	:std_logic_vector(width-1 downto 0);
begin
	process(clk,rstn)
	variable tmpx,tmpy :std_logic;
	variable countzero	:std_logic_vector(width-1 downto 0);
	begin
		countzero:=(others=>'0');
		if(rstn='0')then
			count<=countzero;
		elsif(clk' event and clk='1' )then
			if(sft='1')then
				count<=count-1;
				tmpx:='0';
				L1:for bitx in 1 to width-1 loop
					tmpy:='1';
					L2:for bity in 0 to bitx-1 loop
						tmpy:=tmpy and count(bity);
					end loop;
					tmpy:=(not count(bitx)) and tmpy;
					tmpx:=tmpx or (tmpy and data(width-bitx-1)); 
				end loop;
				datum<=tmpx or ((not count(0)) and data(width-1));
			end if;
		end if;
	end process;
end main;