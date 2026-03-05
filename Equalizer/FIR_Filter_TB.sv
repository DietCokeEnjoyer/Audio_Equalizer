`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Elias Dahl, Andres Reis
// 
// Create Date: 10/02/2025 01:30:37 PM
// Design Name: 
// Module Name: FIR_Filter_TB
// Project Name: 
// Target Devices: 
// Description: 
// 
// Dependencies: 
// 
//////////////////////////////////////////////////////////////////////////////////


module FIR_Filter_TB();
parameter C_S_AXI_DATA_WIDTH = 32, C_S_AXI_ADDR_WIDTH = 9, CLK_PERIOD = 33.33, RAM_DATA_WIDTH = 16, RAM_ADDR_WIDTH = 9, NUM_TAPS = 279, NUM_SAMPLES = 1000, FIR_COPIES = 13;
// Axi4Lite signals
logic   S_AXI_ACLK ;
logic   S_AXI_ARESETN ;
logic   [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR ;
logic   S_AXI_AWVALID ;
logic   S_AXI_AWREADY ;
logic   [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA ;
logic   [3:0] S_AXI_WSTRB ;
logic   S_AXI_WVALID ;
logic   S_AXI_WREADY ;
logic   [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR ;
logic   S_AXI_ARVALID ;
logic   S_AXI_ARREADY ;
logic   [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA ;
logic   [1:0] S_AXI_RRESP ;
logic   S_AXI_RVALID ;
logic   S_AXI_RREADY ;
logic   [1:0] S_AXI_BRESP ;
logic   S_AXI_BVALID ;
logic   S_AXI_BREADY ;

// Manager simple Bus signals
logic   [C_S_AXI_ADDR_WIDTH-1:0]    wrAddr ;
logic   [C_S_AXI_DATA_WIDTH-1:0]    wrData ;
logic                               wr ;
logic                               wrDone ;
logic   [C_S_AXI_ADDR_WIDTH-1:0]    rdAddr ;
logic   [C_S_AXI_DATA_WIDTH-1:0]    rdData ;
logic                               rd ;
logic                               rdDone ;

// Data arrays
logic signed [RAM_DATA_WIDTH-1:0]   coeffs[NUM_TAPS-1:0][FIR_COPIES-1:0];
logic signed [RAM_DATA_WIDTH-1:0]   sin_L[NUM_SAMPLES-1:0];
logic signed [RAM_DATA_WIDTH-1:0]   sin_R[NUM_SAMPLES-1:0];

logic signed [RAM_DATA_WIDTH-1:0]   result_L[NUM_SAMPLES-1:0];
logic signed [RAM_DATA_WIDTH-1:0]   result_R[NUM_SAMPLES-1:0];

// Simulation Variables
logic macStatus; // Taken from LSB of rdData when reading from macStatus FIR filter signal.
int i;
int j;

logic signed [C_S_AXI_DATA_WIDTH-1:0] attenFactors_TB [0:FIR_COPIES-1];

//DUTs
FIR_Filter #(.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),  
             .RAM_DATA_WIDTH(RAM_DATA_WIDTH),.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)) FIR_Filter1 (     
         // Axi4LiteRegs Bus
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
        .S_AXI_BREADY(S_AXI_BREADY),         // input
        .attenFactors(attenFactors_TB)
);
Axi4LiteManager #(.C_M_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH), .C_M_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)) Axi4LiteManager1
        (
        // Simple Bus
        .wrAddr(wrAddr),                    // input    [C_M_AXI_ADDR_WIDTH-1:0]
        .wrData(wrData),                    // input    [C_M_AXI_DATA_WIDTH-1:0]
        .wr(wr),                            // input    
        .wrDone(wrDone),                    // output
        .rdAddr(rdAddr),                    // input    [C_M_AXI_ADDR_WIDTH-1:0]
        .rdData(rdData),                    // output   [C_M_AXI_DATA_WIDTH-1:0]
        .rd(rd),                            // input
        .rdDone(rdDone),                    // output
        // Axi4Lite Bus
        .M_AXI_ACLK(S_AXI_ACLK),            // input
        .M_AXI_ARESETN(S_AXI_ARESETN),      // input
        .M_AXI_AWADDR(S_AXI_AWADDR),        // output   [C_M_AXI_ADDR_WIDTH-1:0] 
        .M_AXI_AWVALID(S_AXI_AWVALID),      // output
        .M_AXI_AWREADY(S_AXI_AWREADY),      // input
        .M_AXI_WDATA(S_AXI_WDATA),          // output   [C_M_AXI_DATA_WIDTH-1:0]
        .M_AXI_WSTRB(S_AXI_WSTRB),          // output   [3:0]
        .M_AXI_WVALID(S_AXI_WVALID),        // output
        .M_AXI_WREADY(S_AXI_WREADY),        // input
        .M_AXI_ARADDR(S_AXI_ARADDR),        // output   [C_M_AXI_ADDR_WIDTH-1:0]
        .M_AXI_ARVALID(S_AXI_ARVALID),      // output
        .M_AXI_ARREADY(S_AXI_ARREADY),      // input
        .M_AXI_RDATA(S_AXI_RDATA),          // input    [C_M_AXI_DATA_WIDTH-1:0]
        .M_AXI_RRESP(S_AXI_RRESP),          // input    [1:0]
        .M_AXI_RVALID(S_AXI_RVALID),        // input
        .M_AXI_RREADY(S_AXI_RREADY),        // output
        .M_AXI_BRESP(S_AXI_BRESP),          // input    [1:0]
        .M_AXI_BVALID(S_AXI_BVALID),        // input
        .M_AXI_BREADY(S_AXI_BREADY)         // output
        );
        
    parameter CLK_PERIOD_2 = (CLK_PERIOD)/2;
    // Generate Clock
    always begin
        #(CLK_PERIOD_2) S_AXI_ACLK = ~S_AXI_ACLK;
    end
    
    initial begin
        // Initialize
        S_AXI_ARESETN = 0;
        S_AXI_ACLK = 0;
        wr = 0;
        wrAddr = 0;
        wrData = 0;
        rd = 0;
        rdAddr = 0;
        
        // Read filter coefficents and sine waves into arrays.
        $readmemh("Sin_1318_Hex.txt", sin_L);
        $readmemh("Sin_1734_Hex.txt", sin_R);
        $readmemh("Coeffs_Hex.mem", coeffs); 
        $readmemb("attenFactors_2_14.mem", attenFactors_TB);
        
        //Generate Reset
        #(CLK_PERIOD_2 + 2) S_AXI_ARESETN = 1;
        #(CLK_PERIOD*10);
        
               
        // Fill coeff buffer
        for(j = 0; j < FIR_COPIES; j++) begin
            wrAddr = 4 * j; //Address of coeff RAM
            for(i = NUM_TAPS - 1; i >= 0; i--)begin
            
                if(j < 2) begin
                    wrData = 0;
                    wrAddr = 'h34 + 4*j; //Address of buffer RAM
                    wr = 1;
                    #(CLK_PERIOD*2);
                    wr = 0;
                    while(!wrDone) begin
                        #(CLK_PERIOD);
                    end
                    wrAddr = 4 * j; //Address of coeff RAM
                end
                
                wrData = coeffs[i][j];       
                wr = 1;
                #(CLK_PERIOD*2);
                wr = 0;
                while(!wrDone) begin
                    #(CLK_PERIOD);
                end
            end
        end
        
        #(CLK_PERIOD*10);
        
        //Enable FIR
        wrAddr = 'h50;
        wrData = 1;
        wr = 1;
        #(CLK_PERIOD*2);
        wr = 0;
        while(!wrDone) begin
            #(CLK_PERIOD);
        end
        
        
        
        for(i = 0; i < NUM_SAMPLES; i++) begin
            for(int c = 0; c < 2; c++) begin
                if(c == 0) begin
                    wrAddr = 'h34; // Left channel
                    wrData = sin_L[i];
                end
                else begin
                    wrAddr = 'h38; // Right channel
                    wrData = sin_R[i];
                end
                
                wr = 1;
                #(CLK_PERIOD*2);
                wr = 0;
                
                while(!wrDone) begin
                    #(CLK_PERIOD*1);
                end
                
                // Read macStatus
                rdAddr='h44; // Mac flag
                rd = 1;
                #(CLK_PERIOD*2);
                rd = 0;
                while(!rdDone) begin
                    #(CLK_PERIOD*1);
                end 
                macStatus = rdData[0];
                
                // keep reading macStatus until the MAC is complete
                while(macStatus)begin
                    rd = 1;
                    #(CLK_PERIOD*2);
                    rd = 0;
                    while(!rdDone) begin
                        #(CLK_PERIOD*1);
                    end 
                    macStatus = rdData[0];
                end
                
                //Result Address
                if(c == 0)
                    rdAddr = 'h3c;
                else
                    rdAddr = 'h40;

                rd = 1;
                #(CLK_PERIOD*2);
                rd = 0;
                
                while(!rdDone) begin
                    #(CLK_PERIOD*1);
                end
                
                if(c == 0)
                    result_L[i] = rdData;
                else
                    result_R[i] = rdData;

            end
        end
        
        $display("Left Channel results: \n");
        for(i = 0; i < NUM_SAMPLES; i++) begin
            $display("%d \n", result_L[i]);
        end
        
        $display("Right Channel results: \n");
        for(i = 0; i < NUM_SAMPLES; i++) begin
            $display("%d \n", result_R[i]);
        end
        $stop;
    end  
endmodule
