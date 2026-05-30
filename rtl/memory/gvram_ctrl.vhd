-- gvram_ctrl: BRAM-backed GVRAM controller for chips 0 and 1
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity gvram_ctrl is
generic(
	awidth	: integer := 24
);
port(
	-- Video read ports: chip 0 and chip 1 channels
	g00_addr : in  std_logic_vector(awidth-1 downto 0);
	g00_rd   : in  std_logic;
	g00_rdat : out std_logic_vector(15 downto 0);
	g00_ack  : out std_logic;

	g01_addr : in  std_logic_vector(awidth-1 downto 0);
	g01_rd   : in  std_logic;
	g01_rdat : out std_logic_vector(15 downto 0);
	g01_ack  : out std_logic;

	g10_addr : in  std_logic_vector(awidth-1 downto 0);
	g10_rd   : in  std_logic;
	g10_rdat : out std_logic_vector(15 downto 0);
	g10_ack  : out std_logic;

	g11_addr : in  std_logic_vector(awidth-1 downto 0);
	g11_rd   : in  std_logic;
	g11_rdat : out std_logic_vector(15 downto 0);
	g11_ack  : out std_logic;

	-- GVRAM clear ports for chips 0 and 1
	g0_caddr : in  std_logic_vector(awidth-1 downto 8);
	g0_clear : in  std_logic;
	g1_caddr : in  std_logic_vector(awidth-1 downto 8);
	g1_clear : in  std_logic;

	-- CPU write/read port (packed-format address from X68mmapCV)
	cpu_addr    : in  std_logic_vector(17 downto 0);
	cpu_wdat    : in  std_logic_vector(15 downto 0);
	cpu_rdat    : out std_logic_vector(15 downto 0);
	cpu_wr      : in  std_logic;
	cpu_rd      : in  std_logic;
	cpu_rmw     : in  std_logic_vector(1 downto 0);
	cpu_rmwmask : in  std_logic_vector(15 downto 0);
	cpu_ack     : out std_logic;

	-- Graphics mode (from vcreg: GR_CMODE)
	gmode    : in  std_logic_vector(1 downto 0);

	-- Clocks and reset
	rclk     : in  std_logic;
	ram_ce   : in  std_logic := '1';
	vclk     : in  std_logic;
	vid_ce   : in  std_logic := '1';
	sclk     : in  std_logic;
	sys_ce   : in  std_logic := '1';
	rstn     : in  std_logic
);
end gvram_ctrl;

architecture rtl of gvram_ctrl is

component gvram_bram
port(
	c0_address_a : in  std_logic_vector(15 downto 0);
	c0_data_a    : in  std_logic_vector(15 downto 0);
	c0_wren_a    : in  std_logic;
	c0_q_a       : out std_logic_vector(15 downto 0);
	c0_address_b : in  std_logic_vector(15 downto 0);
	c0_q_b       : out std_logic_vector(15 downto 0);
	c1_address_a : in  std_logic_vector(15 downto 0);
	c1_data_a    : in  std_logic_vector(15 downto 0);
	c1_wren_a    : in  std_logic;
	c1_q_a       : out std_logic_vector(15 downto 0);
	c1_address_b : in  std_logic_vector(15 downto 0);
	c1_q_b       : out std_logic_vector(15 downto 0);
	clock_a      : in  std_logic;
	clock_b      : in  std_logic
);
end component;

component vrcack
generic(
	awidth : integer := 22;
	cwidth : integer := 8
);
port(
	rd     : in  std_logic;
	rdaddr : in  std_logic_vector(awidth-1 downto 0);
	raddrh : in  std_logic_vector(awidth-cwidth-1 downto 0);
	rcaddr : in  std_logic_vector(cwidth-1 downto 0);
	de     : in  std_logic;
	ack    : out std_logic;
	clk    : in  std_logic;
	ce     : in  std_logic := '1';
	rstn   : in  std_logic
);
end component;

component CACHEMEMWN
generic(
	awidth : integer := 8
);
port(
	data      : in  std_logic_vector(15 downto 0);
	rdaddress : in  std_logic_vector(awidth-1 downto 0);
	rdclock   : in  std_logic;
	wraddress : in  std_logic_vector(awidth-1 downto 0);
	wrclock   : in  std_logic := '1';
	wren      : in  std_logic := '0';
	q         : out std_logic_vector(15 downto 0)
);
end component;

signal cpu_chip_addr : std_logic_vector(15 downto 0);

signal cpu_chip0_sel : std_logic;
signal cpu_chip1_sel : std_logic;

signal c0_addr_a  : std_logic_vector(15 downto 0);
signal c0_data_a  : std_logic_vector(15 downto 0);
signal c0_wren_a  : std_logic;
signal c0_q_a     : std_logic_vector(15 downto 0);
signal c0_addr_b  : std_logic_vector(15 downto 0);
signal c0_q_b     : std_logic_vector(15 downto 0);

signal c1_addr_a  : std_logic_vector(15 downto 0);
signal c1_data_a  : std_logic_vector(15 downto 0);
signal c1_wren_a  : std_logic;
signal c1_q_a     : std_logic_vector(15 downto 0);
signal c1_addr_b  : std_logic_vector(15 downto 0);
signal c1_q_b     : std_logic_vector(15 downto 0);

type fill_state_t is (FS_IDLE, FS_FILL, FS_LAST, FS_DONE);
signal fill_state : fill_state_t;

type fill_tgt_t is (FT_G00, FT_G01, FT_G10, FT_G11, FT_NONE);
signal fill_tgt : fill_tgt_t;

signal fill_row     : std_logic_vector(8 downto 0);
signal fill_cnt     : std_logic_vector(8 downto 0);   -- 0-511 = full page
signal fill_de      : std_logic;
signal fill_chip    : std_logic;  -- '0'=chip0, '1'=chip1

signal cache_wraddr_d : std_logic_vector(8 downto 0);


constant TAG_WIDTH : integer := awidth - 9;

signal g00addrh : std_logic_vector(TAG_WIDTH-1 downto 0);
signal g01addrh : std_logic_vector(TAG_WIDTH-1 downto 0);
signal g10addrh : std_logic_vector(TAG_WIDTH-1 downto 0);
signal g11addrh : std_logic_vector(TAG_WIDTH-1 downto 0);

signal g0caddrh : std_logic_vector(awidth-9 downto 0);
signal g1caddrh : std_logic_vector(awidth-9 downto 0);

signal clr_page   : std_logic_vector(8 downto 0);
signal clr_cnt    : std_logic_vector(6 downto 0);
signal clr_active : std_logic;
signal clr_chip   : std_logic;

signal cache_wrdat  : std_logic_vector(15 downto 0);
signal cache_wraddr : std_logic_vector(8 downto 0);
signal g00rwr, g01rwr : std_logic;
signal g10rwr, g11rwr : std_logic;
signal cache_wren_d : std_logic;

signal g00_cache_wrdat : std_logic_vector(15 downto 0);
signal g01_cache_wrdat : std_logic_vector(15 downto 0);
signal g10_cache_wrdat : std_logic_vector(15 downto 0);
signal g11_cache_wrdat : std_logic_vector(15 downto 0);

signal bfill_g00, bfill_g01 : std_logic;
signal bfill_g10, bfill_g11 : std_logic;

signal c0_nibble    : std_logic_vector(3 downto 0);
signal c1_nibble    : std_logic_vector(3 downto 0);
signal cpu_c0_nibble : std_logic_vector(3 downto 0);
signal cpu_c1_nibble : std_logic_vector(3 downto 0);

signal clr_active_r1   : std_logic;
signal clr_start_pulse : std_logic;


type rmw_state_t is (RMW_IDLE, RMW_ADDR, RMW_READ, RMW_WRITE);
signal rmw_state  : rmw_state_t;
signal rmw_rdat0  : std_logic_vector(15 downto 0);
signal rmw_rdat1  : std_logic_vector(15 downto 0);
signal rmw_merged0 : std_logic_vector(15 downto 0);
signal rmw_merged1 : std_logic_vector(15 downto 0);
signal cpu_ack_i  : std_logic;

signal rmw_chipmask : std_logic_vector(15 downto 0);

signal cpu_wdat0 : std_logic_vector(15 downto 0);
signal cpu_wdat1 : std_logic_vector(15 downto 0);

signal int_rmw : std_logic;

signal rmw_addr_r      : std_logic_vector(15 downto 0);
signal rmw_wdat0_r     : std_logic_vector(15 downto 0);
signal rmw_wdat1_r     : std_logic_vector(15 downto 0);
signal rmw_mask_r      : std_logic_vector(15 downto 0);
signal rmw_c0sel_r     : std_logic;
signal rmw_c1sel_r     : std_logic;

signal rst_clr_active : std_logic;
signal rst_clr_addr   : std_logic_vector(15 downto 0);

signal cpu_inv_tog_s   : std_logic;
signal cpu_inv_row_s   : std_logic_vector(8 downto 0);
signal int_rmw_prev_s  : std_logic;
signal cpu_inv_tog_r1  : std_logic;
signal cpu_inv_tog_r2  : std_logic;
signal cpu_inv_tog_r3  : std_logic;
signal cpu_inv_row_r   : std_logic_vector(8 downto 0);
signal cpu_inv_pulse_r : std_logic;

begin

	cpu_chip_addr <= cpu_addr(17 downto 2);

	cpu_chip0_sel <= '1' when gmode = "00" and cpu_rmwmask(3 downto 0) /= x"0" else
	                 '1' when gmode = "01" else
	                 '1' when gmode(1) = '1' else
	                 '0';
	cpu_chip1_sel <= '1' when gmode = "00" and cpu_rmwmask(7 downto 4) /= x"0" else
	                 '1' when gmode = "01" else
	                 '1' when gmode(1) = '1' else
	                 '0';

	process(cpu_addr)
	begin
		case cpu_addr(1 downto 0) is
			when "00"   => rmw_chipmask <= x"000f";
			when "01"   => rmw_chipmask <= x"00f0";
			when "10"   => rmw_chipmask <= x"0f00";
			when "11"   => rmw_chipmask <= x"f000";
			when others => rmw_chipmask <= x"000f";
		end case;
	end process;

	cpu_wdat0 <= cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0);
	cpu_wdat1 <= cpu_wdat(7 downto 4) & cpu_wdat(7 downto 4) & cpu_wdat(7 downto 4) & cpu_wdat(7 downto 4)
	             when gmode = "01" or gmode(1) = '1' else
	             cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0) & cpu_wdat(3 downto 0);

	int_rmw <= '1' when cpu_wr = '1' or cpu_rmw /= "00" else
	           '0';

	process(sclk, rstn) begin
		if rstn = '0' then
			cpu_inv_tog_s  <= '0';
			cpu_inv_row_s  <= (others => '0');
			int_rmw_prev_s <= '0';
		elsif rising_edge(sclk) then
			if sys_ce = '1' then
				int_rmw_prev_s <= int_rmw;
				if int_rmw = '1' and int_rmw_prev_s = '0' then
					cpu_inv_tog_s <= not cpu_inv_tog_s;
					cpu_inv_row_s <= cpu_addr(17 downto 9);
				end if;
			end if;
		end if;
	end process;

	process(rclk, rstn) begin
		if rstn = '0' then
			cpu_inv_tog_r1  <= '0';
			cpu_inv_tog_r2  <= '0';
			cpu_inv_tog_r3  <= '0';
			cpu_inv_row_r   <= (others => '0');
			cpu_inv_pulse_r <= '0';
		elsif rising_edge(rclk) then
			if ram_ce = '1' then
				cpu_inv_tog_r1 <= cpu_inv_tog_s;
				cpu_inv_tog_r2 <= cpu_inv_tog_r1;
				cpu_inv_tog_r3 <= cpu_inv_tog_r2;
				cpu_inv_pulse_r <= cpu_inv_tog_r2 xor cpu_inv_tog_r3;
				if (cpu_inv_tog_r2 xor cpu_inv_tog_r3) = '1' then
					cpu_inv_row_r <= cpu_inv_row_s;
				end if;
			end if;
		end if;
	end process;

	GVRAM: gvram_bram port map(
		c0_address_a => c0_addr_a,
		c0_data_a    => c0_data_a,
		c0_wren_a    => c0_wren_a,
		c0_q_a       => c0_q_a,
		c0_address_b => c0_addr_b,
		c0_q_b       => c0_q_b,
		c1_address_a => c1_addr_a,
		c1_data_a    => c1_data_a,
		c1_wren_a    => c1_wren_a,
		c1_q_a       => c1_q_a,
		c1_address_b => c1_addr_b,
		c1_q_b       => c1_q_b,
		clock_a      => sclk,
		clock_b      => rclk
	);

	cpu_c0_nibble <= c0_q_a( 3 downto  0) when cpu_addr(1 downto 0) = "00" else
	                 c0_q_a( 7 downto  4) when cpu_addr(1 downto 0) = "01" else
	                 c0_q_a(11 downto  8) when cpu_addr(1 downto 0) = "10" else
	                 c0_q_a(15 downto 12);
	cpu_c1_nibble <= c1_q_a( 3 downto  0) when cpu_addr(1 downto 0) = "00" else
	                 c1_q_a( 7 downto  4) when cpu_addr(1 downto 0) = "01" else
	                 c1_q_a(11 downto  8) when cpu_addr(1 downto 0) = "10" else
	                 c1_q_a(15 downto 12);
	cpu_rdat <= x"00" & cpu_c1_nibble & cpu_c0_nibble;

	c0_addr_b <= fill_row & fill_cnt(8 downto 2)
	             when (fill_state = FS_FILL or fill_state = FS_LAST)
	             else cpu_chip_addr;
	c1_addr_b <= fill_row & fill_cnt(8 downto 2)
	             when (fill_state = FS_FILL or fill_state = FS_LAST)
	             else cpu_chip_addr;

	rmw_merged0 <= (rmw_rdat0 and (not rmw_mask_r)) or (rmw_wdat0_r and rmw_mask_r);
	rmw_merged1 <= (rmw_rdat1 and (not rmw_mask_r)) or (rmw_wdat1_r and rmw_mask_r);

	process(sclk, rstn) begin
		if rstn = '0' then
			rst_clr_active <= '1';
			rst_clr_addr   <= (others => '0');
		elsif rising_edge(sclk) then
			if sys_ce = '1' then
				if rst_clr_active = '1' then
					if rst_clr_addr = x"FFFF" then
						rst_clr_active <= '0';
					else
						rst_clr_addr <= rst_clr_addr + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	process(rst_clr_active, rst_clr_addr,
	        clr_active, clr_chip, clr_page, clr_cnt,
	        cpu_chip_addr, cpu_wdat0, cpu_wr, cpu_chip0_sel,
	        rmw_state, rmw_merged0, rmw_addr_r, rmw_c0sel_r, int_rmw)
	begin
		if rst_clr_active = '1' then
			c0_addr_a <= rst_clr_addr;
			c0_data_a <= (others => '0');
			c0_wren_a <= '1';
		elsif clr_active = '1' and clr_chip = '0' then
			c0_addr_a <= clr_page & clr_cnt;  -- row(8:0) & word_col(6:0) = 16 bits
			c0_data_a <= (others => '0');
			c0_wren_a <= '1';
		elsif rmw_state = RMW_ADDR or rmw_state = RMW_READ then
			c0_addr_a <= rmw_addr_r;
			c0_data_a <= (others => '0');
			c0_wren_a <= '0';
		elsif rmw_state = RMW_WRITE then
			c0_addr_a <= rmw_addr_r;
			c0_data_a <= rmw_merged0;
			c0_wren_a <= rmw_c0sel_r;
		else
			c0_addr_a <= cpu_chip_addr;
			c0_data_a <= cpu_wdat0;
			c0_wren_a <= cpu_wr and cpu_chip0_sel and (not int_rmw);
		end if;
	end process;

	process(rst_clr_active, rst_clr_addr,
	        clr_active, clr_chip, clr_page, clr_cnt,
	        cpu_chip_addr, cpu_wdat1, cpu_wr, cpu_chip1_sel,
	        rmw_state, rmw_merged1, rmw_addr_r, rmw_c1sel_r, int_rmw)
	begin
		if rst_clr_active = '1' then
			c1_addr_a <= rst_clr_addr;
			c1_data_a <= (others => '0');
			c1_wren_a <= '1';
		elsif clr_active = '1' and clr_chip = '1' then
			c1_addr_a <= clr_page & clr_cnt;
			c1_data_a <= (others => '0');
			c1_wren_a <= '1';
		elsif rmw_state = RMW_ADDR or rmw_state = RMW_READ then
			c1_addr_a <= rmw_addr_r;
			c1_data_a <= (others => '0');
			c1_wren_a <= '0';
		elsif rmw_state = RMW_WRITE then
			c1_addr_a <= rmw_addr_r;
			c1_data_a <= rmw_merged1;
			c1_wren_a <= rmw_c1sel_r;
		else
			c1_addr_a <= cpu_chip_addr;
			c1_data_a <= cpu_wdat1;
			c1_wren_a <= cpu_wr and cpu_chip1_sel and (not int_rmw);
		end if;
	end process;

	process(sclk, rstn) begin
		if rstn = '0' then
			rmw_state <= RMW_IDLE;
			rmw_rdat0 <= (others => '0');
			rmw_rdat1 <= (others => '0');
		elsif rising_edge(sclk) then
			case rmw_state is
			when RMW_IDLE =>
				if sys_ce = '1' and clr_active = '0' and rst_clr_active = '0' and (cpu_rmw /= "00" or int_rmw = '1') then
					rmw_state   <= RMW_ADDR;
					rmw_addr_r  <= cpu_chip_addr;
					rmw_wdat0_r <= cpu_wdat0;
					rmw_wdat1_r <= cpu_wdat1;
					rmw_mask_r  <= rmw_chipmask;
					rmw_c0sel_r <= cpu_chip0_sel;
					rmw_c1sel_r <= cpu_chip1_sel;
				end if;
			when RMW_ADDR =>
				rmw_state <= RMW_READ;
			when RMW_READ =>
				rmw_rdat0 <= c0_q_a;
				rmw_rdat1 <= c1_q_a;
				rmw_state <= RMW_WRITE;
			when RMW_WRITE =>
				if sys_ce = '1' then
					rmw_state <= RMW_IDLE;
				end if;
			when others =>
				rmw_state <= RMW_IDLE;
			end case;
		end if;
	end process;


	cpu_ack_i <= '0' when rst_clr_active = '1' else
	             '1' when rmw_state = RMW_WRITE else
	             cpu_wr when cpu_rmw = "00" and int_rmw = '0' and clr_active = '0' else
	             cpu_rd when clr_active = '0' and fill_state = FS_IDLE else
	             '0';

	process(sclk, rstn) begin
		if rstn = '0' then
			cpu_ack <= '0';
		elsif rising_edge(sclk) then
			if sys_ce = '1' then
				cpu_ack <= cpu_ack_i;
			end if;
		end if;
	end process;

	c0_nibble <= c0_q_b( 3 downto  0) when cache_wraddr(1 downto 0) = "00" else
	             c0_q_b( 7 downto  4) when cache_wraddr(1 downto 0) = "01" else
	             c0_q_b(11 downto  8) when cache_wraddr(1 downto 0) = "10" else
	             c0_q_b(15 downto 12);
	c1_nibble <= c1_q_b( 3 downto  0) when cache_wraddr(1 downto 0) = "00" else
	             c1_q_b( 7 downto  4) when cache_wraddr(1 downto 0) = "01" else
	             c1_q_b(11 downto  8) when cache_wraddr(1 downto 0) = "10" else
	             c1_q_b(15 downto 12);

	cache_wrdat <= x"00" & c1_nibble & c0_nibble;

	cache_wraddr <= cache_wraddr_d;
	process(rclk) begin
		if rising_edge(rclk) then
			if ram_ce = '1' then
				cache_wraddr_d <= fill_cnt;
				if fill_state = FS_FILL then
					cache_wren_d <= '1';
				else
					cache_wren_d <= '0';
				end if;
			end if;
		end if;
	end process;

	process(rclk, rstn) begin
		if rstn = '0' then
			fill_state <= FS_IDLE;
			fill_tgt   <= FT_NONE;
			fill_cnt   <= (others => '0');
			fill_de    <= '0';
			fill_chip  <= '0';
			bfill_g00  <= '0';
			bfill_g01  <= '0';
			bfill_g10  <= '0';
			bfill_g11  <= '0';
			g00addrh   <= (others => '1');
			g01addrh   <= (others => '1');
			g10addrh   <= (others => '1');
			g11addrh   <= (others => '1');
		elsif rising_edge(rclk) then
		  if ram_ce = '1' then
			fill_de <= '0';

			case fill_state is
			when FS_IDLE =>
				if g00_addr(awidth-1 downto 9) /= g00addrh and g00_rd = '1' then
					g00addrh   <= g00_addr(awidth-1 downto 9);
					fill_row   <= g00_addr(17 downto 9);
					fill_tgt   <= FT_G00;
					fill_chip  <= '0';
					fill_cnt   <= (others => '0');
					fill_state <= FS_FILL;
					bfill_g00  <= '1';
					if g01_addr(awidth-1 downto 9) = g00_addr(awidth-1 downto 9) then
						g01addrh   <= g00_addr(awidth-1 downto 9);
						bfill_g01  <= '1';
					else
						bfill_g01  <= '0';
					end if;
					bfill_g10  <= '0';
					bfill_g11  <= '0';
				elsif g01_addr(awidth-1 downto 9) /= g01addrh and g01_rd = '1' then
					g01addrh   <= g01_addr(awidth-1 downto 9);
					fill_row   <= g01_addr(17 downto 9);
					fill_tgt   <= FT_G01;
					fill_chip  <= '1';
					fill_cnt   <= (others => '0');
					fill_state <= FS_FILL;
					bfill_g01  <= '1';
					if g00_addr(awidth-1 downto 9) = g01_addr(awidth-1 downto 9) then
						g00addrh   <= g01_addr(awidth-1 downto 9);
						bfill_g00  <= '1';
					else
						bfill_g00  <= '0';
					end if;
					bfill_g10  <= '0';
					bfill_g11  <= '0';
				elsif g10_addr(awidth-1 downto 9) /= g10addrh and g10_rd = '1' then
					g10addrh   <= g10_addr(awidth-1 downto 9);
					fill_row   <= g10_addr(17 downto 9);
					fill_tgt   <= FT_G10;
					fill_chip  <= '0';
					fill_cnt   <= (others => '0');
					fill_state <= FS_FILL;
					bfill_g10  <= '1';
					if g11_addr(awidth-1 downto 9) = g10_addr(awidth-1 downto 9) then
						g11addrh   <= g10_addr(awidth-1 downto 9);
						bfill_g11  <= '1';
					else
						bfill_g11  <= '0';
					end if;
					bfill_g00  <= '0';
					bfill_g01  <= '0';
				elsif g11_addr(awidth-1 downto 9) /= g11addrh and g11_rd = '1' then
					g11addrh   <= g11_addr(awidth-1 downto 9);
					fill_row   <= g11_addr(17 downto 9);
					fill_tgt   <= FT_G11;
					fill_chip  <= '1';
					fill_cnt   <= (others => '0');
					fill_state <= FS_FILL;
					bfill_g11  <= '1';
					if g10_addr(awidth-1 downto 9) = g11_addr(awidth-1 downto 9) then
						g10addrh   <= g11_addr(awidth-1 downto 9);
						bfill_g10  <= '1';
					else
						bfill_g10  <= '0';
					end if;
					bfill_g00  <= '0';
					bfill_g01  <= '0';
				end if;

			when FS_FILL =>
				fill_de <= '1';
				if fill_cnt = "111111111" then  -- 511
					fill_state <= FS_LAST;
				else
					fill_cnt <= fill_cnt + 1;
				end if;

			when FS_LAST =>
				fill_de    <= '0';
				fill_state <= FS_DONE;

			when FS_DONE =>
				fill_tgt   <= FT_NONE;
				fill_state <= FS_IDLE;
			end case;

			if cpu_inv_pulse_r = '1' then
				if g00addrh(8 downto 0) = cpu_inv_row_r then
					g00addrh <= (others => '1');
				end if;
				if g01addrh(8 downto 0) = cpu_inv_row_r then
					g01addrh <= (others => '1');
				end if;
				if g10addrh(8 downto 0) = cpu_inv_row_r then
					g10addrh <= (others => '1');
				end if;
				if g11addrh(8 downto 0) = cpu_inv_row_r then
					g11addrh <= (others => '1');
				end if;
			end if;

			if clr_start_pulse = '1' then
				g00addrh <= (others => '1');
				g01addrh <= (others => '1');
				g10addrh <= (others => '1');
				g11addrh <= (others => '1');
			end if;
		  end if;
		end if;
	end process;

	process(sclk) begin
		if rising_edge(sclk) then
			if sys_ce = '1' then
				clr_active_r1 <= clr_active;
			end if;
		end if;
	end process;
	clr_start_pulse <= clr_active and not clr_active_r1;

	process(sclk, rstn) begin
		if rstn = '0' then
			clr_active <= '0';
			clr_cnt    <= (others => '0');
			clr_page   <= (others => '0');
			clr_chip   <= '0';
			g0caddrh   <= (others => '1');
			g1caddrh   <= (others => '1');
		elsif rising_edge(sclk) then
			if sys_ce = '1' then
				if clr_active = '1' then
					if clr_cnt = "1111111" then  -- 127: clear 128 words per row
						clr_active <= '0';
					else
						clr_cnt <= clr_cnt + 1;
					end if;
				else
					if g0_caddr /= g0caddrh and g0_clear = '1' and rmw_state = RMW_IDLE and rst_clr_active = '0' then
						g0caddrh   <= g0_caddr;
						clr_page   <= g0_caddr(17 downto 9);
						clr_chip   <= '0';
						clr_cnt    <= (others => '0');
						clr_active <= '1';
					elsif g1_caddr /= g1caddrh and g1_clear = '1' and rmw_state = RMW_IDLE and rst_clr_active = '0' then
						g1caddrh   <= g1_caddr;
						clr_page   <= g1_caddr(17 downto 9);
						clr_chip   <= '1';
						clr_cnt    <= (others => '0');
						clr_active <= '1';
					end if;
				end if;
			end if;
		end if;
	end process;

	g00rwr <= cache_wren_d when bfill_g00 = '1' else '0';
	g01rwr <= cache_wren_d when bfill_g01 = '1' else '0';
	g10rwr <= cache_wren_d when bfill_g10 = '1' else '0';
	g11rwr <= cache_wren_d when bfill_g11 = '1' else '0';

	g00_cache_wrdat <= cache_wrdat;
	g01_cache_wrdat <= cache_wrdat;
	g10_cache_wrdat <= cache_wrdat;
	g11_cache_wrdat <= cache_wrdat;

	g00_cache_i : CACHEMEMWN generic map(9) port map(
		g00_cache_wrdat, g00_addr(8 downto 0), vclk, cache_wraddr, rclk, g00rwr and ram_ce, g00_rdat);
	g01_cache_i : CACHEMEMWN generic map(9) port map(
		g01_cache_wrdat, g01_addr(8 downto 0), vclk, cache_wraddr, rclk, g01rwr and ram_ce, g01_rdat);
	g10_cache_i : CACHEMEMWN generic map(9) port map(
		g10_cache_wrdat, g10_addr(8 downto 0), vclk, cache_wraddr, rclk, g10rwr and ram_ce, g10_rdat);
	g11_cache_i : CACHEMEMWN generic map(9) port map(
		g11_cache_wrdat, g11_addr(8 downto 0), vclk, cache_wraddr, rclk, g11rwr and ram_ce, g11_rdat);

	g00ack_i: vrcack generic map(awidth, 9) port map(
		g00_rd, g00_addr, g00addrh, cache_wraddr, g00rwr, g00_ack, vclk, vid_ce, rstn);
	g01ack_i: vrcack generic map(awidth, 9) port map(
		g01_rd, g01_addr, g01addrh, cache_wraddr, g01rwr, g01_ack, vclk, vid_ce, rstn);
	g10ack_i: vrcack generic map(awidth, 9) port map(
		g10_rd, g10_addr, g10addrh, cache_wraddr, g10rwr, g10_ack, vclk, vid_ce, rstn);
	g11ack_i: vrcack generic map(awidth, 9) port map(
		g11_rd, g11_addr, g11addrh, cache_wraddr, g11rwr, g11_ack, vclk, vid_ce, rstn);

end rtl;
