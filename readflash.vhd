LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity readflash is
generic(
	offset	:std_logic_vector(20 downto 0)	:="110000000000000000000";	--0x180000
	awidth	:integer	:=19
);
port(
	-- Flash ports
	pFlshAdr	:out std_logic_vector(21 downto 0);
	pFlshDQ		:in std_logic_vector(15 downto 0);
	pFlshByte_n	:out std_logic;
	pFlshCe_n	:out std_logic;
	pFlshOe_n	:out std_logic;
	pFlshRst_n	:out std_logic;
	pFlshRy		:in std_logic;
	pFlshWe_n	:out std_logic;
	pFlshWp_n	:out std_logic;
	
	addr		:in std_logic_vector(awidth-1 downto 0);
	ce			:in std_logic;
	rdat		:out std_logic_vector(15 downto 0);
	datoe		:out std_logic;
	ack			:out std_logic;
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end readflash;

architecture rtl of readflash is
signal	realaddr	:std_logic_vector(20 downto 0);
signal	addaddr		:std_logic_vector(20 downto 0);
begin
	addaddr(20 downto awidth)<=(others=>'0');
	addaddr(awidth-1 downto 0)<=addr;
	realaddr<=offset+addaddr;
	pFlshAdr<='0' & realaddr;
	pFlshByte_n<='1';
	pFlshCe_n<='0';
	pFlshOe_n<=not ce;
	pFlshRst_n<=rstn;
	pFlshWe_n<='1';
	pFlshWp_n<='0';
	
	rdat<=pFlshDQ(7 downto 0) & pFlshDQ(15 downto 8);
	process(clk,rstn)begin
		if(rstn='0')then
			ack<='0';
		elsif(clk' event and clk='1')then
			if(ce='1' and pFlshRy='1')then
				ack<='1';
			else
				ack<='0';
			end if;
		end if;
	end process;
	
	datoe<=ce;
end rtl;
