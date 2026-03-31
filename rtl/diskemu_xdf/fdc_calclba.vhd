LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;

entity fdc_calclba is
generic(
	wtrack	:integer	:=7;
	wsect	:integer	:=5;
	wssize	:integer	:=10
);
port(
	tracks	:in std_logic_vector(wtrack-1 downto 0);
	sectsize:in std_logic_vector(1 downto 0);	--00:128 01:256 10:512 11:1024
	sects	:in std_logic_vector(wsect-1 downto 0);
	
	track	:in std_logic_vector(wtrack-1 downto 0);
	head	:in std_logic;
	sect	:in std_logic_vector(wsect-1 downto 0);
	spos	:in std_logic_vector(wssize-1 downto 0);
	
	lba		:out std_logic_vector(31 downto 0);
	lbapos	:out std_logic_vector(8 downto 0)
);
end fdc_calclba;

architecture rtl of fdc_calclba is
signal	addr	:std_logic_vector(12+wtrack+wsect downto 0);
signal	vsectsize	:std_logic_vector(10 downto 0);
signal	sectaddr	:std_logic_vector(10+wsect downto 0);
signal	vhead		:std_logic_vector(0 downto 0);
signal	headaddr	:std_logic_vector(11+wsect downto 0);
signal	trackaddr	:std_logic_vector(12+wtrack+wsect downto 0);
begin
	vsectsize<=	"00010000000" when sectsize="00" else
				"00100000000" when sectsize="01" else
				"01000000000" when sectsize="10" else
				"10000000000";
	vhead(0)<=head;
	sectaddr<=sect*vsectsize;
	headaddr<=vhead*sects*vsectsize;
	trackaddr<=track*"10"*sects*vsectsize;
	addr<=spos+sectaddr+headaddr+trackaddr;
	lba(11 downto 0)<=addr(20 downto 9);
	lbapos<=addr(8 downto 0);
end rtl;

	