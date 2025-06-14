#======================================================
#  Initialization
#======================================================

sh rm -rf Netlist
sh rm -rf Report
sh mkdir Netlist
sh mkdir Report

#======================================================
#  Set Libraries: Check whether the locations are correct
#======================================================

set search_path {. \
    /share1/tech/ADFP/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/CCS \
    /share1/tech/ADFP/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/NLDM \
}
set target_library { \
    N16ADFP_StdCellss0p72vm40c_ccs.db \
    N16ADFP_StdCellff0p88v125c_ccs.db \
    N16ADFP_SRAM_ss0p72v0p72vm40c_100a.db \
    N16ADFP_SRAM_ff0p88v0p88v125c_100a.db \
}
set link_library {* \
    N16ADFP_StdCellss0p72vm40c_ccs.db \
    N16ADFP_StdCellff0p88v125c_ccs.db \
    N16ADFP_SRAM_ss0p72v0p72vm40c_100a.db \
    N16ADFP_SRAM_ff0p88v0p88v125c_100a.db \
    dw_foundation.sldb \
}
set symbol_library {generic.sdb}
set synthetic_library {dw_foundation.sldb}

set default_schematic_option {-size infinite}

set hdlin_translate_off_skip_text "TRUE"
set edifout_netlist_only "TRUE"
set verilogout_no_tri true

set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing "TRUE"
set sh_line_editing_mode emacs

# set compile_seqmap_enable_output_inversion true

#======================================================
#  Global Parameters
#======================================================
set DESIGN "top"

#======================================================
#  Read RTL Code
#======================================================
analyze -format verilog "filelist.v"
elaborate $DESIGN
current_design $DESIGN
link

#======================================================
#  Global Setting
#======================================================
set_operating_conditions -max_library N16ADFP_StdCellss0p72vm40c_ccs -max ss0p72vm40c

#======================================================
#  Set Design Constraints
#======================================================
source -echo -verbose top_syn.sdc

#======================================================
#  Optimization
#======================================================
set_max_area 0

current_design $DESIGN
check_design > Report/check_design.txt
check_timing > Report/check_timing.txt

uniquify
set_fix_multiple_port_nets -all -buffer_constants

#clock gating
set_clock_gating_style \
    -max_fanout 4 \
    -pos integrated \
    -control_point before \
    -control_signal scan_enable 

#compile
compile_ultra -no_autoungroup
compile -gate_clock
compile -inc -only_hold_time

#======================================================
#  Output Reports 
#======================================================
report_area  > Report/${DESIGN}_syn.area
report_power > Report/${DESIGN}_syn.power
report_timing -delay min -max_paths 5 > Report/${DESIGN}_syn.timing_min
report_timing -delay max -max_paths 5 > Report/${DESIGN}_syn.timing_max

report_clock_gating -gating_elements
#report_clock_gating -ungated

#======================================================
#  Change Naming Rule
#======================================================
set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

#======================================================
#  Output Results
#======================================================

remove_unconnected_ports -blast_buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc     -hierarchy -output "./Netlist/${DESIGN}_syn.ddc"
write -format verilog -hierarchy -output "./Netlist/${DESIGN}_syn.v"
write_sdf -version 2.1  -context verilog -load_delay cell ./Netlist/${DESIGN}_syn.sdf
write_sdc  ./Netlist/${DESIGN}_syn.sdc -version 1.8

#====================================================== 
#  Finish and Quit 
#======================================================

report_timing
report_area
check_design

#exit
