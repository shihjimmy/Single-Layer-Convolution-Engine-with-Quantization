module top # (
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 15,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    // Clock and Active-Low Reset
    input clk_top,
    input clk_tb ,
    input clk_ram,
    input rst_n  ,

    // Finish Flag
    output finish,

    // AXI port
    output [           ADDR_WIDTH-1:0] awaddr ,
    output [                      7:0] awlen  ,
    output [                      2:0] awsize ,
    output [                      1:0] awburst,
    output                             awvalid,
    input                              awready,

    output [           DATA_WIDTH-1:0] wdata  ,
    output [           STRB_WIDTH-1:0] wstrb  ,
    output                             wlast  ,
    output                             wvalid ,
    input                              wready , 

    // can be unused
    input  [                      1:0] bresp  ,
    input                              bvalid ,
    output                             bready ,

    output [           ADDR_WIDTH-1:0] araddr ,
    output [                      7:0] arlen  ,
    output [                      2:0] arsize ,
    output [                      1:0] arburst,
    output                             arvalid,
    input                              arready,

    input  [           DATA_WIDTH-1:0] rdata  ,
    input  [                      1:0] rresp  ,
    input                              rlast  ,
    input                              rvalid ,
    output                             rready
);  

    assign bready = 1;

    localparam S_IDLE  = 0;
    localparam S_PARAM = 1;
    localparam S_CALC = 2;
    localparam S_FINISH = 3;
    localparam S_WAIT = 4;

    reg [2:0] state_r, state_w;

    // count current image
    reg [2:0] current_img_r, current_img_w;
    // count finished row
    reg [5:0] current_row_r, current_row_w;
    // count current conv
    reg [4:0] current_conv_r, current_conv_w;
    // count current data
    reg [5:0] current_data_r, current_data_w;



    // store convolution & quantization results
    reg [7:0] conv_1_r[0:31], conv_1_w[0:31];
    reg [7:0] conv_2_r[0:31], conv_2_w[0:31];

    // store original data
    reg [7:0] data_1_r[0:31], data_1_w[0:31]; 
    reg [7:0] data_2_r[0:31], data_2_w[0:31]; 
    reg [7:0] data_3_r[0:31], data_3_w[0:31]; 


    // store parameters
    reg [127:0] param_r, param_w;
    reg [7:0] skipped_r, skipped_w;

    wire [7:0] param1, param2, param3, param4, param5, param6, param7, param8, param9;
    wire [23:0] bias;
    wire [31:0] scale;

    assign param1 = param_r[120 +: 8];
    assign param2 = param_r[112 +: 8];
    assign param3 = param_r[104 +: 8];
    assign param4 = param_r[96 +: 8];
    assign param5 = param_r[88 +: 8];
    assign param6 = param_r[80 +: 8];
    assign param7 = param_r[72 +: 8];
    assign param8 = param_r[64 +: 8];
    assign param9 = param_r[56 +: 8];
    assign bias   = param_r[32 +: 24];
    assign scale  = param_r[0 +: 32];

    //---------------------------------------------------//
    // for CDC FINISH

    wire finish_or_not;
    reg handshake_r;
    wire handshake;

    CDC_finish u_finish(
        .clk_A(clk_tb),
        .clk_B(clk_top),
        .rst(~rst_n),
        .finish(finish_or_not),
        .finish_CDC(finish),
        .handshake(handshake)
    );

    assign finish_or_not = (state_r==S_WAIT && state_w==S_FINISH) || (state_r==S_FINISH && handshake && !handshake_r);
    
    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)  handshake_r <= 0;
        else        handshake_r <= handshake;
    end


    //---------------------------------------------------//
    // for WRITE/ READ FIFO

    reg can_read_finish;
    reg read_start;
    reg can_read_finish_r, can_read_finish_w;

    wire [7:0] fifo_bitmask, fifo_data;
    reg fifo_pop_bitmask, fifo_pop_data;
    wire fifo_bitmask_empty, fifo_data_empty;
    wire fifo_bitmask_full, fifo_data_full;

    reg is_skipped;
    reg pixel_valid;
    reg [7:0] pixel_data;

    FIFO_READ_WRAPPER u_read_wrapper(
        .clk_top    (clk_top)   ,
        .clk_ram    (clk_ram)   ,
        .rst_n      (rst_n)     ,

        .araddr     (araddr)    ,
        .arlen      (arlen)     ,
        .arsize     (arsize)    ,
        .arburst    (arburst)   ,
        .arvalid    (arvalid)   ,
        .arready    (arready)   ,

        .rdata      (rdata)     ,
        .rresp      (rresp)     ,
        .rlast      (rlast)     ,
        .rvalid     (rvalid)    ,
        .rready     (rready)    ,

        .start         (read_start)         ,
        .current       (current_img_r)      ,
        .can_finish    (can_read_finish)    ,

        .fifo_bitmask         (fifo_bitmask)        ,
        .fifo_data            (fifo_data)           ,
        .fifo_pop_bitmask     (fifo_pop_bitmask)    ,
        .fifo_pop_data        (fifo_pop_data)       ,
        .fifo_bitmask_full    (fifo_bitmask_full)   ,
        .fifo_data_full       (fifo_data_full)      ,
        .fifo_bitmask_empty   (fifo_bitmask_empty)  ,
        .fifo_data_empty      (fifo_data_empty)
    );

    reg write_start;
    reg can_write_finish;
    reg can_write_finish_r, can_write_finish_w;
    
    reg data_valid, push_valid, beginning;
    reg [7:0] data;
    wire write_finish;

    FIFO_WRITE_WRAPPER u_write_wrapper(
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

        .start       (write_start)      ,
        .can_finish  (can_write_finish_r) ,
        .current     (current_img_r)    ,
        .beginning   (beginning)        ,
        .data_valid  (data_valid)       ,
        .push_valid  (push_valid)       ,
        .data        (data)             , 
        .finish      (write_finish)     
    );


    //---------------------------------------------------//
    // for Conv, Maxpool, quant

    reg start_conv;
    reg [7:0] data1, data2, data3, data4, data5, data6, data7, data8, data9;
    wire finish_conv;
    wire [19:0] result_conv;
 
    conv u_conv(
        .clk(clk_top),
        .rst_n(rst_n),

        .start(start_conv),
        .data1(data1),
        .data2(data2),
        .data3(data3),
        .data4(data4),
        .data5(data5),
        .data6(data6),
        .data7(data7),
        .data8(data8),
        .data9(data9),

        .param1(param1),
        .param2(param2),
        .param3(param3),
        .param4(param4),
        .param5(param5),
        .param6(param6),
        .param7(param7),
        .param8(param8),
        .param9(param9),
        .result(result_conv),
        .finish(finish_conv)
    );

    wire finish_quant;
    wire [7:0] result_quant;

    quantizer u_quant(
        .clk(clk_top),
        .rst_n(rst_n),
        .start(finish_conv),
        .data1(result_conv),
        .bias(bias),
        .scale(scale),
        .result(result_quant),
        .finish(finish_quant)
    );

    reg [7:0] conv1, conv2, conv3, conv4;
    wire [7:0] result;
    wire bitmask;
    
    maxpool u_maxpool(
        .data1(conv1),
        .data2(conv2),
        .data3(conv3),
        .data4(conv4),

        .skipped(skipped_r),
        .result(result),
        .bitmask(bitmask)
    );


    //---------------------------------------------------//
    // control signal for read FIFO
    
    // read_start
    always@ (*) begin
        read_start = state_r==S_IDLE;
    end

    // can read finish
    always@ (*) begin
        can_read_finish = (state_r == S_CALC) && (~fifo_data_empty) && (~(|fifo_data));

        case(state_r)
            S_IDLE:  can_read_finish_w = 0;
            S_CALC:  can_read_finish_w = (can_read_finish_r==0) ? can_read_finish : can_read_finish_r;
            default: can_read_finish_w = can_read_finish_r;
        endcase
    end

    // fifo_pop_bitmask
    always@ (*) begin
        fifo_pop_bitmask = ( &current_data_r[0+:3] && pixel_valid ) && (~fifo_bitmask_empty) && (state_r==S_CALC);
    end

    // fifo_pop_data / is_skipped
    always@ (*) begin
        is_skipped = 0;

        if(pixel_valid && !can_read_finish_r) begin
            case(current_data_r[0+:3])
                3'd0:   is_skipped = fifo_bitmask[7];
                3'd1:   is_skipped = fifo_bitmask[6];
                3'd2:   is_skipped = fifo_bitmask[5];
                3'd3:   is_skipped = fifo_bitmask[4];
                3'd4:   is_skipped = fifo_bitmask[3];
                3'd5:   is_skipped = fifo_bitmask[2];
                3'd6:   is_skipped = fifo_bitmask[1];
                3'd7:   is_skipped = fifo_bitmask[0];
            endcase
        end
    end

    always@ (*) begin
        fifo_pop_data = is_skipped || (state_r==S_PARAM && (~fifo_data_empty));
    end

    // pixel valid / pixel data
    always@ (*) begin
        pixel_valid = ( ( ~fifo_bitmask_empty && (~fifo_data_empty) ) || ( can_read_finish_r ) ) && (state_r == S_CALC);
        pixel_data = (is_skipped) ? fifo_data : 0;
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)   can_read_finish_r <= 0;
        else         can_read_finish_r <= can_read_finish_w;
    end


    //---------------------------------------------------//
    // control signal for write FIFO

    // write_start
    always@ (*) begin
        write_start = (&current_conv_r && finish_quant && current_row_r[0]);
    end

    // can_write_finish
    always@ (*) begin
        can_write_finish   = &(current_row_r[4:0]);
        can_write_finish_w = (write_finish && can_write_finish_r) ? 0 : (can_write_finish && ~can_write_finish_r) ? 1 : can_write_finish_r;
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)   can_write_finish_r <= 0;
        else         can_write_finish_r <= can_write_finish_w;
    end

    // data / data_valid / push_valid / beginning
    always@ (*) begin
        beginning   = (current_row_r==1 && current_conv_r==1);
        data        = result;
        push_valid  = bitmask;
        data_valid  = current_row_r[0] && current_conv_r[0] && finish_quant;
    end


    //---------------------------------------------------//
    // signal for calculation

    // start_conv
    always@ (*) begin
        if(state_r == S_CALC)   start_conv = (pixel_valid && (|current_data_r)) || (current_data_r[5]);
        else                    start_conv = 0;
    end

    // data 1~9
    always@ (*) begin
        data1 = 0;
        data2 = 0;
        data3 = 0;
        data4 = 0;
        data5 = 0;
        data6 = 0;
        data7 = 0;
        data8 = 0;
        data9 = 0;

        if(state_r == S_CALC && pixel_valid) begin
            case(current_data_r)
                6'd0: begin
                    data1 = 0;
                    data2 = 0;
                    data3 = 0;
                    data4 = 0;
                    data5 = 0;
                    data6 = 0;
                    data7 = 0;
                    data8 = 0;
                    data9 = 0;
                end

                6'd1: begin
                    data1 = 0;
                    data2 = data_1_r[0];
                    data3 = data_1_r[1];
                    data4 = 0;
                    data5 = data_2_r[0];
                    data6 = data_2_r[1];
                    data7 = 0;
                    data8 = data_3_r[0];
                    data9 = pixel_data;
                end

                6'd32: begin
                    data1 = data_1_r[30];
                    data2 = data_1_r[31];
                    data3 = 0;
                    data4 = data_2_r[30];
                    data5 = data_2_r[31];
                    data6 = 0;
                    data7 = data_3_r[30];
                    data8 = data_3_r[31];
                    data9 = 0;
                end

                default: begin
                    data1 = data_1_r[ (current_data_r-2) ];
                    data2 = data_1_r[ (current_data_r-1) ];
                    data3 = data_1_r[ current_data_r ];
                    data4 = data_2_r[ (current_data_r-2) ];
                    data5 = data_2_r[ (current_data_r-1) ];
                    data6 = data_2_r[ current_data_r ];
                    data7 = data_3_r[ (current_data_r-2) ];
                    data8 = data_3_r[ (current_data_r-1) ];
                    data9 = pixel_data;
                end
            endcase
        end
    end

    // conv 1~4
    always@ (*) begin
        conv1 = 0;
        conv2 = 0;
        conv3 = 0;
        conv4 = 0;

        if( (state_r == S_CALC || state_r == S_WAIT) && current_row_r[0] && finish_quant) begin
            if(current_conv_r[0]) begin
                conv1 = conv_1_r[ {current_conv_r[1 +: 4], 1'd0} ];
                conv2 = conv_1_r[ current_conv_r ];
                conv3 = conv_2_r[ {current_conv_r[1 +: 4], 1'd0} ];
                conv4 = result_quant;
            end
        end
    end

    //---------------------------------------------------//

    always@ (*) begin
        case(state_r)
            S_IDLE:     state_w = (fifo_data_full)  ? S_PARAM : S_IDLE;    
            S_PARAM:    state_w = (fifo_data_empty) ? S_CALC  : S_PARAM;     
            S_CALC:     state_w = (current_data_r[5] && (&current_row_r[4:0])) ? S_WAIT : S_CALC; 
            S_WAIT:     state_w = (&current_img_r && write_finish) ? S_FINISH : (write_finish) ? S_IDLE : S_WAIT;   
            S_FINISH:   state_w = S_FINISH;    
            default:    state_w = state_r;    
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)  state_r <= 0;
        else        state_r <= state_w;
    end


    // parameters
    wire param_enable;
    assign param_enable = (state_r == S_PARAM) && (~fifo_data_empty);

    always@ (*) begin
        param_w = param_r;

        if((state_r == S_PARAM) && (~fifo_data_empty)) begin
            param_w = {param_r[0 +: 120], fifo_data};
        end
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)                  param_r <= 0;
        else  if(param_enable)      param_r <= param_w;
    end

    
    // skipped
    wire skipped_enable;
    assign skipped_enable = beginning && finish_quant;

    always@ (*) begin
        skipped_w = skipped_r;

        if( beginning && finish_quant ) 
            skipped_w = (conv_2_r[0] < result_quant) ? result_quant : conv_2_r[0];
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)                    skipped_r <= 0;
        else if(skipped_enable)       skipped_r <= skipped_w;
    end

    

    // current img
    wire img_enable;
    assign img_enable = state_r == S_WAIT && state_w == S_IDLE;

    always@ (*) begin
        current_img_w = current_img_r;

        if(state_r == S_WAIT && state_w == S_IDLE) begin
            current_img_w = current_img_r + 1;
        end
    end
    
    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)              current_img_r <= 0;
        else if(img_enable)     current_img_r <= current_img_w;
    end


    // current row
    wire row_enable;
    assign row_enable = state_r==S_IDLE || ( (&current_conv_r && finish_quant)&&(state_r==S_CALC || state_r==S_WAIT) );

    always@ (*) begin
        current_row_w = current_row_r;

        case(state_r)
            S_IDLE: current_row_w = 0;
            S_CALC, S_WAIT: current_row_w = current_row_r + ( (&current_conv_r && finish_quant) );
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)              current_row_r <= 0;
        else if(row_enable)     current_row_r <= current_row_w;
    end


    // current conv
    always@ (*) begin
        current_conv_w = current_conv_r;

        case(state_r)
            S_IDLE: current_conv_w = 0;
            S_CALC, S_WAIT: current_conv_w = current_conv_r + finish_quant;
        endcase 
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)  current_conv_r <= 0;
        else        current_conv_r <= current_conv_w;
    end



    // current data
    always@ (*) begin
        if(current_data_r[5] || state_r==S_WAIT || state_r==S_IDLE) begin
            current_data_w = 0;
        end
        else begin
            current_data_w = current_data_r + pixel_valid;
        end
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n)  current_data_r <= 0;
        else        current_data_r <= current_data_w;
    end


    // data-regs
    wire data_enable;
    assign data_enable = (state_r==S_CALC && state_w!=S_IDLE) || (state_r==S_CALC && (pixel_valid || current_data_r[5]));

    integer i;
    always@ (*) begin
        for(i=0; i<=31; i=i+1) begin
            data_1_w[i] = data_1_r[i];
            data_2_w[i] = data_2_r[i];
            data_3_w[i] = data_3_r[i];
        end

        case(state_r)
            S_IDLE: begin
                for(i=0; i<=31; i=i+1) begin
                    data_1_w[i] = 0;
                    data_2_w[i] = 0;
                    data_3_w[i] = 0;
                end
            end

            S_CALC: begin
                if( current_data_r[5] ) begin
                    for(i=0; i<=31; i=i+1) begin
                        data_1_w[i] = data_2_r[i];
                        data_2_w[i] = data_3_r[i];
                        data_3_w[i] = 0;
                    end
                end
                else if(pixel_valid) begin
                    data_3_w[current_data_r] = pixel_data;
                end
            end
        endcase
    end

    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n) begin
            for(i=0; i<=31; i=i+1) begin
                data_1_r[i] <= 0;
                data_2_r[i] <= 0;
                data_3_r[i] <= 0;
            end
        end
        else if(data_enable) begin
            for(i=0; i<=31; i=i+1) begin
                data_1_r[i] <= data_1_w[i];
                data_2_r[i] <= data_2_w[i];
                data_3_r[i] <= data_3_w[i];
            end
        end
    end



    // conv-regs
    wire conv_enable;
    assign conv_enable = (state_r==S_CALC && state_w!=S_IDLE) || (state_r==S_CALC && finish_quant);

    integer j;
    always@ (*) begin
        for(j=0; j<=31; j=j+1) begin
            conv_1_w[j] = conv_1_r[j];
            conv_2_w[j] = conv_2_r[j];
        end

        case(state_r)
            S_IDLE: begin
                for(j=0; j<=31; j=j+1) begin
                    conv_1_w[j] = 0;
                    conv_2_w[j] = 0;
                end
            end

            S_CALC: begin
                if( (&current_conv_r && finish_quant) ) begin
                    for(j=0; j<=30; j=j+1) begin
                        conv_1_w[j] = conv_2_r[j];
                        conv_2_w[j] = 0;
                    end
                    conv_1_w[31] = result_quant;
                end
                else if(finish_quant) begin
                    conv_2_w[ current_conv_r ] = result_quant;
                end
            end
        endcase
    end


    always@ (posedge clk_top or negedge rst_n) begin
        if(~rst_n) begin
            for(j=0; j<=31; j=j+1) begin
                conv_1_r[j] <= 0;  
                conv_2_r[j] <= 0;
            end
        end
        else if(conv_enable) begin
            for(j=0; j<=31; j=j+1) begin
                conv_1_r[j] <= conv_1_w[j];
                conv_2_r[j] <= conv_2_w[j];
            end
        end
    end

endmodule




