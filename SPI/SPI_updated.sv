`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineers: Elias Dahl, Gabriel Minton
// Create Date: 10/28/2025 01:09:32 PM 
// Module Name: SPI
//////////////////////////////////////////////////////////////////////////////////

    
module SPI_updated #
     (parameter C_S_AXI_ADDR_WIDTH = 6, C_S_AXI_DATA_WIDTH = 32, SCK_PULSE_MAX = 2)
    (
        // Axi4Lite Bus
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
        // SPI pins
        output logic  SCK,
        output logic  SDI,
        output logic  CONV,
        input  logic  SDO
    );
    
     // Simple Bus Signals
        logic    [C_S_AXI_ADDR_WIDTH-1:0] wrAddr;
        logic    [C_S_AXI_DATA_WIDTH-1:0] wrData;
        logic    wr;
        logic    [C_S_AXI_ADDR_WIDTH-1:0] rdAddr;
        logic    [C_S_AXI_DATA_WIDTH-1:0] rdData;
        logic    rd;
    
    // Instantiate Supporter
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
     


//Internal signals
    logic [1:0] SCK_Pulse_D, SCK_Pulse_Q; // For changing SCK High to Low.
    logic [9:0] Total_Cycles_D, Total_Cycles_Q; // Counts up to Max_Cycles
    logic [4:0] SCK_Cycles_D, SCK_Cycles_Q; // Counts number of SCK cycles, up to the number of bits processed.
    logic [4:0] Num_Bits_D, Num_Bits_Q, //Number of bits to be processed: 16 or 24, written by the manager.
             Data_Index_D, Data_Index_Q; //Index into SDI and SDO data registers.
             
    // Holds the number of clock cycles per sample. Needs to go up to 30,000 for lowest intended sample rate of 1kHz.    
    logic [14:0] Max_Cycles_D, Max_Cycles_Q;      
      
    logic [C_S_AXI_DATA_WIDTH-1:0] SDI_Data_D, SDI_Data_Q, //Data received from the manager to output on SDI
                                    SDO_Data_D, SDO_Data_Q; //Data converted from SDO input.
                                                              
     
            
    //FSM State
    typedef enum logic [1:0] {IDLE, START, LOW_SCK, HIGH_SCK} statetype;
    statetype nextState, currState;
    
    // Sequential Logic
    always_ff @ (posedge S_AXI_ACLK) begin
        if ( ! S_AXI_ARESETN) begin
            currState <= IDLE;
            SCK_Pulse_Q <= 0;
            Total_Cycles_Q <= 0;
            SCK_Cycles_Q <= 0;
            Num_Bits_Q <= 0;
            Max_Cycles_Q <= 0;
            SDI_Data_Q <= 0;
            SDO_Data_Q <= 0;
            Data_Index_Q <= 0;
        end else begin
            currState <= nextState;
            SCK_Pulse_Q <= SCK_Pulse_D;
            Total_Cycles_Q <= Total_Cycles_D;
            SCK_Cycles_Q <= SCK_Cycles_D;
            Num_Bits_Q <= Num_Bits_D;
            Max_Cycles_Q <= Max_Cycles_D;
            SDI_Data_Q <= SDI_Data_D;
            SDO_Data_Q <= SDO_Data_D;
            Data_Index_Q <= Data_Index_D;
        end
    end
    
    // Combinational Logic
    always_comb begin
    // Default Values.
        nextState = currState;
        SCK_Pulse_D = SCK_Pulse_Q;
        SCK_Cycles_D = SCK_Cycles_Q;
        Num_Bits_D = Num_Bits_Q;
        Max_Cycles_D = Max_Cycles_Q;
        SDI_Data_D = SDI_Data_Q;
        SDO_Data_D = SDO_Data_Q;
        Data_Index_D = Data_Index_Q;
        
        // Needs to be incremented every clock cycle.
        Total_Cycles_D = Total_Cycles_Q + 1;
        
        // SDI bit is changed by changing Data_Index in the FSM.
        SDI = SDI_Data_Q[Data_Index_Q];  
        
        CONV = 0;
        SCK = 0;          
        rdData = 0;
        
        
        // FSM
        case(currState)
            IDLE: begin
                CONV = 1;
                
                // Stay in Idle if the SPI hasn't been initialized or the peripheral is still converting.
                if (Num_Bits_Q == 0 || Max_Cycles_Q == 0 || Total_Cycles_Q < Max_Cycles_Q) begin
                    nextState = IDLE;
                end
                
                // Exit IDLE otherwise
                else begin
                    nextState = START;   
                    // Update Data_Index to its inital value so the First SDI bit is valid.
                    Data_Index_D = Num_Bits_Q-1;
                end
            end
            
            // First third of the first low level of SCK.
            // Resets the Total_Cycles and SCK_Cycles counters.
            START: begin
                CONV = 0;
                Total_Cycles_D = 0;
                SCK_Cycles_D = 0;
                SCK_Pulse_D = 1;   
                nextState = LOW_SCK;
            end
            
            LOW_SCK: begin
                SCK = 0;
                // SCK stays LOW for three clock cycles.
                if (SCK_Pulse_Q < SCK_PULSE_MAX) begin
                    nextState = LOW_SCK;
                    SCK_Pulse_D = SCK_Pulse_Q + 1;
                end
                else begin
                    nextState = HIGH_SCK;
                    SCK_Pulse_D = 0;
                end
            end
            
            HIGH_SCK: begin
                SCK = 1;
                //SCK stays high for three clock cycles.
                if (SCK_Pulse_Q < SCK_PULSE_MAX) begin
                    nextState = HIGH_SCK;
                    SCK_Pulse_D = SCK_Pulse_Q + 1;
                end
                
                // If in the last SCK cycle,
                // go back to IDLE after reading SDO.
                else if(SCK_Cycles_Q == Num_Bits_Q - 1) begin
                    nextState = IDLE;
                    // Read SDO
                    SDO_Data_D[Data_Index_Q] = SDO;
                    Data_Index_D = Data_Index_Q - 1;
                end
                
                // Otherwise read SDO and go back to LOW_SCK
                else begin
                    nextState = LOW_SCK;
                    SCK_Pulse_D = 0;
                    SCK_Cycles_D = SCK_Cycles_Q + 1;
                    // Read SDO
                    SDO_Data_D[Data_Index_Q] = SDO;
                    Data_Index_D = Data_Index_Q - 1;
                end
            end
        
            default: begin
                nextState = IDLE;
            end
        endcase
        
// Read & Write Logic    
       if(wr) begin
           case(wrAddr)
           // Write to Num_Bits
               'h0: begin
                    Num_Bits_D = wrData[4:0];
                end
                    
            // Write to Max_Cycles
               'h10: begin
                    Max_Cycles_D = wrData[14:0];
                end
                    
            // Write to SDI Data
               'h4: begin
                    SDI_Data_D = wrData;
                end
                
           // Any other wrAddr is invalid, so do nothing.
               default: begin
               end
           endcase
        end
        
        if (rd) begin
            case(rdAddr)
            // Read from SDO_Data
                'h8: begin
                    rdData = SDO_Data_Q;
                end
                
            // Read CONV for checking if the SPI is Active
                'hc: begin
                    rdData = {{C_S_AXI_DATA_WIDTH-1{1'b0}},CONV};
                end
                
            // Default case, do nothing. 
                default: begin
                end
            endcase
        end     
    end      
        
endmodule
