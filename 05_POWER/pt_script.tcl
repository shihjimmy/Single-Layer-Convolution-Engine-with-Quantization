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

#======================================================
#  Power Analysis
#======================================================

#PrimeTime Script
set power_enable_analysis TRUE
#set power_analysis_mode time_based

read_file -format verilog  ../02_SYN/Netlist/top_syn.v
current_design top
link

read_sdf -load_delay net ../02_SYN/Netlist/top_syn.sdf


## Measure  power
#report_switching_activity -list_not_annotated -show_pin
read_saif  -strip_path test/u_top  ../03_GATE/CONV_p0.saif 
update_power
report_power 
report_power >> p0_2.power

read_saif   -strip_path test/u_top  ../03_GATE/CONV_p1.saif 
update_power
report_power 
report_power >> p0_2.power

read_saif   -strip_path test/u_top  ../03_GATE/CONV_p2.saif 
update_power
report_power 
report_power >> p0_2.power

exit
