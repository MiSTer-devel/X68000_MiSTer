LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity FMreg is
generic(
	DWIDTH	:integer	:=16
);
port(
	CH		:std_logic_vector(1 downto 0);
	SL		:std_logic_vector(1 downto 0);
	RDAT	:out std_logic_vector(DWIDTH-1 downto 0);
	WDAT	:in std_logic_vector(DWIDTH-1 downto 0);
	WR		:in std_logic;

	clk		:in std_logic
);
end FMreg;

architecture rtl of FMreg is
component ram16x32
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;
signal	addr	:std_logic_vector(4 downto 0);
signal	WDATsub,RDATsub	:std_logic_vector(15 downto 0);
constant ALLZERO	:std_logic_vector(15 downto 0)	:=(others=>'0');
begin
	ADDR<='0' & CH & SL;
	WDATsub<=ALLZERO(15 downto DWIDTH) & WDAT;
	ram	:ram16x32 port map(addr,clk,WDATsub,WR,RDATsub);
	RDAT<=RDATsub(DWIDTH-1 downto 0);
end rtl;
