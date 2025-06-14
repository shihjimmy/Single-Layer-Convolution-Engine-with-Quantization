set CYCLE_TOP 2.3
set CYCLE_TB  50
set CYCLE_RAM 0.5

create_clock -name "clk_top"  -period $CYCLE_TOP   clk_top;
create_clock -name "clk_tb"   -period $CYCLE_TB    clk_tb ;
create_clock -name "clk_ram"  -period $CYCLE_RAM   clk_ram;

set_dont_touch_network      [get_clocks *]
set_fix_hold                [get_clocks *]
set_ideal_network           [get_ports clk*]
set_clock_uncertainty  0.1  [get_clocks *]
set_clock_latency      0.1  [get_clocks *]
set_clock_transition   0.1  [get_clocks *]

set_input_delay 0 -clock clk_ram [remove_from_collection [all_inputs] {clk_top clk_tb clk_ram rst_n}]
set_input_delay 0 -clock clk_top clk_top
set_input_delay 0 -clock clk_tb  clk_tb
set_input_delay 0 -clock clk_ram clk_ram
set_input_delay [ expr $CYCLE_TB*0.5 ] -clock clk_tb {rst_n}

set_output_delay 0  -clock clk_ram [remove_from_collection [all_outputs] {finish}]
set_output_delay 0  -clock clk_tb {finish}

set_drive        1        [all_inputs]
set_load         0.05     [all_outputs]



#====================================================== 
#  Clock Domain Crossing constraints
#======================================================
set_clock_groups -asynchronous -group {clk_top} -group {clk_tb  clk_ram}
set_clock_groups -asynchronous -group {clk_tb}  -group {clk_top clk_ram}
set_clock_groups -asynchronous -group {clk_ram} -group {clk_top clk_tb}
