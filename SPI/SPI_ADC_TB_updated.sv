`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineers: Elias Dahl, Gabriel Minton
// Create Date: 10/30/2025 03:34:05 PM
// Module Name: SPI_ADC_TB
//////////////////////////////////////////////////////////////////////////////////


module SPI_ADC_TB_updated();
parameter C_S_AXI_DATA_WIDTH = 32, C_S_AXI_ADDR_WIDTH = 6, CLK_PERIOD = 33.33;
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

//SPI Signals
logic  SCK;
logic  SDI;
logic  CONV;
logic  SDO;

SPI_updated #(.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)) SPI_1 (     
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
        .SCK(SCK),
        .SDI(SDI),
        .CONV(CONV),
        .SDO(SDO)
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
        
    AdcTester AdcTester1 (
    .SCK(SCK),
    .SDI(SDI),
    .CS_(CONV),
    .SDO(SDO)
    );

    parameter CLK_PERIOD_2 = (CLK_PERIOD)/2;
    // Generate Clock
    always begin
        #(CLK_PERIOD_2) S_AXI_ACLK = ~S_AXI_ACLK;
    end
    
    // create memory arrays
    logic [C_S_AXI_DATA_WIDTH-1:0] outputL [0:999];
    logic [C_S_AXI_DATA_WIDTH-1:0] outputR [0:999];
    int i;
    logic r_CONV;

    initial begin
        // Initialize
        S_AXI_ARESETN = 0;
        S_AXI_ACLK = 0;
        wr = 0;
        wrAddr = 0;
        wrData = 0;
        rd = 0;
        rdAddr = 0;
        r_CONV = 0;
        
        //Generate Reset
        #(CLK_PERIOD_2 + 2) S_AXI_ARESETN = 1;
        #(CLK_PERIOD*10); 
        
        // Addr of Num_Bits
        wrAddr = 'h0;
        wrData = 'd16;
        wr = 1;
        #(CLK_PERIOD*2);    
        wr = 0;
        while(!wrDone) begin
            #(CLK_PERIOD);
        end 
        
        // Addr of Max_Cycles
        wrAddr = 'h10;
        wrData = 'd600; // 25kHz sample rate.
        wr = 1;
        #(CLK_PERIOD*2);    
        wr = 0;
        while(!wrDone) begin
            #(CLK_PERIOD);
        end 
        
            
        rdAddr = 'hc;
        rd = 1;
        #(CLK_PERIOD*2);
        rd = 0;      
        while(!rdDone)begin
            #(CLK_PERIOD);
        end
        
        //Wait for SPI cycle to discard first value.
        r_CONV = rdData[0];
        
        while(r_CONV == 1)begin
            rd = 1;
            #(CLK_PERIOD*2);
            rd = 0;        
            while(!rdDone)begin
                #(CLK_PERIOD);
            end
            r_CONV = rdData[0];
        end
        
        while(r_CONV == 0)begin
            rd = 1;
            #(CLK_PERIOD*2);
            rd = 0;        
            while(!rdDone)begin
                #(CLK_PERIOD);
            end
            r_CONV = rdData[0];
        end
        
        for(i = 0; i < 2000; i++) begin
            // Write SDI
            wrAddr ='h4;
            if(i%2 == 0) begin
                wrData = 'h8000; // single ended, channel 0;
                
            end
            else begin
                wrData = 'hc000; // single ended, channel 1;
            end
            
            wr = 1;
            #(CLK_PERIOD*2);    
            wr = 0;
            
            while(!wrDone) begin
                #(CLK_PERIOD);
            end
            
            //Wait for SPI to be inactive before reading next sample.
            rdAddr = 'hc;
            while(r_CONV == 1)begin
                rd = 1;
                #(CLK_PERIOD*2);
                rd = 0;        
                while(!rdDone)begin
                    #(CLK_PERIOD);
                end
                r_CONV = rdData[0];
             end
        
            while(r_CONV == 0)begin
                rd = 1;
                #(CLK_PERIOD*2);
                rd = 0;        
                while(!rdDone)begin
                    #(CLK_PERIOD);
                end
                r_CONV = rdData[0];
            end
            
            // Read SDO
            rdAddr = 'h8;
            rd = 1;
            #(CLK_PERIOD*2);
            rd = 0;
            while(!rdDone) begin
                #(CLK_PERIOD);
            end
            
            if(i%2 == 1) begin
                outputL[i/2] = rdData; // single ended, channel 0;            
            end
            else begin
                outputR[i/2] = rdData; // single ended, channel 1;
            end   
        end
        
        $display("Output L: \n");
        for(i=0; i<1000; i++) begin
            $display("%h \n",(outputL[i]));  
        end
        $display("Output R: \n");
        for(i=0; i<1000; i++) begin
            $display("%h \n",(outputR[i]));  
        end
        $stop;
    end
endmodule
