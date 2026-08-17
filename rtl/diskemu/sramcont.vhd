library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity sramcont is
port(
	addr	:in std_logic_vector(12 downto 0);
	rdat	:out std_logic_vector(15 downto 0);
	wdat	:in std_logic_vector(15 downto 0)	:=(others=>'0');
	wr		:in std_logic_vector(1 downto 0)	:="00";
	
	ldreq	:in std_logic;
	streq	:in std_logic;
	done	:out std_logic;

	mist_rd	:out std_logic;
	mist_wr	:out std_logic;
	mist_ack:in std_logic;
	
	mist_lba	:out std_logic_vector(31 downto 0);
	mist_addr	:in std_logic_vector(8 downto 0);
	mist_wdat	:in std_logic_vector(7 downto 0);
	mist_rdat	:out std_logic_vector(7 downto 0);
	mist_we		:in std_logic;

	ram_addr_a		:out std_logic_vector(12 downto 0);
	ram_addr_b		:out std_logic_vector(13 downto 0);
	ram_byteena_a	:out std_logic_vector(1 downto 0);
	ram_data_a		:out std_logic_vector(15 downto 0);
	ram_data_b		:out std_logic_vector(7 downto 0);
	ram_wren_a		:out std_logic;
	ram_wren_b		:out std_logic;
	ram_q_a			:in std_logic_vector(15 downto 0)	:=(others=>'0');
	ram_q_b			:in std_logic_vector(7 downto 0)	:=(others=>'0');

	clk		:in std_logic;
	ce      :in std_logic := '1';
	rstn	:in std_logic
);
end sramcont;

architecture rtl of sramcont is

type state_t is(
	st_idle,
	st_load0,
	st_load1,
	st_store0,
	st_store1
);
signal	state	:state_t;
signal	lba	:std_logic_vector(31 downto 0);
signal	byteena	:std_logic_vector(1 downto 0);
signal	wren	:std_logic;
signal	rddattmp	:std_logic_vector(15 downto 0);

begin

	byteena<=	"10" when wr="01" else
					"01" when wr="10" else
					"11" when wr="11" else
					"11";
	
	wren<='0' when wr="00" else '1';

	ram_addr_a		<=addr;
	ram_addr_b		<=lba(4 downto 0) & mist_addr(8 downto 0);
	ram_byteena_a	<=byteena;
	ram_data_a		<=wdat(7 downto 0) & wdat(15 downto 8);
	ram_data_b		<=mist_wdat;
	ram_wren_a		<=wren and ce;
	ram_wren_b		<=mist_we;
	rddattmp		<=ram_q_a;
	mist_rdat		<=ram_q_b;
	rdat<=rddattmp(7 downto 0) & rddattmp(15 downto 8);
	
	process(clk,rstn)begin
		if rising_edge(clk) then
			if(rstn='0')then
				lba<=(others=>'0');
				state<=st_idle;
				mist_rd<='0';
				mist_wr<='0';
				done<='0';
			elsif(ce = '1')then
				done<='0';
				case state is
				when st_idle =>
					if(ldreq='1')then
						lba<=(others=>'0');
						mist_rd<='1';
						state<=st_load0;
					elsif(streq='1')then
						lba<=(others=>'0');
						mist_wr<='1';
						state<=st_store0;
					end if;
				when st_load0 =>
					if(mist_ack='1')then
						mist_rd<='0';
						state<=st_load1;
					end if;
				when st_load1 =>
					if(mist_ack='0')then
						if(lba<x"0000001f")then
							lba<=lba+1;
							mist_rd<='1';
							state<=st_load0;
						else
							done<='1';
							state<=st_idle;
						end if;
					end if;
				when st_store0 =>
					if(mist_ack='1')then
						mist_wr<='0';
						state<=st_store1;
					end if;
				when st_store1 =>
					if(mist_ack='0')then
						if(lba<x"0000001f")then
							lba<=lba+1;
							mist_wr<='1';
							state<=st_store0;
						else
							done<='1';
							state<=st_idle;
						end if;
					end if;
				when others =>
					state<=st_idle;
				end case;
			end if;
		end if;
	end process;
	
	mist_lba<=lba;
					
end rtl;
