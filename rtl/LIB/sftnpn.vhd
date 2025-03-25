LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sftnpn is
generic(
	denom	:integer	:=5
);
port(
	numer	:in std_logic_vector(denom-1 downto 0);
	sftin	:in std_logic;
	sftout	:out std_logic;
	
	clk		:in std_logic;
	ce      :in std_logic := '1';
	rstn	:in std_logic
);
end sftnpn;

architecture rtl of sftnpn is
signal	sftdat	:std_logic_vector(denom-1 downto 0);
begin

	process(clk,rstn)
	variable tmp	:std_logic_vector(denom-1 downto 0);
	begin
		if rising_edge(clk) then
		if(rstn='0')then
			sftdat<=numer;
		elsif(ce = '1')then
			if(sftin='1')then
				sftout<=sftdat(0);
				sftdat<=sftdat(0) & sftdat(denom-1 downto 1);
			else
				sftout<='0';
			end if;
		end if;
		end if;
	end process;
end rtl;
