module FIFO_READ_WRAPPER(
    input clk_top               ,
    input clk_ram               ,
    input rst_n                 ,

    output [14:0] araddr        ,
    output [7:0]  arlen         ,
    output [2:0]  arsize        ,
    output [1:0]  arburst       ,
    output arvalid              ,
    input  arready              ,

    input  [7:0] rdata          ,
    input  [1:0] rresp          ,
    input  rlast                ,
    input  rvalid               ,
    output rready               ,

    input         start         ,
    input [2:0]   current       ,
    input         can_finish    ,

    output [7:0]  fifo_bitmask  ,
    output [7:0]  fifo_data     ,
    input  fifo_pop_bitmask     ,
    input  fifo_pop_data        ,
    output fifo_bitmask_full    ,
    output fifo_data_full       ,
    output fifo_bitmask_empty   ,
    output fifo_data_empty         
);

    localparam S_IDLE = 0;
    localparam S_PARAM = 1;
    localparam S_BITMASK = 2;
    localparam S_DATA = 3;
    localparam S_WAIT = 4;
    localparam S_CLEAN = 5;

    reg [2:0] state_r, state_w;
    reg [14:0] data_addr_r, data_addr_w;
    reg [14:0] bitmask_addr_r, bitmask_addr_w;


    //----------------------------------------------//
    // for read FIFO
    wire fifo_clean;
    reg read_ivalid;
    reg [15:0] read_idata;

    FIFO_READ_CONTROLLER u_read(
        .clk_top     (clk_top)      ,
        .clk_ram     (clk_ram)      ,
        .rst_n       (rst_n)        ,

        .araddr      (araddr)       ,
        .arlen       (arlen)        ,
        .arsize      (arsize)       ,
        .arburst     (arburst)      ,
        .arvalid     (arvalid)      ,
        .arready     (arready)      ,

        .rdata       (rdata)        ,
        .rresp       (rresp)        ,
        .rlast       (rlast)        ,
        .rvalid      (rvalid)       ,
        .rready      (rready)       ,

        .current     (current)      ,
        .fifo_ivalid (read_ivalid)  ,
        .fifo_idata  (read_idata)   ,

        .fifo_clean          (fifo_clean)           ,
        .fifo_bitmask        (fifo_bitmask)         ,
        .fifo_data           (fifo_data)            ,
        .fifo_pop_bitmask    (fifo_pop_bitmask)     ,
        .fifo_pop_data       (fifo_pop_data)        ,
        .fifo_bitmask_full   (fifo_bitmask_full)    ,
        .fifo_data_full      (fifo_data_full)       ,
        .fifo_bitmask_empty  (fifo_bitmask_empty)   ,
        .fifo_data_empty     (fifo_data_empty)
    );


    //----------------------------------------------//

    always@ (*) begin
        case(state_r)
            S_IDLE:     state_w = (start)                   ? S_PARAM   : S_IDLE;
            S_PARAM:    state_w = (~fifo_data_empty)        ? S_WAIT    : S_PARAM;
            S_BITMASK:  state_w = (~fifo_bitmask_empty)     ? S_WAIT    : S_BITMASK;
            S_DATA:     state_w = (~fifo_data_empty)        ? S_WAIT    : S_DATA;
            S_WAIT:     state_w = (can_finish)              ? S_CLEAN   : (fifo_bitmask_empty) ? S_BITMASK : (fifo_data_empty) ? S_DATA : S_WAIT;
            S_CLEAN:    state_w = (fifo_data_empty && fifo_bitmask_empty)     ? S_IDLE    : S_CLEAN;          
            default:    state_w = state_r;
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)      state_r         <= 0;
        else            state_r         <= state_w;
    end

    assign fifo_clean = state_r==S_CLEAN;

    always@ (*) begin
        read_ivalid = 0;
        read_idata = 0;

        case(state_r)
            S_IDLE: begin
                if(state_w == S_PARAM) begin
                    read_ivalid = 1;
                    
                    case(current)
                        3'd0:       read_idata = {1'd1, 15'd1152}; 
                        3'd1:       read_idata = {1'd1, 15'd1168}; 
                        3'd2:       read_idata = {1'd1, 15'd1184}; 
                        3'd3:       read_idata = {1'd1, 15'd1200}; 
                        3'd4:       read_idata = {1'd1, 15'd1216}; 
                        3'd5:       read_idata = {1'd1, 15'd1232}; 
                        3'd6:       read_idata = {1'd1, 15'd1248}; 
                        3'd7:       read_idata = {1'd1, 15'd1264}; 
                        default:    read_idata = {1'd1, 15'd0}; 
                    endcase
                end
            end

            S_WAIT: begin
                if(state_w == S_BITMASK) begin
                    read_ivalid = 1;    
                    read_idata = {1'd0, bitmask_addr_r};
                end
                else if(state_w == S_DATA) begin
                    read_ivalid = 1;
                    read_idata = {1'd1, data_addr_r};
                end
            end
        endcase
    end
    
    wire bitmask_enable;
    assign bitmask_enable = (state_r==S_IDLE && start) || (state_r==S_BITMASK && state_w==S_WAIT);

    wire data_enable;
    assign data_enable = (state_r==S_IDLE && start) || (state_r==S_DATA && state_w==S_WAIT);

    always@ (*) begin
        data_addr_w = data_addr_r;
        bitmask_addr_w = bitmask_addr_r;
        
        case(state_r)
            S_IDLE: begin
                data_addr_w = 15'd129;
                bitmask_addr_w = 15'd4;
            end

            S_BITMASK: begin
                if(state_w == S_WAIT) begin
                    bitmask_addr_w = bitmask_addr_r + 15'd16;
                end
            end

            S_DATA: begin
                if(state_w == S_WAIT) begin
                    data_addr_w = data_addr_r + 15'd16;
                end
            end
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)              bitmask_addr_r  <= 0;
        else if(bitmask_enable) bitmask_addr_r  <= bitmask_addr_w;
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)              data_addr_r     <= 0;
        else if(data_enable)    data_addr_r     <= data_addr_w;
    end

endmodule


module FIFO_READ_CONTROLLER (
    input clk_top               ,
    input clk_ram               ,
    input rst_n                 ,

    output reg [14:0] araddr    ,
    output reg [7:0]  arlen     ,
    output reg [2:0]  arsize    ,
    output reg [1:0]  arburst   ,
    output reg arvalid          ,
    input  arready              ,

    input  [7:0] rdata          ,
    input  [1:0] rresp          ,
    input  rlast                ,
    input  rvalid               ,
    output reg rready           ,

    input [2:0]   current       ,
    input         fifo_ivalid   ,
    input  [15:0] fifo_idata    ,

    input         fifo_clean    ,

    output [7:0]  fifo_bitmask  ,
    output [7:0]  fifo_data     ,
    input  fifo_pop_bitmask     ,
    input  fifo_pop_data        ,
    output fifo_bitmask_full    ,
    output fifo_data_full       ,
    output fifo_bitmask_empty   ,
    output fifo_data_empty            
);
    //--------------------------------------------------//
    // run under clk_ram
    localparam ram_IDLE = 0;
    localparam ram_ARREADY_BITMASK = 1;
    localparam ram_ARGET_BITMASK = 2;
    localparam ram_ARREADY_DATA = 3;
    localparam ram_ARGET_DATA = 4;

    reg  [2:0] ram_state_r, ram_state_w;

    //--------------------------------------------------//
    // for FIFO
    wire send_pop_n;
    wire send_pop_empty;
    wire [15:0] send_fifo_dataout;

    wire bitmask_push_n, bitmask_pop_n;
    wire [7:0] bitmask_fifo_datain;

    wire data_push_n, data_pop_n;
    wire [7:0] data_fifo_datain;
    

    DW_fifo_s2_sf_inst #(
        .width(16),
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
    u_fifo_send (
        .inst_clk_push(clk_top), 
        .inst_clk_pop(clk_ram), 
        .inst_rst_n(rst_n),      
        .inst_push_req_n(~fifo_ivalid),     
        .inst_pop_req_n(send_pop_n), 
        .inst_data_in(fifo_idata),    
        .push_empty_inst(), 
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
    u_fifo_bitmask (
        .inst_clk_push(clk_ram), 
        .inst_clk_pop(clk_top), 
        .inst_rst_n(rst_n),      
        .inst_push_req_n(bitmask_push_n), 
        .inst_pop_req_n(bitmask_pop_n), 
        .inst_data_in(bitmask_fifo_datain),    
        .push_empty_inst(), 
        .push_ae_inst(), 
        .push_hf_inst(),    
        .push_af_inst(), 
        .push_full_inst(), 
        .push_error_inst(), 
        .pop_empty_inst( fifo_bitmask_empty ), 
        .pop_ae_inst(), 
        .pop_hf_inst(),     
        .pop_af_inst(), 
        .pop_full_inst( fifo_bitmask_full ), 
        .pop_error_inst(),  
        .data_out_inst( fifo_bitmask )
    );


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
    u_fifo_data (
        .inst_clk_push(clk_ram), 
        .inst_clk_pop(clk_top), 
        .inst_rst_n(rst_n),      
        .inst_push_req_n(data_push_n), 
        .inst_pop_req_n(data_pop_n), 
        .inst_data_in(data_fifo_datain),    
        .push_empty_inst(), 
        .push_ae_inst(), 
        .push_hf_inst(),    
        .push_af_inst(), 
        .push_full_inst(), 
        .push_error_inst(), 
        .pop_empty_inst( fifo_data_empty ), 
        .pop_ae_inst(), 
        .pop_hf_inst(),     
        .pop_af_inst(), 
        .pop_full_inst( fifo_data_full ), 
        .pop_error_inst(),  
        .data_out_inst( fifo_data )
    );


    //--------------------------------------------------//
    // ram CDC control
    always@ (*) begin
        case(ram_state_r)
            ram_IDLE:               ram_state_w = (~send_pop_empty && send_fifo_dataout[15])  ? ram_ARREADY_DATA 
                                                : (~send_pop_empty && ~send_fifo_dataout[15]) ? ram_ARREADY_BITMASK : ram_state_r;
            ram_ARREADY_BITMASK:    ram_state_w = (arready && arvalid) ? ram_ARGET_BITMASK : ram_state_r;
            ram_ARGET_BITMASK:      ram_state_w = (rlast && rvalid) ? ram_IDLE : ram_state_r; 
            ram_ARREADY_DATA:       ram_state_w = (arready && arvalid) ? ram_ARGET_DATA : ram_state_r;
            ram_ARGET_DATA:         ram_state_w = (rlast && rvalid) ? ram_IDLE : ram_state_r; 
            default:                ram_state_w = ram_state_r;
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

    always@ (*) begin
        arsize     = 3'd0;
        arburst    = 2'b01;
        arlen      = 8'd15;
        arvalid    = ( ~send_pop_empty && (ram_state_r == ram_ARREADY_BITMASK || ram_state_r == ram_ARREADY_DATA) );
        araddr     = (~send_pop_empty) ? send_fifo_dataout[0 +: 15] : 0;
        rready     = ram_state_r == ram_ARGET_BITMASK || ram_state_r == ram_ARGET_DATA;
    end


    assign send_pop_n          = ~(arvalid && arready);

    assign bitmask_fifo_datain = (ram_state_r==ram_ARGET_BITMASK && rvalid) ? rdata : 0;
    assign bitmask_push_n      = ~(ram_state_r==ram_ARGET_BITMASK && rvalid);
    assign bitmask_pop_n       = ~(~fifo_bitmask_empty && (fifo_pop_bitmask || fifo_clean));

    assign data_fifo_datain    = (ram_state_r==ram_ARGET_DATA && rvalid) ? rdata : 0;
    assign data_push_n         = ~(ram_state_r==ram_ARGET_DATA && rvalid);
    assign data_pop_n          = ~(~fifo_data_empty && (fifo_pop_data || fifo_clean));

    //--------------------------------------------------//

endmodule


