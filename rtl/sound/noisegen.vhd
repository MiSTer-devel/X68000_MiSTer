LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
	use ieee.std_logic_arith.all;

entity noisegen is
port(
	sft		:in std_logic;
	noise	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end noisegen;

architecture rtl of noisegen is
signal sreg	:std_logic_vector(16 downto 0);
begin
	process(clk,rstn)begin
		if(rstn='0')then
			sreg<="00000000000000001";
		elsif(clk' event and clk='1')then
			if(sft='1')then
				sreg<=(sreg(0) xor sreg(3))&sreg(16 downto 1);
			end if;
		end if;
	end process;
	
	noise<=sreg(0);
end rtl;
