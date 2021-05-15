LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clktx is
port(
	txin	:in std_logic;
	txout	:out std_logic;
	
	fclk	:in std_logic;
	sclk	:in std_logic;
	rstn	:in std_logic
);
end clktx;

architecture rtl of clktx is
signal	txpend	:std_logic;
signal	txdone	:std_logic;
--signal	stxpend	:std_logic;
begin
	process(fclk,rstn)begin
		if(rstn='0')then
			txpend<='0';
		elsif(fclk' event and fclk='1')then
			if(txin='1')then
				txpend<='1';
			elsif(txdone='1')then
				txpend<='0';
			end if;
		end if;
	end process;
	
	process(sclk,rstn)begin
		if(rstn='0')then
			txdone<='0';
			txout<='0';
--			stxpend<='0';
		elsif(sclk' event and sclk='1')then
			txout<='0';
--			stxpend<=txpend;
--			if(stxpend='1')then
			if(txpend='1')then
				txout<='1';
				txdone<='1';
--			elsif(stxpend='0')then
			elsif(txpend='0')then
				txdone<='0';
			end if;
		end if;
	end process;
end rtl;				
			