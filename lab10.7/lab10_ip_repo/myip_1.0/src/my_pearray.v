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
    

	clk_wiz_0 u_clk_180 (.clk_out1(BRAM_CLK), .clk_in1(S_AXI_ACLK));

    // regs, wires
    reg input_valid;
    reg [1:0] load_state;
    wire [31:0] rdaddr;
    wire _done;
    
    reg BRAM_CHECKER;
    
    genvar i;
    wire [31:0] out_mem[63:0];
    wire [8*8*32-1:0] out;
    

    // FSM : IDLE => LOAD => CALC => DONE
    reg [2:0] pe_state;
    reg [7:0] counter;
    wire [7:0] load_idx;
    reg [7:0] old_idx;
    localparam PE_IDLE = 2'd0;
    localparam PE_LOAD = 2'd1;
    localparam PE_CALC = 2'd2;
    localparam PE_WRITE = 2'd3;

    assign BRAM_ADDR = {22'd0,counter,2'd0};
    assign BRAM_WRDATA = out_mem[counter];
    assign BRAM_WE = (pe_state==PE_WRITE)? 4'hF : 4'h0;
    assign load_idx = rdaddr[7:0];
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
                PE_LOAD : pe_state <= (counter==8'd129)? PE_CALC : PE_LOAD;
                PE_CALC : pe_state <= (_done)? PE_WRITE : PE_CALC;
                PE_WRITE : begin
                                pe_state <= (counter==8'd63)? PE_IDLE : PE_WRITE;
                                done <= (counter==8'd63)? 1 : done;
                           end
                default : pe_state <= PE_IDLE;
            endcase
        end
    end

    // STATES OP
    always @(posedge S_AXI_ACLK) begin
        if(pe_state == PE_IDLE) begin
            // reset op
            load_state <= 2'd0;
            input_valid <= 1'b0;
            old_idx <= -1;
            counter = 0;
        end
        else if(pe_state == PE_LOAD) begin   // 3 cycles to load 1 element
            if(BRAM_CHECKER) begin
                if(load_state == 2'd0) begin
                    load_state <= 2'd1;
                    input_valid <= 1'b0;
                    counter = rdaddr[7:0];
                end
                else if(load_state == 2'd1) begin
                    load_state <= 2'd2;
                    input_valid <= 1'b0;
                end
                else if(load_state == 2'd2) begin
                    load_state <= 2'd0;
                    input_valid <= 1'b1;
                end
            end
            else begin
            end
        end
        else if(pe_state == PE_CALC) begin
            counter = 8'h0;
            load_state <= 2'b0;
            input_valid <= 1'b0;
        end
        else if(pe_state == PE_WRITE) begin
            counter = counter + 1;
            input_valid <= (counter==8'd63)? 1'b1 : 1'b0;
        end
    end
    
    always @(posedge BRAM_CLK) begin
        if(pe_state == PE_LOAD) begin
            BRAM_CHECKER <= 1;
        end
        else begin
            BRAM_CHECKER <= 0;
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
