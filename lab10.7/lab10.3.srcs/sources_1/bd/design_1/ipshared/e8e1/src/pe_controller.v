`timescale 1ns / 1ps


module pe_controller#(
    parameter L_RAM_SIZE = 8, // must be power of 2
    parameter BITWIDTH = 32
)(
    input start,
    input RESETN,
    input CLK,
    output done,
    
    output BRAM_CLK,
    output [BITWIDTH-1:0] BRAM_ADDR,
    output [BITWIDTH-1:0] BRAM_WRDATA,
    input [BITWIDTH-1:0] BRAM_RDDATA,
    output [3:0] BRAM_WE
);

//wire [BITWIDTH*L_RAM_SIZE*L_RAM_SIZE-1:0] out;
wire [L_RAM_SIZE*L_RAM_SIZE-1:0] dvalid;
reg valid;
reg [BITWIDTH-1:0] ele;
(* ram_style = "distributed" *) reg [BITWIDTH-1:0] ain[L_RAM_SIZE-1:0];
(* ram_style = "distributed" *) reg [BITWIDTH-1:0] bin[L_RAM_SIZE-1:0];
(* ram_style = "distributed" *) reg [BITWIDTH-1:0] gb1[L_RAM_SIZE*L_RAM_SIZE-1:0];
(* ram_style = "distributed" *) reg [BITWIDTH-1:0] gb2[L_RAM_SIZE*L_RAM_SIZE-1:0];
reg [3:0] bram_we;
wire eff_reset;

reg _done;
assign done = _done;



// FSM
reg [2:0] state;
reg BRAM_CHECKER;
localparam PE_IDLE = 3'd0;
localparam PE_LOAD = 3'd1;
localparam PE_CALC = 3'd2;
localparam PE_DONE = 3'd3;

//
wire [7:0] rdaddr;
reg [7:0] rdaddr_load;
reg [7:0] rdaddr_done;
assign rdaddr = (state==PE_LOAD)? rdaddr_load : rdaddr_done;

reg [BITWIDTH-1:0] bram_wrdata;
reg [21:0]c_22_z;
reg [1:0]c_2_z;

assign BRAM_ADDR = {c_22_z,rdaddr,c_2_z};
assign BRAM_WE = bram_we;
assign BRAM_WRDATA = bram_wrdata;

// load vars
reg load_flag;
reg load_init;
reg load_done;


// calcs vars
reg [3:0] idx;
reg [1:0] calc_stage;
reg calc_done;

// done vars
reg done_init;
reg done_done;
reg [3:0]done_stage;
reg done_resetn;
wire [BITWIDTH-1:0] mem[L_RAM_SIZE*L_RAM_SIZE-1:0];
/*
wire [7:0] t1;
wire [7:0] t2;
wire [7:0] t3;
assign t1 = ((rdaddr-1))>>3;
assign t2 = (rdaddr-1) & 8'h7;
assign t3 = (((rdaddr-1)^L_RAM_SIZE*L_RAM_SIZE));*/

// state trans
always @(posedge CLK) begin
    if(~RESETN) begin
        state <= PE_IDLE;
        c_22_z <= 22'd0;
        c_2_z <= 2'd0;
    end
    else begin
        case(state)
            PE_IDLE : state <= (start)? PE_LOAD:PE_IDLE;
            PE_LOAD : state <= (load_done)? PE_CALC:PE_LOAD;
            PE_CALC : state <= (calc_done)? PE_DONE:PE_CALC;
            PE_DONE : state <= (done_done)? PE_IDLE:PE_DONE;
            default : state <= PE_IDLE;
        endcase
    end
end


// state PE_IDLE 
/*always @(posedge CLK) begin
    // state
    if(state==PE_IDLE) begin
    end
    else begin
        //initialization here
    end
end*/

wire [7:0] gb1_idx;
assign gb1_idx = (rdaddr_load);

wire [7:0] gb2_idx;
assign gb2_idx = (((rdaddr_load)^(L_RAM_SIZE*L_RAM_SIZE)));

// state PE_LOAD
always @(posedge CLK) begin
    // state
    if(state==PE_LOAD) begin
        if(load_flag==0) begin
            rdaddr_load = (load_init)? (rdaddr_load+1):0;
            load_flag <= 1;
            if(load_init & (~load_done)) begin
                //if(rdaddr_load < L_RAM_SIZE*L_RAM_SIZE+1) gb1[gb1_idx] = BRAM_RDDATA;
                if(rdaddr_load < L_RAM_SIZE*L_RAM_SIZE+1) begin
                    gb1[gb1_idx] = BRAM_RDDATA;
                    gb2[0] = BRAM_RDDATA;
                end
                else gb2[gb2_idx] = BRAM_RDDATA;
            end
        end
        else begin
            load_init <= 1;
            load_flag <= 0;
            if(rdaddr==2*L_RAM_SIZE*L_RAM_SIZE+1) load_done <= 1;
        end
    end
    else begin
        //initialization here
        load_init <= 0;
        load_flag <= 0;
        load_done <= 0;
        rdaddr_load = 0;
    end
end

// state PE_CALC
always @(posedge CLK) begin
    // state
    if(state==PE_CALC) begin
        if(calc_stage==0) begin
            if(~calc_done)  begin
                ain[0] <= gb1[idx];
                ain[1] <= gb1[L_RAM_SIZE+idx];
                ain[2] <= gb1[2*L_RAM_SIZE+idx];
                ain[3] <= gb1[3*L_RAM_SIZE+idx];
                ain[4] <= gb1[4*L_RAM_SIZE+idx];
                ain[5] <= gb1[5*L_RAM_SIZE+idx];
                ain[6] <= gb1[6*L_RAM_SIZE+idx];
                ain[7] <= gb1[7*L_RAM_SIZE+idx];
                bin[0] <= gb2[idx];
                bin[1] <= gb2[1*L_RAM_SIZE+idx];
                bin[2] <= gb2[2*L_RAM_SIZE+idx];
                bin[3] <= gb2[3*L_RAM_SIZE+idx];
                bin[4] <= gb2[4*L_RAM_SIZE+idx];
                bin[5] <= gb2[5*L_RAM_SIZE+idx];
                bin[6] <= gb2[6*L_RAM_SIZE+idx];
                bin[7] <= gb2[7*L_RAM_SIZE+idx];  
                valid <= 1;      
                calc_stage <= 1;            // my_pe가 valid를 0 번 받은 상태
            end
        end
        else if(calc_stage==1) begin    // my_pe가 valid를 1 번 받은 상태
            calc_stage <= 2;
        end
        else if(calc_stage==2) begin    // my_pe가 valid를 2 번 받은 상태
            calc_stage <= 3;
            valid <= 0;
            idx <= idx+1;
        end
        else if(calc_stage==3) begin
            if(&dvalid) begin // 계산 완료
                if(idx==L_RAM_SIZE) begin
                    calc_done <= 1;
                end
                calc_stage <= 0;
            end
        end
    end
    else begin
        //initialization here
        idx <= 0;
        calc_stage <= 0;
        calc_done <= 0;
    end
end

// state PE_DONE
always @(posedge CLK) begin
    // state
    if(state==PE_DONE) begin
        if(~done_init) begin
            done_init <= 1;
            bram_we <= 4'hF;
        end
        else begin
            if (done_done) begin
            end
            else if(done_stage==4'd0) begin
                done_stage <= done_stage + 1;
                bram_wrdata = mem[rdaddr_done];//mem[rdaddr];
            end
            else if(done_stage==4'd1) begin
                rdaddr_done = rdaddr_done+1;
                //if(rdaddr_done==L_RAM_SIZE*L_RAM_SIZE) begin
                if(rdaddr_done==L_RAM_SIZE*L_RAM_SIZE) begin
                    bram_we <= 4'h0;
                    done_stage <= done_stage + 1;
                    _done <= 1;
                end
                else bram_wrdata = mem[rdaddr_done];
            end
            else if(done_stage<4'd6) begin
                done_stage <= done_stage + 1;
            end
            else if(done_stage==4'd6) begin
                done_done <= 1;
                _done <= 0;
                done_resetn <= 0;
            end
        end
    end
    else begin
        //initialization here
        done_init <= 0;
        done_done <= 0;
        done_stage <= 0;
        done_resetn <= 1;
        _done <= 0;
        bram_we <= 4'h0;
        rdaddr_done = 0;
    end
end

// output
genvar i,r,c;

assign eff_reset = RESETN&done_resetn;
generate
    for(r=0;r<L_RAM_SIZE;r=r+1) begin
        for(c=0;c<L_RAM_SIZE;c=c+1) begin
            my_pe PE(
                // clk/reset
                .aclk(CLK),
                .aresetn(eff_reset),
                // port A
                .ain(ain[r]),
                // port B
                .bin(bin[c]),
                // integrated valid signal
                .valid(valid),
                // computation result
                .dvalid(dvalid[r*L_RAM_SIZE+c]),
                .dout(mem[r*L_RAM_SIZE+c])
                //.dout(out[(r*L_RAM_SIZE+c+1)*BITWIDTH-1:(r*L_RAM_SIZE+c)*BITWIDTH])
            );
        end
    end
endgenerate

endmodule