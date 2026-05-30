-- GVRAM in BRAM: 2 x 64K x 16-bit true dual-port RAM for X68000 graphics VRAM

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY gvram_bram IS
	PORT
	(
		-- Chip 0 Port A: read+write (RMW reads via q_a, CPU/clear writes)
		c0_address_a	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c0_data_a		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c0_wren_a		: IN STD_LOGIC := '0';
		c0_q_a			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		-- Chip 0 Port B: read-only (cache fills)
		c0_address_b	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c0_q_b			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);

		-- Chip 1 Port A: read+write
		c1_address_a	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c1_data_a		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c1_wren_a		: IN STD_LOGIC := '0';
		c1_q_a			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		-- Chip 1 Port B: read-only (cache fills)
		c1_address_b	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		c1_q_b			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);

		-- Shared clocks
		clock_a		: IN STD_LOGIC;
		clock_b		: IN STD_LOGIC
	);
END gvram_bram;

ARCHITECTURE SYN OF gvram_bram IS
	signal c0_data_b_zero : STD_LOGIC_VECTOR(15 DOWNTO 0) := (others => '0');
	signal c1_data_b_zero : STD_LOGIC_VECTOR(15 DOWNTO 0) := (others => '0');
BEGIN
	CHIP0: altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK1",
		clock_enable_input_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		intended_device_family => "Cyclone V",
		lpm_type => "altsyncram",
		numwords_a => 65536,
		numwords_b => 65536,
		operation_mode => "BIDIR_DUAL_PORT",
		ram_block_type => "M10K",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_mixed_ports => "OLD_DATA",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => 16,
		widthad_b => 16,
		width_a => 16,
		width_b => 16,
		width_byteena_a => 1,
		width_byteena_b => 1,
		wrcontrol_wraddress_reg_b => "CLOCK1"
	)
	PORT MAP (
		address_a => c0_address_a,
		address_b => c0_address_b,
		clock0 => clock_a,
		clock1 => clock_b,
		data_a => c0_data_a,
		data_b => c0_data_b_zero,
		wren_a => c0_wren_a,
		wren_b => '0',
		q_a => c0_q_a,
		q_b => c0_q_b
	);

	CHIP1: altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK1",
		clock_enable_input_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		intended_device_family => "Cyclone V",
		lpm_type => "altsyncram",
		numwords_a => 65536,
		numwords_b => 65536,
		operation_mode => "BIDIR_DUAL_PORT",
		ram_block_type => "M10K",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_mixed_ports => "OLD_DATA",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => 16,
		widthad_b => 16,
		width_a => 16,
		width_b => 16,
		width_byteena_a => 1,
		width_byteena_b => 1,
		wrcontrol_wraddress_reg_b => "CLOCK1"
	)
	PORT MAP (
		address_a => c1_address_a,
		address_b => c1_address_b,
		clock0 => clock_a,
		clock1 => clock_b,
		data_a => c1_data_a,
		data_b => c1_data_b_zero,
		wren_a => c1_wren_a,
		wren_b => '0',
		q_a => c1_q_a,
		q_b => c1_q_b
	);
END SYN;
