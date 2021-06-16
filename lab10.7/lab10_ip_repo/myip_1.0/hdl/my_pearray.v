`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/12 01:01:19
// Design Name: 
// Module Name: my_pearray
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module my_pearray(
    //from axi
    input wire start,
    output reg done,
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,

    //to BRAM
    output wire [31:0] BRAM_ADDR,
    output wire [31:0] BRAM_WRDATA,
    output wire [3:0] BRAM_WE,
    output wire BRAM_CLK,
    input wire [31:0] BRAM_RDDATA
    );
    


    // regs, wires
    reg input_valid;
    reg [1:0] load_state;
    reg [3:0] _BRAM_WE;
    wire [31:0] rdaddr;
    wire _done;
    
    genvar i;
    wire [31:0] out_mem[63:0];
    wire [8*8*32-1:0] out;
    

    // FSM : IDLE => LOAD => CALC => DONE
    reg [2:0] pe_state;
    reg [7:0] counter;
    localparam PE_IDLE = 2'd0;
    localparam PE_LOAD = 2'd1;
    localparam PE_CALC = 2'd2;
    localparam PE_WRITE = 2'd3;

    assign BRAM_ADDR = {22'd0,counter,2'd0};
    assign BRAM_WRDATA = out_mem[counter];
    assign BRAM_WE = (pe_state==PE_WRITE)? 4'hF : 4'h0;

    // STATE TRANS
    always @(posedge S_AXI_ACLK) begin
        if(S_AXI_ARESETN == 1'b0) begin
            // reset op
            pe_state <= PE_IDLE;
            done <= 0;
        end
        else begin
            case (pe_state)
                PE_IDLE : begin
                                pe_state <= (start)? PE_LOAD : PE_IDLE;
                                done <= 0;
                          end
                PE_LOAD : pe_state <= (counter==8'd128)? PE_CALC : PE_LOAD;
                PE_CALC : pe_state <= (_done)? PE_WRITE : PE_CALC;
                PE_WRITE : begin
                                pe_state <= (counter==8'd64)? PE_IDLE : PE_WRITE;
                                done <= (counter==8'd64)? 1 : done;
                           end
                default : pe_state <= PE_IDLE;
            endcase
        end
    end

    // STATES OP
    always @(posedge S_AXI_ACLK) begin
        if(pe_state == PE_IDLE) begin
            // reset op
            counter = 8'd0;
            load_state <= 2'd0;
            input_valid <= 1'b0;
        end
        else if(pe_state == PE_LOAD) begin   // 3 cycles to load 1 element
            if(load_state == 2'd0) load_state <= load_state+1; 
            else if(load_state == 2'd1) begin
                load_state <= load_state+1;
                input_valid <= 1'b1;
            end 
            else if(load_state == 2'd2) begin
                load_state <= 2'b0;
                input_valid <= 1'b0;
                counter = counter + 1;
            end
        end
        else if(pe_state == PE_CALC) begin
            counter = 8'hFF;
            load_state <= 2'b0;
            input_valid <= 1'b0;
        end
        else if(pe_state == PE_WRITE) begin
            counter = counter + 1;
            input_valid <= (counter==8'd64)? 1'b1 : 1'b0;
        end
    end

    generate
        for(i=0;i<64; i=i+1) begin
            assign out_mem[i] = out[(i+1)*32-1:(i)*32];
        end
    endgenerate

    pe_controller PE_CTRL(
    .start(start || input_valid),
    .reset(~S_AXI_ARESETN),
    .clk(S_AXI_ACLK),
    .rdaddr(rdaddr),
    .rddata(BRAM_RDDATA),
    .out(out),
    .done(_done)
    );   

endmodule
