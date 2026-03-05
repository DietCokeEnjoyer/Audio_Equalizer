`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineers: Elias Dahl, Andres Reis
// Module Name: Audio_EQ
//////////////////////////////////////////////////////////////////////////////////


module Audio_EQ_Final#(parameter C_S_AXI_DATA_WIDTH = 32, C_S_AXI_ADDR_WIDTH = 9, RAM_DATA_WIDTH = 16, RAM_ADDR_WIDTH = 9, FIR_COPIES = 13, NUM_CHANNELS = 2, NUM_TAPS = 279)
(   
    /*Supporter Signals*/
    input  logic  S_AXI_ACLK,
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
    
    /*SPI Signals: 0 -> ADC; 1 -> DAC*/
    output logic  [1:0]SCK,
    output logic  [1:0]SDI,
    output logic  [1:0]CONV,
    input  logic  [1:0]SDO
    );
    
    /*Internal Manager Signals. 0 -> ADC SPI; 1 -> DAC SPI; 2 -> FIR*/
    logic   [C_S_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR [0:2];
    logic   [2:0] M_AXI_AWVALID ;
    logic   [2:0] M_AXI_AWREADY ;
    logic   [C_S_AXI_DATA_WIDTH-1:0] M_AXI_WDATA [0:2] ;
    logic   [3:0] M_AXI_WSTRB [0:2] ;
    logic   [2:0] M_AXI_WVALID ;
    logic   [2:0] M_AXI_WREADY ;
    logic   [C_S_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR [0:2] ;
    logic   [2:0] M_AXI_ARVALID ;
    logic   [2:0] M_AXI_ARREADY ;
    logic   [C_S_AXI_DATA_WIDTH-1:0] M_AXI_RDATA [0:2] ;
    logic   [1:0] M_AXI_RRESP [0:2] ;
    logic   [2:0] M_AXI_RVALID ;
    logic   [2:0] M_AXI_RREADY ;
    logic   [1:0] M_AXI_BRESP [0:2] ;
    logic   [2:0] M_AXI_BVALID ;
    logic   [2:0] M_AXI_BREADY ;
    
    // Manager Simple Busses
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    M_wrAddr [0:2] ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    M_wrData [0:2] ;
    logic                      [2:0]    M_wr ;
    logic                      [2:0]    M_wrDone ;
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    M_rdAddr [0:2] ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    M_rdData [0:2] ;
    logic                      [2:0]    M_rd ;
    logic                      [2:0]    M_rdDone ;
    
    /*Supporter simple bus*/
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    S_wrAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    S_wrData ;
    logic                               S_wr ;
    logic   [C_S_AXI_ADDR_WIDTH-1:0]    S_rdAddr ;
    logic   [C_S_AXI_DATA_WIDTH-1:0]    S_rdData ;
    logic                               S_rd ; 
    
    /*Attenuation Frequnecy Flops*/
    logic signed [C_S_AXI_DATA_WIDTH-1:0] attenFactors_D[0:FIR_COPIES-1]; 
    logic signed [C_S_AXI_DATA_WIDTH-1:0] attenFactors_Q[0:FIR_COPIES-1];
    
    /*EQ Enable*/
    logic EQ_Enable_D, EQ_Enable_Q;
    
    logic channelSelect_D, channelSelect_Q;
    
    logic RWCounter_D, RWCounter_Q;
    
    logic macStatus_D, macStatus_Q;
    
    
    /* Sample Flops */
    logic   [C_S_AXI_DATA_WIDTH-1:0] currSample_D, currSample_Q;
    
    /*FSM States*/
    typedef enum logic [4:0] {INIT_0, INIT_1, INIT_2, INIT_3, IDLE, READ_ADC_0, READ_ADC_1,
							  WRITE_FIR_0, WRITE_FIR_1, READ_FIR_0, READ_FIR_1, WRITE_SPIS_0, WRITE_SPIS_1, WAIT_DAC} statetype; 
    
    statetype nextState, currState;
    
    /*Internal Devices*/
    
    // Axi4Lite Supporter Bus, used for communicating with the Microblaze/ EQ Program.
    Axi4LiteSupporter #(.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)) Supporter_0 (
        // Simple Bus
        .wrAddr(S_wrAddr),                    // output   [C_S_AXI_ADDR_WIDTH-1:0]
        .wrData(S_wrData),                    // output   [C_S_AXI_DATA_WIDTH-1:0]
        .wr(S_wr),                            // output
        .rdAddr(S_rdAddr),                    // output   [C_S_AXI_ADDR_WIDTH-1:0]
        .rdData(S_rdData),                    // input    [C_S_AXI_ADDR_WIDTH-1:0]
        .rd(S_rd),                            // output   
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
        
    FIR_Filter #(.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH), .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)) FIR_0 (
     // Axi4LiteRegs Bus
        .S_AXI_ACLK(S_AXI_ACLK),            // input
        .S_AXI_ARESETN(S_AXI_ARESETN),      // input
        .S_AXI_AWADDR(M_AXI_AWADDR[2]),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
        .S_AXI_AWVALID(M_AXI_AWVALID[2]),      // input
        .S_AXI_AWREADY(M_AXI_AWREADY[2]),      // output
        .S_AXI_WDATA(M_AXI_WDATA[2]),          // input    [C_S_AXI_DATA_WIDTH-1:0]
        .S_AXI_WSTRB(M_AXI_WSTRB[2]),          // input    [3:0]
        .S_AXI_WVALID(M_AXI_WVALID[2]),        // input
        .S_AXI_WREADY(M_AXI_WREADY[2]),        // output        
        .S_AXI_ARADDR(M_AXI_ARADDR[2]),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
        .S_AXI_ARVALID(M_AXI_ARVALID[2]),      // input
        .S_AXI_ARREADY(M_AXI_ARREADY[2]),      // output
        .S_AXI_RDATA(M_AXI_RDATA[2]),          // output   [C_S_AXI_DATA_WIDTH-1:0]
        .S_AXI_RRESP(M_AXI_RRESP[2]),          // output   [1:0]
        .S_AXI_RVALID(M_AXI_RVALID[2]),        // output    
        .S_AXI_RREADY(M_AXI_RREADY[2]),        // input
        .S_AXI_BRESP(M_AXI_BRESP[2]),          // output   [1:0]
        .S_AXI_BVALID(M_AXI_BVALID[2]),        // output
        .S_AXI_BREADY(M_AXI_BREADY[2]),         // input
        .attenFactors(attenFactors_Q),          // input
        .JA_1(macStatus_D)                      // output
    );
    
    genvar j;
    generate
        /* Managers */
        for(j = 0; j < 3; j++) begin
            Axi4LiteManager #(.C_M_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH), .C_M_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)) Manager_
            (
            // Simple Bus
            .wrAddr(M_wrAddr[j]),                    // input    [C_M_AXI_ADDR_WIDTH-1:0]
            .wrData(M_wrData[j]),                    // input    [C_M_AXI_DATA_WIDTH-1:0]
            .wr(M_wr[j]),                            // input    
            .wrDone(M_wrDone[j]),                    // output
            .rdAddr(M_rdAddr[j]),                    // input    [C_M_AXI_ADDR_WIDTH-1:0]
            .rdData(M_rdData[j]),                    // output   [C_M_AXI_DATA_WIDTH-1:0]
            .rd(M_rd[j]),                            // input
            .rdDone(M_rdDone[j]),                    // output
            // Axi4Lite Bus
            .M_AXI_ACLK(S_AXI_ACLK),            // input
            .M_AXI_ARESETN(S_AXI_ARESETN),      // input
            .M_AXI_AWADDR(M_AXI_AWADDR[j]),        // output   [C_M_AXI_ADDR_WIDTH-1:0] 
            .M_AXI_AWVALID(M_AXI_AWVALID[j]),      // output
            .M_AXI_AWREADY(M_AXI_AWREADY[j]),      // input
            .M_AXI_WDATA(M_AXI_WDATA[j]),          // output   [C_M_AXI_DATA_WIDTH-1:0]
            .M_AXI_WSTRB(M_AXI_WSTRB[j]),          // output   [3:0]
            .M_AXI_WVALID(M_AXI_WVALID[j]),        // output
            .M_AXI_WREADY(M_AXI_WREADY[j]),        // input
            .M_AXI_ARADDR(M_AXI_ARADDR[j]),        // output   [C_M_AXI_ADDR_WIDTH-1:0]
            .M_AXI_ARVALID(M_AXI_ARVALID[j]),      // output
            .M_AXI_ARREADY(M_AXI_ARREADY[j]),      // input
            .M_AXI_RDATA(M_AXI_RDATA[j]),          // input    [C_M_AXI_DATA_WIDTH-1:0]
            .M_AXI_RRESP(M_AXI_RRESP[j]),          // input    [1:0]
            .M_AXI_RVALID(M_AXI_RVALID[j]),        // input
            .M_AXI_RREADY(M_AXI_RREADY[j]),        // output
            .M_AXI_BRESP(M_AXI_BRESP[j]),          // input    [1:0]
            .M_AXI_BVALID(M_AXI_BVALID[j]),        // input
            .M_AXI_BREADY(M_AXI_BREADY[j])         // output
            );
        end
        
        /* SPIs */
        for (j = 0; j < 2; j++) begin
            SPI #(.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)) SPI_ (     
             // Axi4LiteRegs Bus
            .S_AXI_ACLK(S_AXI_ACLK),            // input
            .S_AXI_ARESETN(S_AXI_ARESETN),      // input
            .S_AXI_AWADDR(M_AXI_AWADDR[j]),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
            .S_AXI_AWVALID(M_AXI_AWVALID[j]),      // input
            .S_AXI_AWREADY(M_AXI_AWREADY[j]),      // output
            .S_AXI_WDATA(M_AXI_WDATA[j]),          // input    [C_S_AXI_DATA_WIDTH-1:0]
            .S_AXI_WSTRB(M_AXI_WSTRB[j]),          // input    [3:0]
            .S_AXI_WVALID(M_AXI_WVALID[j]),        // input
            .S_AXI_WREADY(M_AXI_WREADY[j]),        // output        
            .S_AXI_ARADDR(M_AXI_ARADDR[j]),        // input    [C_S_AXI_ADDR_WIDTH-1:0]
            .S_AXI_ARVALID(M_AXI_ARVALID[j]),      // input
            .S_AXI_ARREADY(M_AXI_ARREADY[j]),      // output
            .S_AXI_RDATA(M_AXI_RDATA[j]),          // output   [C_S_AXI_DATA_WIDTH-1:0]
            .S_AXI_RRESP(M_AXI_RRESP[j]),          // output   [1:0]
            .S_AXI_RVALID(M_AXI_RVALID[j]),        // output    
            .S_AXI_RREADY(M_AXI_RREADY[j]),        // input
            .S_AXI_BRESP(M_AXI_BRESP[j]),          // output   [1:0]
            .S_AXI_BVALID(M_AXI_BVALID[j]),        // output
            .S_AXI_BREADY(M_AXI_BREADY[j]),         // input
            .SCK(SCK[j]),
            .SDI(SDI[j]),
            .CONV(CONV[j]),
            .SDO(SDO[j])
            );
        end
    endgenerate 
    
        /* Sequential Logic */
    always_ff @ (posedge S_AXI_ACLK) begin
        if(!S_AXI_ARESETN) begin
            currState <= INIT_0;
            currSample_Q <= 0;
            EQ_Enable_Q <= 0;
            channelSelect_Q <= 0;
            RWCounter_Q <= 0;
            macStatus_Q <= 0;
            for(int i = 0; i < FIR_COPIES; i++) begin
                attenFactors_Q[i] <= 0;
            end
        end 
        else begin
            currState <= nextState;
            currSample_Q <= currSample_D;
            EQ_Enable_Q <= EQ_Enable_D;
            channelSelect_Q <= channelSelect_D;
            RWCounter_Q <= RWCounter_D;
            macStatus_Q <= macStatus_D;
            for(int i = 0; i < FIR_COPIES; i++) begin
                attenFactors_Q[i] <= attenFactors_D[i];
            end
        end 
    end 
    
    /* Combinational Logic */
    always_comb begin
        /* Default Values */
        
        // Flops
        nextState = currState;
        currSample_D = currSample_Q;
        EQ_Enable_D = EQ_Enable_Q;
        channelSelect_D = channelSelect_Q;
        RWCounter_D = RWCounter_Q;
        
        for(int i = 0; i < FIR_COPIES; i++) begin 
            attenFactors_D[i] = attenFactors_Q[i];
        end
        
        // Manager Simple Bus
        for (int i = 0; i < 3; i++ )begin
            M_wrAddr[i] = 0;
            M_wrData[i] = 0;
            M_rdAddr[i] = 0;
        end
        
        M_wr = 0;
        M_rd = 0;
        
        // Supp simple bus
        S_rdData = 0;
        
        
        /* FSM */
        case(currState)
            /* When the EQ is enabled, intiates a write of the number of bits used to both SPIS. */
            INIT_0: begin
                if(EQ_Enable_Q == 1) begin
                    
                    //Write to SPIs                   
                    M_wrAddr[0] = 'h0; //Addr of num bits
                    M_wrAddr[1] = 'h0; //Addr of num bits

                    M_wrData[0] = 'd16; //Bits used by ADC SPI
                    M_wrData[1] = 'd24; //Bits used by DAC SPI
                    
                    M_wr[0] = 1;
                    M_wr[1] = 1;
                    
                    if(RWCounter_Q == 0) begin
                        RWCounter_D = 1;
                        nextState = INIT_0;
                    end
                    else begin
                        RWCounter_D = 0;
                        nextState = INIT_1;
                    end
                end
            end
            
            /* Waits for the SPI writes to complete */
            INIT_1: begin
                if(M_wrDone[0] == 1 && M_wrDone[1] == 1) begin
                    nextState = INIT_2;
                end
                else begin
                    nextState = INIT_1;
                end
            end
            
            /* Initiates a write for the number of cycles used by both SPIS, and enables the FIR filter.*/
            INIT_2: begin  
                //Write to SPIs
                
                M_wrAddr[0] = 'h10; //Addr of num cycles
                M_wrAddr[1] = 'h10; //Addr of num cycles
                M_wrAddr[2] = 'h50; // FIR Enable
                
                M_wrData[0] = 'd300; // SPI Cycles
                M_wrData[1] = 'd300; // SPI Cycles
                M_wrData[2] = 1;
                
                M_wr[0] = 1;
                M_wr[1] = 1;
                M_wr[2] = 1;
                
                if(RWCounter_Q == 0) begin
                    RWCounter_D = 1;
                    nextState = INIT_2;
                end
                else begin
                    RWCounter_D = 0;
                    nextState = INIT_3;
                end

            end
            
            /* Wait for the writes to complete. */
            INIT_3: begin
                if(M_wrDone[0] == 1 && M_wrDone[1] == 1) begin
                    nextState = IDLE;
                end
                else begin
                    nextState = INIT_3;
                end
            end
            
            /* Waits for the last DAC cycle to complete before starting the next loop.*/
            IDLE: begin
                if(CONV[1] == 1) begin
                    nextState = READ_ADC_0;
                end
                else begin
                    nextState = IDLE;
                end
            end
            
            /* Initiates a read of the ADC output */
            READ_ADC_0: begin
                M_rdAddr[0] = 'h8; // ADC output data
                M_rd[0] = 1;
                
                if(RWCounter_Q == 0) begin
                    RWCounter_D = 1;
                    nextState = READ_ADC_0;
                end
                else begin
                    RWCounter_D = 0;
                    nextState = READ_ADC_1;
                end
            end
            
            /* Waits for the ADC read to complete, and puts the sample into currSample. */
            READ_ADC_1: begin
                if(M_rdDone[0] == 1) begin
                    currSample_D = {'0,~(M_rdData[0][15]),M_rdData[0][14:0]}; // Unsigned -> Signed by flip "MSB"
                    nextState = WRITE_FIR_0;
                end
                else begin
                    nextState = READ_ADC_1;
                end
            end
            
            /* Writes a sample to the FIR filter.*/
            WRITE_FIR_0: begin
                if(channelSelect_Q == 0) begin
                    M_wrAddr[2] = 'h38; // R channel
                end
                else begin
                    M_wrAddr[2] = 'h34; // L channel
                end
                            
                M_wrData[2] = currSample_Q;
                M_wr[2] = 1;
                
                if(RWCounter_Q == 0) begin
                    RWCounter_D = 1;
                    nextState = WRITE_FIR_0;
                end
                else begin
                    RWCounter_D = 0;
                    nextState = WRITE_FIR_1;
                end
            end
            
            WRITE_FIR_1: begin
              if(M_wrDone[2] == 1) begin
                    nextState = READ_FIR_0;
                end
                else begin
                    nextState = WRITE_FIR_1;
                end
            end
            

            // Reads the previous FIR result
            READ_FIR_0: begin
                if(channelSelect_Q == 0) begin
                    M_rdAddr[2] = 'h40; // R channel
                end
                else begin
                    M_rdAddr[2] = 'h3c; // L channel
                end
                
                
                M_rd[2] = 1;
                
                if(RWCounter_Q == 0) begin
                    RWCounter_D = 1;
                    nextState = READ_FIR_0;
                end
                else begin
                    RWCounter_D = 0;
                    nextState = READ_FIR_1;
                end
                
            end
            
            // Waits for the FIR read to compete.
            // Puts the FIR output in currSample when read completes.
            READ_FIR_1: begin
                
                if(M_rdDone[2] == 1) begin
                    currSample_D = {'0,~(M_rdData[2][15]),M_rdData[2][14:0]}; // signed -> Unsigned by flip "MSB"
                    nextState = WRITE_SPIS_0;
                end
                else begin
                    nextState = READ_FIR_1;
                end
            end    
            
            /* Initates a write of the current sample to the DAC, and the SDI address data for the next ADC cycle. */
            WRITE_SPIS_0: begin
                // Only address bits are different. 
                if(channelSelect_Q == 0) begin
                    M_wrData[1] = {'0,4'b0011,4'b0000,currSample_Q[15:0]}; // L channel
                    M_wrData[0] = 'hc000; // ch1 to be processed next next?
                end
                else begin
                    M_wrData[1] = {'0,4'b0011,4'b0001,currSample_Q[15:0]}; // R channel
                    M_wrData[0] = 'h8000; // ch0 to be processed next next?
                end
                
                M_wrAddr[1] = 'h4; // SDI
                M_wr[1] = 1;
                
                M_wrAddr[0] = 'h4; // ADC SDI
                M_wr[0] = 1;
                
                if(RWCounter_Q == 0) begin
                    RWCounter_D = 1;
                    nextState = WRITE_SPIS_0;
                end
                else begin
                    RWCounter_D = 0;
                    channelSelect_D = (channelSelect_Q == 1) ? 0 : 1; //Swap channel for next pass.
                    nextState = WRITE_SPIS_1;
                end
                
            end
            
            /* Waits for the writes to complete */
            WRITE_SPIS_1: begin
                if(M_wrDone[1] == 1 && M_wrDone[0]) begin
                    nextState = WAIT_DAC;
                end
                else begin
                    nextState = WRITE_SPIS_1;
                end
            end
            
            /* Waits for the DAC SPI CONV to go low so IDLE can wait for it to go high. */
            WAIT_DAC: begin
                if(CONV[1] == 1) begin
                    nextState = WAIT_DAC;
                end
                else begin
                nextState = IDLE;
                end
            end

            default: begin
                nextState = INIT_0;
            end
        endcase
        
       if(S_wr) begin
           /* Writes to the FIR coefficient buffers */
           /* Addresses from 0x0 to 0x30 */
           for(int i=0;i<FIR_COPIES;i++) begin
                if(S_wrAddr == (4 * i)) begin
                    M_wrData[2] = S_wrData;
                    M_wrAddr[2] = S_wrAddr;
                    M_wr[2] = S_wr;
               end
           end
           
            /*Writes to the FIR sample buffers, used for initializing them to 0.*/
            /* 0x34-0x38 */
            for(int i=0; i < NUM_CHANNELS; i++) begin
                if(S_wrAddr == 'h34 + 4 * i) begin
                    M_wrData[2] = S_wrData;
                    M_wrAddr[2] = S_wrAddr;
                    M_wr[2] = S_wr;
                end
            end
            
            /* Used to start the equalizer */
            if(S_wrAddr == 'h3c) begin
                EQ_Enable_D = S_wrData[0];   
            end
            
            /* Used to write to the attenuation factor flops. */
            /* 0x40 - 0x70 */
            for(int i = 0; i < FIR_COPIES; i++) begin
                if(S_wrAddr == 'h40 + 4*i) begin
                    attenFactors_D[i] = {'0,S_wrData[15:0]};
                end
            end 
       end
    end
endmodule
