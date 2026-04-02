LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity dpssram is
generic(
	awidth	:integer	:=8;
	dwidth	:integer	:=8
);
port(
	addr1	:in std_logic_vector(awidth-1 downto 0);
	wdat1	:in std_logic_vector(dwidth-1 downto 0);
	wr1	:in std_logic;
	rdat1	:out std_logic_vector(dwidth-1 downto 0);
	
	addr2	:in std_logic_vector(awidth-1 downto 0);
	wdat2	:in std_logic_vector(dwidth-1 downto 0);
	wr2	:in std_logic;
	rdat2	:out std_logic_vector(dwidth-1 downto 0);
	
	clk	:in std_logic
);
end dpssram;

architecture rtl of dpssram is
constant arange	:integer	:=2**awidth;
begin
	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK0",
		clock_enable_input_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		indata_reg_b => "CLOCK0",
		intended_device_family => "Cyclone V",
		lpm_type => "altsyncram",
		numwords_a => arange,
		numwords_b => arange,
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_mixed_ports => "DONT_CARE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => awidth,
		widthad_b => awidth,
		width_a => dwidth,
		width_b => dwidth,
		width_byteena_a => 1,
		width_byteena_b => 1,
		wrcontrol_wraddress_reg_b => "CLOCK0"
	)
	PORT MAP (
		address_a => addr1,
		address_b => addr2,
		clock0 => clk,
		data_a => wdat1,
		data_b => wdat2,
		wren_a => wr1,
		wren_b => wr2,
		q_a => rdat1,
		q_b => rdat2
	);
end rtl;

