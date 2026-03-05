`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineers: Elias Dahl, Amelia Hines
// Module Name: FIR_Filter
//////////////////////////////////////////////////////////////////////////////////


module FIR_Filter#( parameter C_S_AXI_DATA_WIDTH = 32, C_S_AXI_ADDR_WIDTH = 6, RAM_DATA_WIDTH = 16, RAM_ADDR_WIDTH = 6)
(   input  logic  S_AXI_ACLK,
    input  logic  S_AXI_ARESETN,
    input  logic  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic  S_AXI_AWVALID,
    output logic  S_AXI_AWREADY,
    input  logic  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  logic  [3:0] S_AXI_WSTRB,
    input  logic  S_AXI_WVALID,
    output logic  S_AXI_WREADY,
    input  logic  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic  S_AXI_ARVALID,
    output logic  S_AXI_ARREADY,
    output logic  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic  [1:0] S_AXI_RRESP,
    output logic  S_AXI_RVALID,
    input  logic  S_AXI_RREADY,
    output logic  [1:0] S_AXI_BRESP,
    output logic  S_AXI_BVALID,
    input  logic  S_AXI_BREADY, 
    output logic JA_1
    );
    
    logic  [RAM_DATA_WIDTH-1:0] ram_coeff_wdata ;
    logic  [RAM_ADDR_WIDTH-1:0] ram_coeff_addr ;
    logic  [RAM_DATA_WIDTH-1:0] wr_coeff ; 
    logic signed  [RAM_DATA_WIDTH-1:0] ram_coeff_rdata ;
    // buffer ram sigs
    logic  wr_buff ;
    logic  [RAM_ADDR_WIDTH-1:0] ram_buff_addr ;
    logic  [RAM_DATA_WIDTH-1:0] ram_buff_wdata ;
    logic signed [RAM_DATA_WIDTH-1:0] ram_buff_rdata ;
    
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    wrAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    wrData ;
    logic                               wr ;
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    rdAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    rdData ;
    logic                               rd ;   
    
    logic signed    [C_S_AXI_DATA_WIDTH-1:0] sum_D, sum_Q ;
    logic signed    [C_S_AXI_DATA_WIDTH-1:0] result_D, result_Q ;
    
    logic           [RAM_ADDR_WIDTH-1:0] kAddr_D, kAddr_Q ;
    logic           [RAM_ADDR_WIDTH-1:0] tapAddr_D, tapAddr_Q ;
    logic           [RAM_ADDR_WIDTH-1:0] buffAddr_D, buffAddr_Q ;
    
    logic [C_S_AXI_DATA_WIDTH-1:0] macStatus;
    
    // FSM state
    typedef enum logic [1:0] {IDLE, MAC, ROUND} statetype;
    statetype nextState, currState;
    
    // Sequential Logic
    always_ff @ (posedge S_AXI_ACLK) begin
        if(!S_AXI_ARESETN) begin
            sum_Q <= 0;
            result_Q <= 0;
            kAddr_Q <= 0;
            tapAddr_Q <= 0;
            buffAddr_Q <= 0;
            currState <= IDLE;
        end 
          else begin
            currState <= nextState;
            sum_Q <= sum_D;
            result_Q <= result_D;
            kAddr_Q <= kAddr_D;
            tapAddr_Q <= tapAddr_D;
            buffAddr_Q <= buffAddr_D;
          end
    end
    
    always_comb begin
        // default signal values.
        sum_D = sum_Q;
        result_D = result_Q;
        kAddr_D = kAddr_Q;
        tapAddr_D = tapAddr_Q;
        buffAddr_D = buffAddr_Q;
        rdData = 0;
        macStatus = 0;
        ram_coeff_wdata = 0;
        wr_coeff = 0;
        ram_buff_wdata = 0;
        wr_buff = 0;
        nextState = currState;
        ram_coeff_addr = 0;
        ram_buff_addr = 0;
        JA_1 = 0;
        
        case(currState)
            // Stay in IDLE and do nothing unless a sample
            // is written to the buffer.
            // If a sample is written, intialize the registers
            // used when MACing, and move to MAC.
            IDLE: begin
                if(wr && wrAddr == 'h4) begin
                    macStatus = 'd1;
                    kAddr_D = 0;
                    tapAddr_D = buffAddr_Q;
                    sum_D = 0;
                    result_D = 0;
                    nextState =  MAC;
                end
            end
            // Repeatedly MAC until all samples in the buffer
            // have been used, then proceed to ROUND.
            MAC: begin
                macStatus = 1;
                JA_1 = macStatus;
                ram_coeff_addr = kAddr_Q;
                ram_buff_addr = tapAddr_Q;
                sum_D = sum_Q + (ram_coeff_rdata* ram_buff_rdata);
                if(kAddr_Q == 60) begin
                    nextState = ROUND;
                end
                else begin
                    kAddr_D = kAddr_Q + 1;
                    if(tapAddr_Q == 0) begin
                        tapAddr_D = 60; //Num taps -1
                    end
                    else begin
                        tapAddr_D = tapAddr_Q - 1;
                    end
                    nextState = MAC;
                end        
            end
            // Add half of the LSB and then effectively 
            // arithmetic right shift 15 bits to round the result to Q1.15.
            ROUND: begin
                macStatus = 1;
                JA_1 = macStatus;
                result_D = (sum_Q + 'h4000);
                result_D = {{16{result_D[30]}},result_D[30:15]}; // result >>> 15
                
                if(buffAddr_Q == 60) begin
                    buffAddr_D = 0;
                end
                else begin
                    buffAddr_D = buffAddr_Q + 1;
                end
                nextState = IDLE;
            end
            default: begin
                nextState = IDLE;
            end
        endcase     
        
      // RAM write logic
       if(wr) begin
           // Where data is written to is handled by the filter.
           // The RAMs are acting as circular buffers, with each new write 
           // going to the next spot in the buffer, eventually looping around 
           // and overwriting old values.
           case(wrAddr)
               // Write to coeff RAM. 
               'h0: begin
                    ram_coeff_wdata = wrData;
                    ram_coeff_addr = buffAddr_Q;
                    wr_coeff = wr ;
                   
                    if(buffAddr_Q == 'd60) begin
                        buffAddr_D = 0;
                    end
                    else begin
                        buffAddr_D = buffAddr_Q + 1;
                    end
               end
               // Write to buffer RAM. This starts a MAC cycle.
               // buffAddr is manipulated by the ROUND State.
               'h4: begin
                    ram_buff_wdata = wrData;
                    ram_buff_addr = buffAddr_Q;
                    wr_buff = wr ;
                end
               // Any other wrAddr is invalid, so do nothing.
               default: begin
               end
           endcase
        end
        
        // RAM read logic
        if (rd) begin
            case(rdAddr)
                // Read from result register
                'h8: begin
                    rdData = result_Q;
                end
                // Check if the filter is MACing / not IDLE
                'hc: begin
                    rdData = macStatus;
                end
                // Default case, useful for testing. 
                // This value will be seen if we are reading data but incorrectly using addresses.
                default: begin
                    rdData = 'hF;
                end
            endcase
        end     
    end
    // RAM for holding the FIR Filter coefficients.
ram #(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),.RAM_DATA_WIDTH(RAM_DATA_WIDTH)) ram_coeffs (
    .wr(wr_coeff),                      // input
    .DRAM_ACLK(S_AXI_ACLK),             // input
    .DRAM_RESETN(S_AXI_ARESETN),        // input
    .DRAM_ADDR(ram_coeff_addr),         // input
    .DRAM_WDATA(ram_coeff_wdata),       // input
    .DRAM_RDATA(ram_coeff_rdata)        // output
    ) ;
    // RAM for holding sample values.
ram #(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),.RAM_DATA_WIDTH(RAM_DATA_WIDTH)) ram_buffer (
    .wr(wr_buff),                      // input
    .DRAM_ACLK(S_AXI_ACLK),            // input
    .DRAM_RESETN(S_AXI_ARESETN),       // input
    .DRAM_ADDR(ram_buff_addr),         // input
    .DRAM_WDATA(ram_buff_wdata),       // input
    .DRAM_RDATA(ram_buff_rdata)        // output
    ) ;
// Axi4Lite Supporter Bus, used for reading and writing data to the Filter RAM and registers.
Axi4LiteSupporter #(.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)) Axi4LiteSupporter1 (
    // Simple Bus
    .wrAddr(wrAddr),                    // output   [C_S_AXI_ADDR_WIDTH-1:0]
    .wrData(wrData),                    // output   [C_S_AXI_DATA_WIDTH-1:0]
    .wr(wr),                            // output
    .rdAddr(rdAddr),                    // output   [C_S_AXI_ADDR_WIDTH-1:0]
    .rdData(rdData),                    // input    [C_S_AXI_ADDR_WIDTH-1:0]
    .rd(rd),                            // output   
    // Axi4Lite Bus
    .S_AXI_ACLK(S_AXI_ACLK),            // input
    .S_AXI_ARESETN(S_AXI_ARESETN),      // input
    .S_AXI_AWADDR(S_AXI_AWADDR),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
    .S_AXI_AWVALID(S_AXI_AWVALID),      // input
    .S_AXI_AWREADY(S_AXI_AWREADY),      // output
    .S_AXI_WDATA(S_AXI_WDATA),          // input    [C_S_AXI_DATA_WIDTH-1:0]
    .S_AXI_WSTRB(S_AXI_WSTRB),          // input    [3:0]
    .S_AXI_WVALID(S_AXI_WVALID),        // input
    .S_AXI_WREADY(S_AXI_WREADY),        // output        
    .S_AXI_ARADDR(S_AXI_ARADDR),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
    .S_AXI_ARVALID(S_AXI_ARVALID),      // input
    .S_AXI_ARREADY(S_AXI_ARREADY),      // output
    .S_AXI_RDATA(S_AXI_RDATA),          // output   [C_S_AXI_DATA_WIDTH-1:0]
    .S_AXI_RRESP(S_AXI_RRESP),          // output   [1:0]
    .S_AXI_RVALID(S_AXI_RVALID),        // output    
    .S_AXI_RREADY(S_AXI_RREADY),        // input
    .S_AXI_BRESP(S_AXI_BRESP),          // output   [1:0]
    .S_AXI_BVALID(S_AXI_BVALID),        // output
    .S_AXI_BREADY(S_AXI_BREADY)         // input
    ) ;

endmodule

    
