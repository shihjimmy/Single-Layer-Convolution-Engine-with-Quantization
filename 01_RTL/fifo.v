module DW_fifo_s2_sf_inst(
    inst_clk_push, 
    inst_clk_pop, 
    inst_rst_n,                          
    inst_push_req_n, 
    inst_pop_req_n, 
    inst_data_in,                          
    push_empty_inst, 
    push_ae_inst, 
    push_hf_inst,                          
    push_af_inst, 
    push_full_inst, 
    push_error_inst,                          
    pop_empty_inst, 
    pop_ae_inst, 
    pop_hf_inst,                           
    pop_af_inst, 
    pop_full_inst, 
    pop_error_inst,                          
    data_out_inst 
);  
    parameter width = 8;  
    parameter depth = 8;  
    parameter push_ae_lvl = 2;  
    parameter push_af_lvl = 2;  
    parameter pop_ae_lvl = 2;  
    parameter pop_af_lvl = 2;  
    parameter err_mode = 0;  
    parameter push_sync = 2;  
    parameter pop_sync = 2;  
    parameter rst_mode = 0;  

    input inst_clk_push;  
    input inst_clk_pop;  
    input inst_rst_n;  
    input inst_push_req_n;  
    input inst_pop_req_n;  
    input [width-1 : 0] inst_data_in;  
    
    output push_empty_inst;  
    output push_ae_inst;  
    output push_hf_inst;  
    output push_af_inst;  
    output push_full_inst;  
    output push_error_inst;  

    output pop_empty_inst;  
    output pop_ae_inst;  
    output pop_hf_inst;  
    output pop_af_inst;  
    output pop_full_inst;  
    output pop_error_inst;  
    output [width-1 : 0] data_out_inst;


    // Instance of DW_fifo_s2_sf  
    DW_fifo_s2_sf #(
        width,  depth,  push_ae_lvl,  push_af_lvl,  pop_ae_lvl, pop_af_lvl,  
        err_mode,  push_sync,  pop_sync,  rst_mode
    )    
    U1 (
        .clk_push(inst_clk_push),   
        .clk_pop(inst_clk_pop), 
        .rst_n(inst_rst_n),   
        .push_req_n(inst_push_req_n),   
        .pop_req_n(inst_pop_req_n),
        .data_in(inst_data_in),         
        .push_empty(push_empty_inst),   
        .push_ae(push_ae_inst),        
        .push_hf(push_hf_inst),   
        .push_af(push_af_inst),         
        .push_full(push_full_inst),   
        .push_error(push_error_inst),         
        .pop_empty(pop_empty_inst),   
        .pop_ae(pop_ae_inst),         
        .pop_hf(pop_hf_inst),   
        .pop_af(pop_af_inst),
        .pop_full(pop_full_inst),   
        .pop_error(pop_error_inst),         
        .data_out(data_out_inst) 
    );
         
endmodule
