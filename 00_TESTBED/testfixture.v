`timescale 1ns/1ps                          
`define CYCLE_TOP 2.3                               // Change as you want
`define CYCLE_TB  50                                // Don't touch
`define CYCLE_RAM 0.5                               // Don't touch
`define MAX_CYCLE 20000                             // It can be modified if you need more cycles.
`define SDF_FILE "../02_SYN/Netlist/top_syn.sdf"    // Depends on the name of your SDF file

module test #(
    parameter DATA_WIDTH   = 8             ,
    parameter ADDR_WIDTH   = 15            ,
    parameter M_COUNT      = 1             ,
    parameter STRB_WIDTH   = (DATA_WIDTH/8),
    parameter ID_WIDTH     = 8             
);

// input
reg clk_top;
reg clk_tb ;
reg clk_ram;

reg  rst_n_tb ;
wire rst_n_top;
wire rst_n_ram;

// output
wire finish;

// AXI ports
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_awid   ;
wire [M_COUNT*  ADDR_WIDTH-1:0] m_axi_awaddr ;
wire [M_COUNT           *8-1:0] m_axi_awlen  ;
wire [M_COUNT           *3-1:0] m_axi_awsize ;
wire [M_COUNT           *2-1:0] m_axi_awburst;
wire [M_COUNT             -1:0] m_axi_awlock ;
wire [M_COUNT           *4-1:0] m_axi_awcache;
wire [M_COUNT           *3-1:0] m_axi_awprot ;
wire [M_COUNT             -1:0] m_axi_awvalid;
wire [M_COUNT             -1:0] m_axi_awready;
wire [M_COUNT  *DATA_WIDTH-1:0] m_axi_wdata  ;
wire [M_COUNT  *STRB_WIDTH-1:0] m_axi_wstrb  ;
wire [M_COUNT             -1:0] m_axi_wlast  ;
wire [M_COUNT             -1:0] m_axi_wvalid ;
wire [M_COUNT             -1:0] m_axi_wready ;
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_bid    ;  
wire [M_COUNT           *2-1:0] m_axi_bresp  ;
wire [M_COUNT             -1:0] m_axi_bvalid ;
wire [M_COUNT             -1:0] m_axi_bready ;
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_arid   ;
wire [M_COUNT*  ADDR_WIDTH-1:0] m_axi_araddr ;
wire [M_COUNT           *8-1:0] m_axi_arlen  ;
wire [M_COUNT           *3-1:0] m_axi_arsize ;
wire [M_COUNT           *2-1:0] m_axi_arburst;
wire [M_COUNT             -1:0] m_axi_arlock ;
wire [M_COUNT           *4-1:0] m_axi_arcache;
wire [M_COUNT           *3-1:0] m_axi_arprot ;
wire [M_COUNT             -1:0] m_axi_arvalid;
wire [M_COUNT             -1:0] m_axi_arready;
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_rid    ;  
wire [M_COUNT  *DATA_WIDTH-1:0] m_axi_rdata  ;
wire [M_COUNT           *2-1:0] m_axi_rresp  ;
wire [M_COUNT             -1:0] m_axi_rlast  ;
wire [M_COUNT             -1:0] m_axi_rvalid ;
wire [M_COUNT             -1:0] m_axi_rready ;

axi_ram # (
    .DATA_WIDTH (DATA_WIDTH   ),
    .ADDR_WIDTH (ADDR_WIDTH   )
) axi_ram_inst (
    .clk             (clk_ram        ),
    .rst_n           (rst_n_ram      ),
    .s_axi_awid      (8'b0           ),
    .s_axi_awaddr    (m_axi_awaddr   ),
    .s_axi_awlen     (m_axi_awlen    ),
    .s_axi_awsize    (m_axi_awsize   ),
    .s_axi_awburst   (m_axi_awburst  ),
    .s_axi_awlock    (1'b0           ),
    .s_axi_awcache   (4'b0           ),
    .s_axi_awprot    (3'b0           ),
    .s_axi_awvalid   (m_axi_awvalid  ),
    .s_axi_awready   (m_axi_awready  ),
    .s_axi_wdata     (m_axi_wdata    ),
    .s_axi_wstrb     (m_axi_wstrb    ),
    .s_axi_wlast     (m_axi_wlast    ),
    .s_axi_wvalid    (m_axi_wvalid   ),
    .s_axi_wready    (m_axi_wready   ),
    .s_axi_bid       (m_axi_bid      ),
    .s_axi_bresp     (m_axi_bresp    ),
    .s_axi_bvalid    (m_axi_bvalid   ),
    .s_axi_bready    (m_axi_bready   ),
    .s_axi_arid      (8'b0           ),
    .s_axi_araddr    (m_axi_araddr   ),
    .s_axi_arlen     (m_axi_arlen    ),
    .s_axi_arsize    (m_axi_arsize   ),
    .s_axi_arburst   (m_axi_arburst  ),
    .s_axi_arlock    (1'b0           ),
    .s_axi_arcache   (4'b0           ),
    .s_axi_arprot    (3'b0           ),
    .s_axi_arvalid   (m_axi_arvalid  ),
    .s_axi_arready   (m_axi_arready  ),
    .s_axi_rid       (m_axi_rid      ),
    .s_axi_rdata     (m_axi_rdata    ),
    .s_axi_rresp     (m_axi_rresp    ),
    .s_axi_rlast     (m_axi_rlast    ),
    .s_axi_rvalid    (m_axi_rvalid   ),
    .s_axi_rready    (m_axi_rready   )
);

top # (
    .DATA_WIDTH (DATA_WIDTH   ),
    .ADDR_WIDTH (ADDR_WIDTH   ),
    .STRB_WIDTH (STRB_WIDTH   )
) u_top (
    // Clock and Active-Low Reset
    .clk_top         (clk_top        ),
    .clk_tb          (clk_tb         ),
    .clk_ram         (clk_ram        ),
    .rst_n           (rst_n_top      ),

    // Control Signals
    .finish(finish),

    // AXI port
    .awaddr          (m_axi_awaddr    ),
    .awlen           (m_axi_awlen     ),
    .awsize          (m_axi_awsize    ),
    .awburst         (m_axi_awburst   ),
    .awvalid         (m_axi_awvalid   ),
    .awready         (m_axi_awready   ),
    .wdata           (m_axi_wdata     ),
    .wstrb           (m_axi_wstrb     ),
    .wlast           (m_axi_wlast     ),
    .wvalid          (m_axi_wvalid    ),
    .wready          (m_axi_wready    ),
    .bresp           (m_axi_bresp     ),
    .bvalid          (m_axi_bvalid    ),
    .bready          (m_axi_bready    ),
    .araddr          (m_axi_araddr    ),
    .arlen           (m_axi_arlen     ),
    .arsize          (m_axi_arsize    ),
    .arburst         (m_axi_arburst   ),
    .arvalid         (m_axi_arvalid   ),
    .arready         (m_axi_arready   ),
    .rdata           (m_axi_rdata     ),
    .rresp           (m_axi_rresp     ),
    .rlast           (m_axi_rlast     ),
    .rvalid          (m_axi_rvalid    ),
    .rready          (m_axi_rready    )
);

// Clock and Active-Low Synchronous Reset
initial clk_top = 0;
initial clk_tb  = 0;
initial clk_ram = 0;
always #(`CYCLE_TOP/2.0) clk_top = ~clk_top;
always #(`CYCLE_TB /2.0) clk_tb  = ~clk_tb ;
always #(`CYCLE_RAM/2.0) clk_ram = ~clk_ram;

reset_sync reset_top (
    .i_CLK(clk_top),
    .i_RST_N(rst_n_tb),

    .o_RST_N_SYN(rst_n_top)
);

reset_sync reset_ram (
    .i_CLK(clk_ram),
    .i_RST_N(rst_n_tb),
    
    .o_RST_N_SYN(rst_n_ram)
);

// Initialization
initial begin

    $display("----------------------------------------------\n");
    $display("-             Simulation Starts              -\n");
    $display("----------------------------------------------\n");

    rst_n_tb = 1;

    @(negedge clk_tb);
    rst_n_tb = 0;
    repeat (3) @(negedge clk_tb);
    @(negedge clk_tb);
    rst_n_tb = 1;
    $display("----------------------------------------------\n");
    $display("-              Reset Completes               -\n");
    $display("----------------------------------------------\n");

    `ifdef p0
        $readmemb("../00_TESTBED/test_patterns/p0.dat"       , axi_ram_inst.mem);
        $readmemb("../00_TESTBED/test_patterns/p0_golden.dat", golden);
    `elsif p1
        $readmemb("../00_TESTBED/test_patterns/p1.dat"       , axi_ram_inst.mem);
        $readmemb("../00_TESTBED/test_patterns/p1_golden.dat", golden);
    `elsif p2
        $readmemb("../00_TESTBED/test_patterns/p2.dat"       , axi_ram_inst.mem);
        $readmemb("../00_TESTBED/test_patterns/p2_golden.dat", golden);
    `else
        $readmemb("../00_TESTBED/test_patterns/p2.dat"       , axi_ram_inst.mem);
        $readmemb("../00_TESTBED/test_patterns/p2_golden.dat", golden);
    `endif
end

initial begin
    #(`CYCLE_TB*`MAX_CYCLE);
    $finish;
end

// integer cycles;
// initial begin cycles = 0; end
// always@ (posedge clk_tb)    begin
//     cycles = cycles + 1;
//     $display("current cycle: ", cycles);
// end

initial begin
    `ifdef p0
        $fsdbDumpfile("CONV_p0.fsdb");
    `elsif p1
        $fsdbDumpfile("CONV_p1.fsdb");
    `elsif p2
        $fsdbDumpfile("CONV_p2.fsdb");
    `else
        $fsdbDumpfile("CONV_p2.fsdb");
    `endif
    `ifdef UPF
        $fsdbDumpvars(0, test, "+power");
    `else
        $fsdbDumpvars(0, test, "+mda");
    `endif
end

`ifdef SDF
    initial begin
        $sdf_annotate(`SDF_FILE, u_top);
    end
`endif

// Check final result

reg [DATA_WIDTH-1:0] golden  [0:2303];
integer              error   = 0;
integer              num     = 0;
integer              channel = 0;

initial begin
    
    while (finish !== 1'b1) begin
        
        @(posedge clk_tb);
            
    end 
    @(posedge clk_tb);
    while (finish !== 1'b1) begin
        
        @(posedge clk_tb);
            
    end
    @(posedge clk_tb);
    while (finish !== 1'b1) begin
        
        @(posedge clk_tb);
            
    end
    @(posedge clk_tb);

    while (channel !== 8) begin
        
        while (golden[num + channel * 288] !== 8'bXXXX_XXXX) begin
            if (golden[num + channel * 288] !== axi_ram_inst.mem[1280 + num + channel*288]) begin
                error = error + 1;
                $display("Error in MEM[%d]: Obtained: %b, Golden: %b", 1280 + num + channel * 288, axi_ram_inst.mem[1280 + num + channel*288], golden[num + channel * 288]);
            end
            num = num + 1;
        end
        channel = channel + 1;
        num     = 0;

    end

    if (error === 0) begin
        $display("----------------------------------------------\n");
        $display("-                 ALL PASS!                  -\n");
        $display("----------------------------------------------\n");
    end
    else begin
        $display("----------------------------------------------\n");
        $display("   Fail! Total Error: %d                      \n", error);
        $display("----------------------------------------------\n");
    end

    $finish; 

end


endmodule

module reset_sync(
    input       i_CLK,
    input       i_RST_N,

    output      o_RST_N_SYN
);

reg A1, A2;

assign o_RST_N_SYN = A2;

always@(posedge i_CLK) begin
    if(!i_RST_N) begin
        A1 <= 0;
        A2 <= 0;
    end
    else begin
        A1 <= 1;
        A2 <= A1;
    end 
end

endmodule