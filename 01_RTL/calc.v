module conv (
    input clk,
    input rst_n,
    input start,

    input [7:0] data1,
    input [7:0] data2,
    input [7:0] data3,
    input [7:0] data4,
    input [7:0] data5,
    input [7:0] data6,
    input [7:0] data7,
    input [7:0] data8,
    input [7:0] data9,

    input [7:0] param1, 
    input [7:0] param2, 
    input [7:0] param3, 
    input [7:0] param4, 
    input [7:0] param5, 
    input [7:0] param6, 
    input [7:0] param7, 
    input [7:0] param8, 
    input [7:0] param9,

    output [19:0] result,
    output finish
);  
    reg start_1_r, start_2_r, start_3_r, start_4_r, start_5_r;
    reg [19:0] temp1_r, temp2_r, temp3_r, temp4_r, temp5_r, temp6_r, temp7_r, temp8_r, temp9_r;
    wire [19:0] temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8, temp9;
    assign temp1 = $signed({1'd0, data1}) * $signed(param1);
    assign temp2 = $signed({1'd0, data2}) * $signed(param2);
    assign temp3 = $signed({1'd0, data3}) * $signed(param3);
    assign temp4 = $signed({1'd0, data4}) * $signed(param4);
    assign temp5 = $signed({1'd0, data5}) * $signed(param5);
    assign temp6 = $signed({1'd0, data6}) * $signed(param6);
    assign temp7 = $signed({1'd0, data7}) * $signed(param7);
    assign temp8 = $signed({1'd0, data8}) * $signed(param8);
    assign temp9 = $signed({1'd0, data9}) * $signed(param9);


    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            start_1_r <= 0;
            start_2_r <= 0;
            start_3_r <= 0;
            start_4_r <= 0;

            temp1_r <= 0;
            temp2_r <= 0;
            temp3_r <= 0;
            temp4_r <= 0;
            temp5_r <= 0;
            temp6_r <= 0;
            temp7_r <= 0;
            temp8_r <= 0;
            temp9_r <= 0;
        end
        else begin
            start_1_r <= start;
            start_2_r <= start_1_r;
            start_3_r <= start_2_r;
            start_4_r <= start_3_r;
            start_5_r <= start_4_r;

            temp1_r <= temp1;
            temp2_r <= temp2;
            temp3_r <= temp3;
            temp4_r <= temp4;
            temp5_r <= temp5;
            temp6_r <= temp6;
            temp7_r <= temp7;
            temp8_r <= temp8;
            temp9_r <= temp9;
        end
    end

    wire [19:0] add1, add2, add3, add4;
    reg  [19:0] add1_r, add2_r, add3_r, add4_r, add5_r;
    assign add1 = temp1_r + temp2_r;
    assign add2 = temp3_r + temp4_r;
    assign add3 = temp5_r + temp6_r;
    assign add4 = temp7_r + temp8_r;


    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            add1_r <= 0;
            add2_r <= 0;
            add3_r <= 0;
            add4_r <= 0;
            add5_r <= 0;
        end
        else begin 
            add1_r <= add1;
            add2_r <= add2;
            add3_r <= add3;
            add4_r <= add4;
            add5_r <= temp9_r;
        end
    end
    
    wire [19:0] add1_2, add2_2;
    reg [19:0]  add1_2_r, add2_2_r, add3_2_r;

    assign add1_2 = add1_r + add2_r;
    assign add2_2 = add3_r + add4_r;

    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            add1_2_r <= 0;
            add2_2_r <= 0;
            add3_2_r <= 0;
        end
        else begin 
            add1_2_r <= add1_2;
            add2_2_r <= add2_2;
            add3_2_r <= add5_r;
        end
    end

    wire [19:0] add1_3;
    reg  [19:0] add1_3_r, add2_3_r;

    assign add1_3 = add1_2_r + add2_2_r;

    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            add1_3_r <= 0;
            add2_3_r <= 0;
        end
        else begin 
            add1_3_r <= add1_3;
            add2_3_r <= add3_2_r;
        end
    end

    wire [19:0] add1_4;
    reg [19:0] add1_4_r;

    assign add1_4 = add1_3_r + add2_3_r;

    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            add1_4_r <= 0;
        end
        else begin 
            add1_4_r <= add1_4;
        end
    end

    assign result = add1_4_r;
    assign finish = start_5_r;

endmodule


module maxpool(
    input [7:0] data1,
    input [7:0] data2,
    input [7:0] data3,
    input [7:0] data4,
    input [7:0] skipped,

    output [7:0] result,
    output bitmask
);
    wire bigger1_1, bigger1_2, bigger1_3;
    wire bigger2_1, bigger2_2;
    wire bigger3_1;

    assign bigger1_1 = data1 >= data2;
    assign bigger1_2 = data1 >= data3;
    assign bigger1_3 = data1 >= data4;
    assign bigger2_1 = data2 >= data3;
    assign bigger2_2 = data2 >= data4;
    assign bigger3_1 = data3 >= data4;
    
    assign result =     ( &{bigger1_1, bigger1_2, bigger1_3} ) ? data1 : 
                        ( &{bigger2_1, bigger2_2} ) ? data2 : 
                        ( bigger3_1 ) ? data3 : data4;
    assign bitmask = result != skipped;
endmodule


module quantizer(
    input clk,
    input rst_n,
    input start,

    input [19:0] data1,
    input [23:0] bias,
    input [31:0] scale,

    output [7:0] result,
    output finish
);
    reg start_1_r, start_2_r;
    wire [24:0] temp1, temp2;
    wire [56:0] temp3;
    wire [7:0]  temp4;
    reg  [24:0] data1_r;
    reg  [7:0]  data2_r;

    assign temp1 = $signed(data1) + $signed(bias);
    assign temp2 = (temp1[24]) ? 0 : temp1;
    assign temp3 = data1_r * scale;
    assign temp4 = temp3[31] ? (temp3[32 +: 8] + 1'b1) : temp3[32 +: 8];


    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            start_1_r <= 0;
            start_2_r <= 0;
            data1_r <= 0;
            data2_r <= 0;
        end
        else begin
            start_1_r <= start;
            start_2_r <= start_1_r;
            data1_r <= temp2;
            data2_r <= temp4;
        end
    end

    assign result = data2_r;
    assign finish = start_2_r;

endmodule

