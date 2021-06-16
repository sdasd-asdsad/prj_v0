`timescale 1ns / 1ps


module pe_controller#(
    parameter L_RAM_SIZE = 8, // must be power of 2
    parameter BITWIDTH = 32,
    parameter waitValue = 32'h00000000, // -INF in IEEE-754 form
    parameter waitRdaddr = 32'hffffffff
)(
    input start,
    input reset,
    input clk,
    output [BITWIDTH-1:0] rdaddr,
    input[BITWIDTH-1:0] rddata,
    output [BITWIDTH*L_RAM_SIZE*L_RAM_SIZE-1:0] out,
    output done
);

reg _reset;
// gb[buffer#][element]
reg [BITWIDTH-1:0] gb1[L_RAM_SIZE-1:0][L_RAM_SIZE-1:0];
reg [BITWIDTH-1:0] gb2[L_RAM_SIZE-1:0][L_RAM_SIZE-1:0];
reg [BITWIDTH-1:0] _rdaddr;


wire input_reset;
wire [BITWIDTH-1:0] dout[L_RAM_SIZE-1:0][L_RAM_SIZE-1:0];
wire [L_RAM_SIZE*L_RAM_SIZE-1:0] dvalid;
reg valid;
reg [BITWIDTH-1:0] ain[L_RAM_SIZE-1:0];
reg [BITWIDTH-1:0] bin[L_RAM_SIZE-1:0];

reg [1:0] state;
reg [1:0] next_state;

reg [7:0] idx;
reg [7:0] idx_dvalid;

reg [1:0] timer1;
reg [1:0] timer2;
reg [2:0] timer3;
reg state_init;
reg wait_dvalid;
reg _done;

genvar r,c;

integer i;

//assign rdaddr = _rdaddr;
assign rdaddr = {24'b0,idx};
assign input_reset = reset | _reset;
assign done = _done;

always @(posedge clk) begin
    if(reset) begin
        state <= 2'b00;
        valid <= 0;
        state_init = 0;
        _rdaddr <= 32'hffffffff;
        next_state = 0;
        idx = 0;
        idx_dvalid = 0;
        wait_dvalid = 0;
        timer2 = 0;
        timer3 = 0;
        _done <= 0;
    end
    else begin
        if(state != next_state) begin
            state = next_state;
            state_init = 0;
            _rdaddr <= 32'hffffffff;
        end
    end
    if(state==2'b00) begin
        if(state_init==0) begin
            _reset = 1;
            state_init = 1;
        end
        if(start==1) begin
            next_state = 2'b01;
            state_init = 0;
        end
    end
    else if(state==2'b01) begin
        if(state_init==0) begin 
            _reset = 0;
            idx = 0;
            state_init=1;
        end
        _rdaddr <= idx;
        if(start==1) begin    
            if(idx < L_RAM_SIZE*L_RAM_SIZE) gb1[idx/L_RAM_SIZE][idx&(L_RAM_SIZE-1)] <= rddata;
            else gb2[(idx-L_RAM_SIZE*L_RAM_SIZE)/L_RAM_SIZE][(idx-L_RAM_SIZE*L_RAM_SIZE)&(L_RAM_SIZE-1)] <= rddata; 
            idx = idx + 1;
            if(idx==2*L_RAM_SIZE*L_RAM_SIZE) begin
                next_state = 2'b11;
                state_init = 0;
            end
        end   
    end
    else if(state==2'b11) begin
        if(state_init == 0) begin
            idx_dvalid = 0;
            wait_dvalid = 0;
            state_init = 1;
            timer2 = 0;        
         end
         if(timer2==0 && state_init==1 && idx_dvalid != L_RAM_SIZE) begin
            if(~wait_dvalid) begin
                // NOT CONFIGURABLE BLCOK
                //A
                for(i=0;i<L_RAM_SIZE;i=i+1) begin
                    ain[i] <= gb1[i][idx_dvalid];
                end
                /*
                ain[0] <= gb1[0][idx_dvalid];
                ain[1] <= gb1[1][idx_dvalid];
                ain[2] <= gb1[2][idx_dvalid];
                ain[3] <= gb1[3][idx_dvalid];
                ain[4] <= gb1[4][idx_dvalid];
                ain[5] <= gb1[5][idx_dvalid];
                ain[6] <= gb1[6][idx_dvalid];
                ain[7] <= gb1[7][idx_dvalid];*/
                //B
                for(i=0;i<L_RAM_SIZE;i=i+1) begin
                    bin[i] <= gb2[i][idx_dvalid];
                end
                /*
                bin[0] <= gb2[0][idx_dvalid];
                bin[1] <= gb2[1][idx_dvalid];
                bin[2] <= gb2[2][idx_dvalid];
                bin[3] <= gb2[3][idx_dvalid];
                bin[4] <= gb2[4][idx_dvalid];
                bin[5] <= gb2[5][idx_dvalid];
                bin[6] <= gb2[6][idx_dvalid];
                bin[7] <= gb2[7][idx_dvalid];*/
                valid <= 1;
                timer2 = 2;
            end
            else if(wait_dvalid==1 && (&dvalid)==1) begin
                wait_dvalid <= 0;
                idx_dvalid = idx_dvalid+1;
                if(idx_dvalid==L_RAM_SIZE) begin
                    next_state = 2'b10;
                    state_init = 0;
                end 
            end
        end
        else if(timer2!=0 && state_init==1) begin
            timer2 = timer2 - 1;  
            valid <= 0;          
            wait_dvalid=1;
        end
    end
    else if(state==2'b10) begin
        if(state_init==0) begin
            state_init = 1;
            _done <= 1; 
        end
        else begin
            if(start) begin
                state_init = 0;
                next_state = 2'b00;
                _done <= 0; 
            end
        end
    end
end


// next state

generate
    for(r=0;r<L_RAM_SIZE;r=r+1) begin
        for(c=0;c<L_RAM_SIZE;c=c+1) begin
            assign out[(r*L_RAM_SIZE+c+1)*BITWIDTH-1:(r*L_RAM_SIZE+c)*BITWIDTH] = dout[r][c];
        end
    end
endgenerate

// output
generate
    for(r=0;r<L_RAM_SIZE;r=r+1) begin
        for(c=0;c<L_RAM_SIZE;c=c+1) begin
            my_pe PE(
                // clk/reset
                .aclk(clk),
                .aresetn(~input_reset),
                // port A
                .ain(ain[r]),
                // port B
                .bin(bin[c]),
                // integrated valid signal
                .valid(valid),
                // computation result
                .dvalid(dvalid[r*L_RAM_SIZE+c]),
                .dout(dout[r][c])            
            );
        end
    end
endgenerate

/*
my_pe PE (
    // clk/reset
    .aclk(clk),
    .aresetn(~input_reset),
    // port A
    .ain(ain),
    // port B
    .bin(bin),
    // integrated valid signal
    .valid(valid),
    // computation result
    .dvalid(dvalid),
    .dout(dout)
);*/

endmodule
