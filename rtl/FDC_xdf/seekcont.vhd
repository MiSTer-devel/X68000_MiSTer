LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seekcont is
generic(
	maxtrack	:integer	:=80
);
port(
	uselin	:in std_logic_vector(1 downto 0);
	inireq	:in std_logic;
	seekreq	:in std_logic;
	destin	:in integer range 0 to maxtrack;
	tdi		:in std_logic_vector(3 downto 0);
	
	iniout	:out std_logic_vector(3 downto 0);
	seekout	:out std_logic_vector(3 downto 0);
	dest0	:out integer range 0 to maxtrack;
	dest1	:out integer range 0 to maxtrack;
	dest2	:out integer range 0 to maxtrack;
	dest3	:out integer range 0 to maxtrack;
	tdo	:out std_logic_vector(3 downto 0);
	readyin	:in std_logic;
	
	sendin	:in std_logic_vector(3 downto 0);
	serrin	:in std_logic_vector(3 downto 0);
	sbusyin	:in std_logic_vector(3 downto 0);
	
	seek_end	:out std_logic_vector(3 downto 0);
	seek_err	:out std_logic_vector(3 downto 0);
	readyout	:out std_logic;
	
	seek_pend	:out std_logic_vector(3 downto 0);
	busy	:out std_logic;
	uselout	:out std_logic_vector(1 downto 0);
	
	clk		:in std_logic;
	rstn	:in	std_logic
);
end seekcont;

architecture rtl of seekcont is
signal	inipend	:std_logic_vector(3 downto 0);
signal	seekpend:std_logic_vector(3 downto 0);
signal	curunit	:integer range 0 to 4;
signal	destb0	:integer range 0 to maxtrack;
signal	destb1	:integer range 0 to maxtrack;
signal	destb2	:integer range 0 to maxtrack;
signal	destb3	:integer range 0 to maxtrack;

begin

	process(clk,rstn)
	variable tmp	:std_logic;
	variable	sel	:integer range 0 to 4;
	begin
		if(rstn='0')then
			destb0<=0;
			destb1<=0;
			destb2<=0;
			destb3<=0;
			dest0<=0;
			dest1<=0;
			dest2<=0;
			dest3<=0;
			inipend<=(others=>'0');
			seekpend<=(others=>'0');
			curunit<=4;
			readyout<='0';
			tdo<=(others=>'0');
		elsif(clk' event and clk='1')then
			iniout<=(others=>'0');
			seekout<=(others=>'0');
			seek_end<=(others=>'0');
			seek_err<=(others=>'0');
			if(inireq='1' or seekreq='1')then
				case uselin is
				when "00" =>
					inipend(0)<=inireq;
					seekpend(0)<=seekreq;
					destb0<=destin;
					tdo(0)<=tdi(0);
				when "01" =>
					inipend(1)<=inireq;
					seekpend(1)<=seekreq;
					destb1<=destin;
					tdo(1)<=tdi(1);
				when "10" =>
					inipend(2)<=inireq;
					seekpend(2)<=seekreq;
					destb2<=destin;
					tdo(2)<=tdi(2);
				when "11" =>
					inipend(3)<=inireq;
					seekpend(3)<=seekreq;
					destb3<=destin;
					tdo(3)<=tdi(3);
				end case;
			end if;
			
			if(curunit<4)then
				if(sendin(curunit)='1')then
					if(seekpend(curunit)='0' and inipend(curunit)='0')then
						seek_end(curunit)<='1';
					end if;
					curunit<=4;
					readyout<=readyin;
				elsif(serrin(curunit)='1')then
					seek_err(curunit)<='1';
					curunit<=4;
					readyout<=readyin;
--				elsif(sbusyin(curunit)='0')then
--					seek_end(curunit)<='1';
--					curunit<=4;
--					readyout<=readyin;
				end if;
			else
				sel:=4;
				for i in 3 downto 0 loop
					if(inipend(i)='1' or seekpend(i)='1')then
						sel:=i;
					end if;
				end loop;
				if(sel/=4)then
					curunit<=sel;
					iniout(sel)<=inipend(sel);
					seekout(sel)<=seekpend(sel);
					inipend(sel)<='0';
					seekpend(sel)<='0';
					case sel is
					when 0 =>
						dest0<=destb0;
					when 1 =>
						dest1<=destb1;
					when 2 =>
						dest2<=destb2;
					when 3 =>
						dest3<=destb3;
					when others =>
					end case;
				end if;
			end if;
		end if;
	end process;
	
	busy<=	'1' when inipend/="0000" else
				'1' when seekpend/="0000" else
				'0' when curunit=4 else
				'1';
				
	uselout<=	"00" when curunit=0 else
					"01" when curunit=1 else
					"10" when curunit=2 else
					"11" when curunit=3 else
					"00";
	
	seek_pend<=inipend or seekpend;
	
end rtl;

