module FIFO_WRITE_WRAPPER(
    input clk_top               ,
    input clk_ram               , 
    input rst_n                 ,

    input start                 ,
    // can finish the calculation, after ending this row 
    input can_finish            ,
    input [2:0] current         ,
    input beginning             ,
    input data_valid            ,
    input push_valid            ,
    input [7:0] data            ,

    output [14:0] awaddr        ,
    output [ 7:0] awlen         ,
    output [ 2:0] awsize        ,
    output [ 1:0] awburst       ,
    output        awvalid       ,
    input         awready       ,

    output [7:0]  wdata         ,
    output        wstrb         ,
    output        wlast         ,
    output        wvalid        ,
    input         wready        ,

    output        finish
);

    localparam S_IDLE = 0;
    localparam S_WRITE_DATA_INFO = 1;
    localparam S_WRITE_DATA = 2;
    localparam S_WRITE_BITMASK_INFO_1 = 3;
    localparam S_WRITE_BITMASK_INFO_2 = 4;
    localparam S_WRITE_BITMASK = 5;
    localparam S_WAIT = 6;
    localparam S_FINISH = 7;

    reg [2:0]  state_r, state_w;
    reg [14:0] bitmask_addr_r, bitmask_addr_w;
    reg [14:0] data_addr_r, data_addr_w;
    reg [15:0] bitmask_r, bitmask_w;
    reg [4:0]  count_r, count_w, temp;


    //-----------------------------------------//
    // for FIFO_WRITE_CONTROLLER

    wire fifo_data_empty, fifo_info_empty;
    reg fifo_data_ivalid, fifo_info_ivalid;
    reg [7:0] fifo_data_idata;
    reg [22:0] fifo_info_idata;


    FIFO_WRITE_CONTROLLER u_fifo_control(
        .clk_top     (clk_top)      ,
        .clk_ram     (clk_ram)      ,
        .rst_n       (rst_n)        ,
        .awaddr      (awaddr  )     ,
        .awlen       (awlen   )     ,
        .awsize      (awsize  )     ,
        .awburst     (awburst )     ,
        .awvalid     (awvalid )     ,
        .awready     (awready )     ,
        .wdata       (wdata   )     ,
        .wstrb       (wstrb   )     ,
        .wlast       (wlast   )     ,
        .wvalid      (wvalid  )     ,
        .wready      (wready  )     , 
        .fifo_data_ivalid   (fifo_data_ivalid)    ,
        .fifo_data_idata    (fifo_data_idata )    ,
        .fifo_info_ivalid   (fifo_info_ivalid)    ,
        .fifo_info_idata    (fifo_info_idata )    ,
        .fifo_data_empty    (fifo_data_empty)     ,
        .fifo_info_empty    (fifo_info_empty)      
    );

    //-----------------------------------------//


    always@ (*) begin
        case(state_r)   
            S_IDLE:                     state_w = (start) ? S_WRITE_DATA_INFO : state_r;        
            S_WRITE_DATA_INFO:          state_w = S_WRITE_DATA;     
            S_WRITE_DATA:               state_w = (fifo_data_empty && fifo_info_empty) ? S_WRITE_BITMASK_INFO_1 : state_r;
            S_WRITE_BITMASK_INFO_1:     state_w = S_WRITE_BITMASK_INFO_2;
            S_WRITE_BITMASK_INFO_2:     state_w = S_WRITE_BITMASK;
            S_WRITE_BITMASK:            state_w = (fifo_data_empty && fifo_info_empty && can_finish) ? S_FINISH : (fifo_data_empty && fifo_info_empty) ? S_WAIT : state_r;
            S_WAIT:                     state_w = (start) ? S_WRITE_DATA_INFO : state_r; 
            S_FINISH:                   state_w = S_IDLE;
            default:                    state_w = state_r;
        endcase
    end

    assign finish = state_r == S_FINISH;

    always@ (*) begin
        bitmask_w = (data_valid && beginning) ? {bitmask_r[0 +: 15], 1'd0} : (data_valid) ? {bitmask_r[0 +: 15], push_valid} : bitmask_r;
        count_w   = (state_r == S_IDLE || state_r == S_WAIT)  ? ( count_r + (data_valid && (push_valid || beginning) )) : 0;
        temp      = count_r - 1'd1;
    end

    wire data_addr_enable;
    wire bitmask_addr_enable;
    assign data_addr_enable     = state_r==S_IDLE || state_r==S_WRITE_DATA_INFO;
    assign bitmask_addr_enable  = state_r==S_IDLE || state_r==S_WRITE_BITMASK_INFO_2;

    always@ (*) begin
        data_addr_w    = data_addr_r;
        bitmask_addr_w = bitmask_addr_r;

        case(state_r)
            S_IDLE: begin
                case(current)
                    3'd0: begin
                        data_addr_w    = 15'd1312;
                        bitmask_addr_w = 15'd1280;
                    end

                    3'd1: begin
                        data_addr_w    = 15'd1600;
                        bitmask_addr_w = 15'd1568;
                    end

                    3'd2: begin
                        data_addr_w    = 15'd1888;
                        bitmask_addr_w = 15'd1856;
                    end

                    3'd3: begin
                        data_addr_w    = 15'd2176;
                        bitmask_addr_w = 15'd2144;
                    end
                    
                    3'd4: begin
                        data_addr_w    = 15'd2464;
                        bitmask_addr_w = 15'd2432;
                    end
                    
                    3'd5: begin
                        data_addr_w    = 15'd2752;
                        bitmask_addr_w = 15'd2720;
                    end

                    3'd6: begin
                        data_addr_w    = 15'd3040;
                        bitmask_addr_w = 15'd3008;
                    end
                    
                    3'd7: begin
                        data_addr_w    = 15'd3328;
                        bitmask_addr_w = 15'd3296;
                    end
                endcase
            end

            S_WRITE_DATA_INFO: begin
                data_addr_w    = data_addr_r + count_r;
            end

            S_WRITE_BITMASK_INFO_2: begin
                bitmask_addr_w = bitmask_addr_r + 15'd2;
            end
        endcase
    end 

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)                      bitmask_addr_r  <= 0;
        else if(bitmask_addr_enable)    bitmask_addr_r  <= bitmask_addr_w;
    end


    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)                  data_addr_r     <= 0;
        else if(data_addr_enable)   data_addr_r     <= data_addr_w;
    end



    always@ (*) begin
        fifo_data_ivalid = 0;
        fifo_data_idata = 0;
        fifo_info_ivalid = 0;
        fifo_info_idata = 0;
        
        case(state_r)
            S_IDLE, S_WAIT: begin
                fifo_data_ivalid = (beginning || push_valid) & data_valid;
                fifo_data_idata  = data;
            end

            S_WRITE_DATA_INFO: begin
                fifo_info_ivalid = (|count_r) ? 1 : 0;
                fifo_info_idata  = {data_addr_r, 3'd0, temp};
            end

            S_WRITE_BITMASK_INFO_1: begin
                fifo_data_ivalid = 1;
                fifo_data_idata  = bitmask_r[8 +: 8];
            end
              
            S_WRITE_BITMASK_INFO_2: begin
                fifo_data_ivalid = 1;
                fifo_data_idata  = bitmask_r[0 +: 8];

                fifo_info_ivalid = 1;
                fifo_info_idata  = {bitmask_addr_r, 8'd1};
            end
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n) begin
            state_r         <= 0;
            bitmask_r       <= 0;
            count_r         <= 0;
        end
        else begin
            state_r         <= state_w;
            bitmask_r       <= bitmask_w;
            count_r         <= count_w;
        end
    end

endmodule


module FIFO_WRITE_CONTROLLER (
    input clk_top               ,
    input clk_ram               ,
    input rst_n                 ,

    output [14:0] awaddr        ,
    output [ 7:0] awlen         ,
    output [ 2:0] awsize        ,
    output [ 1:0] awburst       ,
    output        awvalid       ,
    input         awready       ,

    output [7:0]  wdata         ,
    output        wstrb         ,
    output        wlast         ,
    output        wvalid        ,
    input         wready        , 

    input          fifo_data_ivalid   ,
    input  [7:0]   fifo_data_idata    , 
    input          fifo_info_ivalid   ,
    input  [22:0]  fifo_info_idata    ,   
    output         fifo_data_empty    ,
    output         fifo_info_empty
);
    //--------------------------------------------------//
    // run under clk_ram
    localparam ram_IDLE = 0;
    localparam ram_AWREADY = 1;
    localparam ram_AWSEND = 2;

    reg [1:0] ram_state_r, ram_state_w;

    //--------------------------------------------------//
    // for FIFO
    reg send_pop_n;
    wire send_pop_empty;
    wire [22:0] send_fifo_dataout;

    DW_fifo_s2_sf_inst #(
        .width(23),
        .depth(4),  
        .push_ae_lvl(2), 
        .push_af_lvl(2),
        .pop_ae_lvl(2),
        .pop_af_lvl(2),
        .err_mode(0),  
        .push_sync(2), 
        .pop_sync(2),  
        .rst_mode(0)  
    ) 
    u_fifo_send_info (
        .inst_clk_push(clk_top), 
        .inst_clk_pop(clk_ram), 
        .inst_rst_n(rst_n),      
        .inst_push_req_n(~fifo_info_ivalid), 
        .inst_pop_req_n(send_pop_n), 
        .inst_data_in(fifo_info_idata),    
        .push_empty_inst(fifo_info_empty), 
        .push_ae_inst(), 
        .push_hf_inst(),    
        .push_af_inst(), 
        .push_full_inst(), 
        .push_error_inst(), 
        .pop_empty_inst(send_pop_empty), 
        .pop_ae_inst(), 
        .pop_hf_inst(),     
        .pop_af_inst(), 
        .pop_full_inst(), 
        .pop_error_inst(),  
        .data_out_inst(send_fifo_dataout)
    );

    reg fifo_data_pop_n;
    wire data_pop_empty;
    wire [7:0] data_fifo_dataout;

    DW_fifo_s2_sf_inst #(
        .width(8),
        .depth(16),  
        .push_ae_lvl(2), 
        .push_af_lvl(2),
        .pop_ae_lvl(2),
        .pop_af_lvl(2),
        .err_mode(0),  
        .push_sync(2), 
        .pop_sync(2),  
        .rst_mode(0)  
    ) 
    u_fifo_send_data (
        .inst_clk_push(clk_top), 
        .inst_clk_pop(clk_ram), 
        .inst_rst_n(rst_n),      
        .inst_push_req_n(~fifo_data_ivalid), 
        .inst_pop_req_n(fifo_data_pop_n), 
        .inst_data_in(fifo_data_idata),    
        .push_empty_inst(fifo_data_empty), 
        .push_ae_inst(), 
        .push_hf_inst(),    
        .push_af_inst(), 
        .push_full_inst(), 
        .push_error_inst(), 
        .pop_empty_inst(data_pop_empty), 
        .pop_ae_inst(), 
        .pop_hf_inst(),     
        .pop_af_inst(), 
        .pop_full_inst(), 
        .pop_error_inst(),  
        .data_out_inst(data_fifo_dataout)
    );

    //--------------------------------------------------//
    // ram CDC control

    always@ (*) begin
        case(ram_state_r)       
            ram_IDLE:           ram_state_w = (~send_pop_empty) ? ram_AWREADY : ram_IDLE;
            ram_AWREADY:        ram_state_w = (awready && awvalid) ? ram_AWSEND : ram_AWREADY;
            ram_AWSEND:         ram_state_w = (data_pop_empty && (~wready)) ? ram_IDLE : ram_AWSEND;
            default:            ram_state_w = ram_state_r;
        endcase
    end 

    wire ram_sleep;
    wire ram_enable;
    assign ram_sleep = ram_state_r == ram_IDLE && ram_state_w == ram_IDLE;
    assign ram_enable = ~ram_sleep;

    always@ (posedge clk_ram or negedge rst_n) begin
        if(!rst_n)                 ram_state_r <= ram_IDLE;
        else if(ram_enable)        ram_state_r <= ram_state_w;
    end


    assign awsize  = 3'd0;
    assign awburst = 2'b01;
    assign awlen   = (~send_pop_empty) ? send_fifo_dataout[0 +: 8]  : 0;
    assign awaddr  = (~send_pop_empty) ? send_fifo_dataout[8 +: 15] : 0;
    assign awvalid = ram_state_r == ram_AWREADY;

    assign wstrb   = 1'b1;
    assign wlast   = 1'b0; // this parameter is not used in AXI_RAM
    assign wvalid  = ram_state_r == ram_AWSEND && (~data_pop_empty);
    assign wdata   = (~data_pop_empty) ? data_fifo_dataout : 0;

    always@ (*) begin
        send_pop_n = ~(awready&&awvalid);
        fifo_data_pop_n = ~(wvalid && wready);
    end

    //--------------------------------------------------//

endmodule

