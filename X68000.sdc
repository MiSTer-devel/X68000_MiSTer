derive_pll_clocks
derive_clock_uncertainty;

set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -start -setup 2
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -start -hold 1
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -end -setup 2
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -end -hold 1

set_multicycle_path -from {emu:emu|X68K_top:X68K_top|DMA63450:DMA|*} -setup 2
set_multicycle_path -from {emu:emu|X68K_top:X68K_top|DMA63450:DMA|*} -hold 1

set_multicycle_path -from {emu|X68K_top|MPU|*} -setup 2
set_multicycle_path -from {emu|X68K_top|MPU|*} -hold 1
set_multicycle_path -to   {emu|X68K_top|MPU|*} -setup 2
set_multicycle_path -to   {emu|X68K_top|MPU|*} -hold 1

set_false_path -from {emu:emu|X68K_top:X68K_top|contcont:cont|contval*}
