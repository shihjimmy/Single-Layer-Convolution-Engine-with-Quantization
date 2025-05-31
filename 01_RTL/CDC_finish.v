module CDC_finish(
    input clk_A,
    input clk_B,
    input rst,
    input finish,
    output finish_CDC,
    output handshake
);
    // For Pulse Synchronizer
    reg  pulse_clkB_r;
    wire pulse_clkB_w;
    reg  pulse_clkA1_r, pulse_clkA2_r, pulse_clkA3_r;
    assign pulse_clkB_w = pulse_clkB_r ^ finish;
    assign finish_CDC = pulse_clkA3_r ^ pulse_clkA2_r;
    
    always@ (posedge clk_B or posedge rst) begin
        if(rst) pulse_clkB_r  <= 0;
        else    pulse_clkB_r  <= pulse_clkB_w;
    end

    always@ (posedge clk_A or posedge rst) begin
        if(rst) begin
            pulse_clkA1_r <= 0;
            pulse_clkA2_r <= 0;
            pulse_clkA3_r <= 0;
        end
        else begin
            pulse_clkA1_r <= pulse_clkB_r;
            pulse_clkA2_r <= pulse_clkA1_r;
            pulse_clkA3_r <= pulse_clkA2_r;
        end
    end

    // Another 2FF for sending handshake data back to clk B
    reg finish_clkB1_r, finish_clkB2_r;
    assign handshake = finish_clkB2_r;
    
    always@ (posedge clk_B or posedge rst) begin
        if(rst) begin
            finish_clkB1_r <= 0;
            finish_clkB2_r <= 0;
        end
        else begin
            finish_clkB1_r <= finish_CDC;
            finish_clkB2_r <= finish_clkB1_r;
        end
    end
endmodule
