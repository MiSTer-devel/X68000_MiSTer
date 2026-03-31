library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity e6258 is
port(
	addr	:in std_logic;
	datin	:in std_logic_vector(7 downto 0);
	datout	:out std_logic_vector(7 downto 0);
	datwr	:in std_logic;
	drq		:out std_logic;

	clkdiv	:in std_logic_vector(1 downto 0);
	sft		:in std_logic;

	sndout	:out std_logic_vector(11 downto 0);

	sysclk	:in std_logic;
	sys_ce  :in std_logic := '1';
	sndclk		:in std_logic;
	snd_ce  :in std_logic := '1';
	rstn	:in std_logic
);
end e6258;

architecture rtl of e6258 is
component calcadpcm
port(
	playen	:in std_logic;
	datin	:in std_logic_vector(3 downto 0);
	datemp	:in std_logic;
	datwr	:in std_logic;

	datout	:out std_logic_vector(11 downto 0);

	clkdiv	:in std_logic_vector(1 downto 0);
	sft		:in std_logic;
	clk		:in std_logic;
	ce      :in std_logic := '1';
	rstn	:in std_logic
);

end component;

signal	nxtbuf0,nxtbuf1	:std_logic_vector(3 downto 0);
signal	bufcount	:integer range 0 to 2;
signal	sftcount	:integer range 0 to 3;
signal	divcount	:integer range 0 to 255;
signal	play_start	:std_logic;
signal	startup_wait	:std_logic;
signal	playen	:std_logic;
signal	recen	:std_logic;
signal	playwr	:std_logic;
signal	datuse	:std_logic;
signal	playdat	:std_logic_vector(3 downto 0);
signal	datemp	:std_logic;
signal	calcsft		:std_logic;
signal	datinbuf	:std_logic_vector(7 downto 0);
signal	addrbuf	:std_logic;
begin

	process(sysclk,rstn)
	begin
		if rising_edge(sysclk) then
			if(rstn='0')then
				datinbuf<=(others=>'0');
				addrbuf<='0';
			elsif(sys_ce = '1')then
				if(datwr='1')then
					datinbuf<=datin;
					addrbuf<=addr;
				end if;
			end if;
		end if;
	end process;

	process(sndclk,rstn)
	variable ldatwr	:std_logic_vector(1 downto 0);
	begin
		if rising_edge(sndclk) then
			if(rstn='0')then
				playen<='0';
				recen<='0';
				bufcount<=0;
				nxtbuf0<=(others=>'0');
				nxtbuf1<=(others=>'0');
				drq<='0';
				play_start<='0';
				startup_wait<='0';
				ldatwr:="00";
			elsif(snd_ce = '1')then
				play_start<='0';
				if(datwr='1')then
					drq<='0';
				end if;
				if(datuse='1')then
					nxtbuf0<=nxtbuf1;
					nxtbuf1<=(others=>'0');
					if(bufcount>0)then
						bufcount<=bufcount-1;
					end if;
					if(bufcount<=1)then
						drq<='1';
					end if;
				end if;
				if(ldatwr="10")then
					if(addrbuf='0')then
						if(datinbuf(0)='1')then
							playen<='0';
							recen<='0';
							bufcount<=0;
							nxtbuf0<=(others=>'0');
							nxtbuf1<=(others=>'0');
							drq<='0';
							startup_wait<='0';
						elsif(datinbuf(1)='1')then
							if(playen='0')then
								playen<='1';
								bufcount<=0;
								nxtbuf0<=(others=>'0');
								nxtbuf1<=(others=>'0');
								drq<='1';
								play_start<='1';
								startup_wait<='1';
							end if;
						elsif(datinbuf(2)='1')then
							recen<='1';
						end if;
					else
						drq<='0';
						nxtbuf1<=datinbuf(7 downto 4);
						nxtbuf0<=datinbuf(3 downto 0);
						bufcount<=2;
						startup_wait<='0';
					end if;
				end if;
				ldatwr:=ldatwr(0) & datwr;
			end if;
		end if;
	end process;

	process(sndclk,rstn)begin
		if rising_edge(sndclk) then
			if(rstn='0')then
				playdat<=(others=>'0');
				playwr<='0';
				divcount<=0;
				datuse<='0';
				calcsft<='0';
				sftcount<=0;
				datemp<='1';
			elsif(snd_ce = '1')then
				playwr<='0';
				datuse<='0';
				calcsft<='0';
				if(play_start='1')then
					divcount<=0;
					sftcount<=0;
				elsif(playen='1' and sft='1' and startup_wait='0')then
					if(sftcount>0)then
						sftcount<=sftcount-1;
					else
						sftcount<=3;
						calcsft<='1';
						if(divcount=0)then
							playdat<=nxtbuf0;
							if(bufcount>0)then
								datemp<='0';
							else
								datemp<='1';
							end if;
							playwr<='1';
							datuse<='1';
							case clkdiv is
							when "00" =>
								divcount<=255;
							when "01" =>
								divcount<=191;
							when "10" =>
								divcount<=127;
							when others =>
								divcount<=127;
							end case;
						else
							divcount<=divcount-1;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	adpcm	:calcadpcm port map(
		playen	=>playen,
		datin	=>playdat,
		datemp	=>datemp,
		datwr	=>playwr,

		datout	=>sndout,

		clkdiv	=>clkdiv,
		sft		=>calcsft,
		clk		=>sndclk,
		ce      =>snd_ce,
		rstn	=>rstn
	);

	datout<=	((not playen) or recen) & '0' & "000000" when addr='0' else
				(others=>'0');
	end rtl;
