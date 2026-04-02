library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity calcadpcm is
port(
	playen	: in  std_logic;
	datin	: in  std_logic_vector(3 downto 0);
	datemp	: in  std_logic;
	datwr	: in  std_logic;
	
	datout	: out std_logic_vector(11 downto 0);

	clkdiv	: in  std_logic_vector(1 downto 0);
	sft		: in  std_logic;
	clk		: in  std_logic;
	ce		: in  std_logic := '1';
	rstn	: in  std_logic
);
end calcadpcm;

architecture rtl of calcadpcm is

	type step_table_t is array (0 to 48) of integer range 0 to 1552;
	constant STEP_TABLE : step_table_t := (
		  16,   17,   19,   21,   23,   25,   28,   31,   34,   37,
		  41,   45,   50,   55,   60,   66,   73,   80,   88,   97,
		 107,  118,  130,  143,  157,  173,  190,  209,  230,  253,
		 279,  307,  337,  371,  408,  449,  494,  544,  598,  658,
		 724,  796,  876,  963, 1060, 1166, 1282, 1411, 1552
	);

	type index_shift_t is array (0 to 7) of integer range -1 to 8;
	constant INDEX_SHIFT : index_shift_t := (-1, -1, -1, -1, 2, 4, 6, 8);

	signal signal_acc : signed(12 downto 0);
	signal step_idx   : integer range 0 to 48;
	signal lplayen    : std_logic;
	signal decay_div  : unsigned(8 downto 0);

begin

	process(clk)
		variable stepval    : integer range 0 to 1552;
		variable delta      : integer range 0 to 2910;
		variable new_signal : integer;
		variable new_step   : integer;
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				signal_acc <= to_signed(0, 13);
				step_idx   <= 0;
				lplayen    <= '0';
				decay_div  <= (others => '0');
			elsif ce = '1' then
				lplayen <= playen;

				if playen = '1' and lplayen = '0' then
					-- Play just started: init ADPCM decoder per MAME
					signal_acc <= to_signed(-2, 13);
					step_idx   <= 0;
					decay_div  <= (others => '0');

				elsif playen = '0' then
					-- Not playing: slow linear ramp to zero to prevent pop
					-- At 40MHz, counter 399 = 10μs per step
					-- Max signal 2047 → ~20ms ramp (completely inaudible)
					step_idx <= 0;
					if signal_acc > 0 then
						if decay_div = 0 then
							decay_div <= to_unsigned(399, 9);
							signal_acc <= signal_acc - 1;
						else
							decay_div <= decay_div - 1;
						end if;
					elsif signal_acc < 0 then
						if decay_div = 0 then
							decay_div <= to_unsigned(399, 9);
							signal_acc <= signal_acc + 1;
						else
							decay_div <= decay_div - 1;
						end if;
					end if;

				elsif datwr = '1' and datemp = '1' then
					-- Buffer empty: ramp signal toward zero at sample rate
					-- This ensures signal is near 0 before STOP arrives (same as official core)
					step_idx <= 0;
					if signal_acc > 0 then
						signal_acc <= signal_acc - 1;
					elsif signal_acc < 0 then
						signal_acc <= signal_acc + 1;
					end if;

				elsif datwr = '1' and datemp = '0' then
						decay_div  <= (others => '0');
						stepval := STEP_TABLE(step_idx);
						
						-- OKI ADPCM delta: per-bit truncated shifts (matches MAME/real hardware)
						delta := stepval / 8;
						if datin(0) = '1' then delta := delta + stepval / 4; end if;
						if datin(1) = '1' then delta := delta + stepval / 2; end if;
						if datin(2) = '1' then delta := delta + stepval;     end if;
						
						if datin(3) = '1' then
							new_signal := to_integer(signal_acc) - delta;
						else
							new_signal := to_integer(signal_acc) + delta;
						end if;
						
						if new_signal > 2047 then
							new_signal := 2047;
						elsif new_signal < -2048 then
							new_signal := -2048;
						end if;
						
						signal_acc <= to_signed(new_signal, 13);
						
						new_step := step_idx + INDEX_SHIFT(to_integer(unsigned(datin(2 downto 0))));
						if new_step < 0 then
							step_idx <= 0;
						elsif new_step > 48 then
							step_idx <= 48;
						else
							step_idx <= new_step;
					end if;
				end if;
			end if;
		end if;
	end process;

	datout <= std_logic_vector(signal_acc(11 downto 0));

end rtl;
