`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineers: Elias Dahl, Andres Reis.
// Module Name: FIR_Filter
//////////////////////////////////////////////////////////////////////////////////


module FIR_Filter_Updated#( parameter C_S_AXI_DATA_WIDTH = 32, C_S_AXI_ADDR_WIDTH = 9, RAM_DATA_WIDTH = 16, RAM_ADDR_WIDTH = 9, FIR_COPIES = 13, NUM_CHANNELS = 2, NUM_TAPS = 279)
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
    output logic JA_1,
    input logic signed [C_S_AXI_DATA_WIDTH-1:0] attenFactors[0:FIR_COPIES-1] // Uses only 16 bits, could be shortend.
    );
    
    // coeff ram sigs
    logic  [RAM_DATA_WIDTH-1:0] ram_coeff_wdata;
    logic  [RAM_ADDR_WIDTH-1:0] ram_coeff_addr;
    logic  [FIR_COPIES-1:0] wr_coeff; 
    logic signed  [RAM_DATA_WIDTH-1:0] ram_coeff_rdata[0:FIR_COPIES-1] ;
    
    // buffer ram sigs
    logic  [NUM_CHANNELS-1:0]wr_buff;
    logic  [RAM_ADDR_WIDTH-1:0] ram_buff_addr [0:NUM_CHANNELS-1] ;
    logic  [RAM_DATA_WIDTH-1:0] ram_buff_wdata ;
    logic signed [RAM_DATA_WIDTH-1:0] ram_buff_rdata[0:NUM_CHANNELS-1] ;
    
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    wrAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    wrData ;
    logic                               wr ;
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    rdAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    rdData ;
    logic                               rd ;   
    
    logic signed    [C_S_AXI_DATA_WIDTH-1:0] sum_D[0:FIR_COPIES - 1], sum_Q[0:FIR_COPIES - 1];
    logic signed    [C_S_AXI_DATA_WIDTH-1:0] result_D[0:NUM_CHANNELS-1], result_Q[0:NUM_CHANNELS-1];
    
    logic           [RAM_ADDR_WIDTH-1:0] kAddr_D, kAddr_Q;
    logic           [RAM_ADDR_WIDTH-1:0] tapAddr_D, tapAddr_Q;
    logic           [RAM_ADDR_WIDTH-1:0] buffAddr_D, buffAddr_Q;
    
    logic                                channelSelect_D, channelSelect_Q;
    
    logic [C_S_AXI_DATA_WIDTH-1:0] macStatus;
    
    logic macEnable_D, macEnable_Q;
    
    // Used for generates.
    genvar j;
    
    // FSM state
    typedef enum logic [2:0] {IDLE, MAC, ROUND_FIR, ATTENUATE, SUM_AND_ROUND} statetype;
    statetype nextState, currState;
    
    // Sequential Logic
    always_ff @ (posedge S_AXI_ACLK) begin
        if(!S_AXI_ARESETN) begin
            for(int i = 0; i < FIR_COPIES; i++) begin
                sum_Q[i] <= 0;
            end
            for(int i = 0; i < NUM_CHANNELS; i++) begin
                result_Q[i] <= 0;
            end
            kAddr_Q <= 0;
            tapAddr_Q <= 0;
            buffAddr_Q <= 0;
            channelSelect_Q <= 0;
            macEnable_Q <= 0;
            currState <= IDLE;
        end 
          else begin
            for(int i = 0; i < FIR_COPIES; i++) begin
                sum_Q[i] <= sum_D[i];
            end
            for(int i = 0; i < NUM_CHANNELS; i++) begin
                result_Q[i] <= result_D[i];
            end
            currState <= nextState;
            kAddr_Q <= kAddr_D;
            tapAddr_Q <= tapAddr_D;
            buffAddr_Q <= buffAddr_D;
            macEnable_Q <= macEnable_D;
            channelSelect_Q <= channelSelect_D;
          end
    end
    
    always_comb begin
        // default signal values.  
        for(int i = 0; i < FIR_COPIES; i++) begin
            sum_D[i] = sum_Q[i];
        end
        for(int i = 0; i < NUM_CHANNELS; i++) begin
            result_D[i] = result_Q[i];
        end
        kAddr_D = kAddr_Q;
        tapAddr_D = tapAddr_Q;
        buffAddr_D = buffAddr_Q;
        channelSelect_D = channelSelect_Q;
        macEnable_D = macEnable_Q;
        rdData = 0;
        macStatus = 0;
        ram_coeff_wdata = 0;
        wr_coeff = 0;
        ram_buff_wdata = 0;
        wr_buff = 0;
        nextState = currState;
        ram_coeff_addr = 0;
        ram_buff_addr[0] = 0;
        ram_buff_addr[1] = 0;
        JA_1 = 0;
        
        case(currState)
            // Stay in IDLE and do nothing unless a sample
            // is written to the buffer.
            // If a sample is written, intialize the registers
            // used when MACing, and move to MAC.
            IDLE: begin
                if(wr && (wrAddr == 'h34 || wrAddr == 'h38) && macEnable_Q == 1) begin
                    macStatus = 1;
                    kAddr_D = 0;
                    /*
                    * Added the If statement below to solve an off by one error that occurs
                    * when this module is used in the Audio Equalizer.
                    */
                    if(buffAddr_Q == 0) begin
                        tapAddr_D = NUM_TAPS-1;
                    end
                    else begin
                        tapAddr_D = buffAddr_Q-1;
                    end
                    
                    //tapAddr_D = buffAddr_Q;
                    for(int i = 0; i < FIR_COPIES; i++) begin
                        sum_D[i] = 0;
                    end
                    result_D[channelSelect_Q] = 0; //
                    nextState =  MAC;
                end
            end
            
            // Repeatedly MAC until all samples in the buffer
            // have been used, then proceed to ROUND.
            MAC: begin
                macStatus = 1;
                JA_1 = macStatus;
                ram_coeff_addr = kAddr_Q;
                ram_buff_addr[channelSelect_Q] = tapAddr_Q;
                
                for(int i = 0; i < FIR_COPIES; i++) begin
                    sum_D[i] = sum_Q[i] + (ram_coeff_rdata[i]* ram_buff_rdata[channelSelect_Q]);
                end
                
                if(kAddr_Q == NUM_TAPS-1) begin
                    nextState = ROUND_FIR;
                end
                else begin
                    kAddr_D = kAddr_Q + 1;
                    if(tapAddr_Q == 0) begin
                        tapAddr_D = NUM_TAPS-1; //Num taps -1
                    end
                    else begin
                        tapAddr_D = tapAddr_Q - 1;
                    end
                    nextState = MAC;
                end        
            end
            
            // Add half of the LSB and then effectively 
            // arithmetic right shift 15 bits to round the result to Q1.15.
            ROUND_FIR: begin
                macStatus = 1;
                JA_1 = macStatus;
                for(int i = 0; i < FIR_COPIES; i++) begin
                    sum_D[i] = (sum_Q[i] + 'h4000);
                    sum_D[i] = {{16{sum_D[i][30]}},sum_D[i][30:15]}; // result >>> 15
                end


                nextState = ATTENUATE;
            end
            
            /* Multiply each band sum by its corresponding attenuation factor. */
            ATTENUATE: begin
                JA_1 = macStatus;
                for(int i = 0; i < FIR_COPIES; i++) begin
                    sum_D[i] = sum_Q[i]*attenFactors[i];
                end
                nextState = SUM_AND_ROUND;
            end
            
            /* Add the result for each attenuated band */
            SUM_AND_ROUND: begin
                JA_1 = macStatus;
                for(int i = 0; i < FIR_COPIES; i++)begin
                    result_D[channelSelect_Q] = result_D[channelSelect_Q]+sum_Q[i];
                end
                result_D[channelSelect_Q] = result_D[channelSelect_Q] + 'h2000;
                result_D[channelSelect_Q] = {{16{result_D[channelSelect_Q][29]}},result_D[channelSelect_Q][29:14]};
                
                // Update buffAddr after both channels have been filtered.
                if(channelSelect_Q == 1) begin
                    if(buffAddr_Q == NUM_TAPS-1)
                        buffAddr_D = 0;
                    else
                        buffAddr_D = buffAddr_Q + 1;
                end
                
                //Swap channel for next pass.   
                channelSelect_D = (channelSelect_Q == 1) ? 0 : 1; 
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
           // Addresses from 0x0 to 0x30 (0-48)
           for(int i=0;i<FIR_COPIES;i++) begin
                if(wrAddr == (4 * i)) begin
                    ram_coeff_wdata = wrData;
                    ram_coeff_addr = buffAddr_Q;
                    wr_coeff[i] = wr;
                   
                    if(buffAddr_Q == NUM_TAPS-1) begin
                        buffAddr_D = 0;
                    end
                    else begin
                        buffAddr_D = buffAddr_Q + 1;
                    end
               end
           end
           
           // Addresses from 0x34 to 0x38 (52-56)
           for(int i=0; i < NUM_CHANNELS; i++) begin
            if(wrAddr == 4 * FIR_COPIES + 4 * i) begin
                ram_buff_wdata = wrData;
                ram_buff_addr[i] = buffAddr_Q;
                wr_buff[i] = wr ;
            end
           end
           
           /* Used to enable/disable the filter.*/
           if(wrAddr == 'h50) begin
                macEnable_D = wrData[0];   
           end
           
           
        end
        
        
        // RAM read logic
        // Addresses begin at 0x3c (60)
        if (rd) begin
            case(rdAddr)
                // Read left channel result
                'h3c: begin
                    rdData = result_Q[0];
                end
                //Read right channel result
                'h40: begin
                    rdData = result_Q[1];
                end
                // Check if the filter is MACing / not IDLE
                'h44: begin
                    rdData = macStatus;
                end
                // Default case, useful for testing. 
                // This value will be seen if we are reading data but incorrectly using addresses.
                default: begin
                    rdData = 'hdeadbeef;
                end
            endcase
        end     
    end
    
// RAMs for holding the filter coefficients.
generate
    for (j = 0; j < FIR_COPIES; j++) begin
        ram #(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),.RAM_DATA_WIDTH(RAM_DATA_WIDTH)) ram_coeffs (
            .wr(wr_coeff[j]),                      // input
            .DRAM_ACLK(S_AXI_ACLK),             // input
            .DRAM_RESETN(S_AXI_ARESETN),        // input
            .DRAM_ADDR(ram_coeff_addr),         // input
            .DRAM_WDATA(ram_coeff_wdata),       // input
            .DRAM_RDATA(ram_coeff_rdata[j])        // output
            ) ; 
    end 
endgenerate 
    
// RAMs for holding the samples.
generate
    for (j = 0; j < NUM_CHANNELS; j++) begin
ram #(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),.RAM_DATA_WIDTH(RAM_DATA_WIDTH)) ram_buffer (
    .wr(wr_buff[j]),                      // input
    .DRAM_ACLK(S_AXI_ACLK),            // input
    .DRAM_RESETN(S_AXI_ARESETN),       // input
    .DRAM_ADDR(ram_buff_addr[j]),         // input
    .DRAM_WDATA(ram_buff_wdata),       // input
    .DRAM_RDATA(ram_buff_rdata[j])        // output
    ) ;
    end 
endgenerate

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

    
