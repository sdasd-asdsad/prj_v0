`timescale 1ns / 1ps

module my_pe#(
    parameter L_RAM_SIZE = 8
)(
    // clk/reset
    input aclk,
    input aresetn,
    // port A
    input [31:0] ain,
    // port B
    input [31:0] bin,
    // integrated valid signal
    input valid,
    // computation result
    output dvalid,
    output [31:0] dout
);
    //
    // valid signal must be set as 0 at negedge after the input put on pe.
    // 
    //
    reg [31:0] psum_reg;
    wire [31:0] mac_out;
    wire mac_dvalid; 
    reg _dvalid;
    
    always @(posedge aclk) begin
        if(aresetn == 0) begin
            _dvalid <= 1;
        end
        else if(_dvalid & valid) begin // MAC IDLE
            _dvalid <=  0;
        end
        else if(~_dvalid & mac_dvalid) begin // MAC busy
            _dvalid <= 1;
        end
    end
    
    always @(posedge aclk) begin
        if(aresetn == 0) begin
            psum_reg <= 0;
        end
        else if(mac_dvalid) begin
            psum_reg <= mac_out;
        end
    end
    
    assign dvalid = _dvalid; 
    assign dout[31:0] = psum_reg[31:0];

    // mac module connect
    floating_point_0 MAC (
    .s_axis_a_tdata(ain),
    .s_axis_a_tvalid(valid),
    .s_axis_b_tdata(bin),
    .s_axis_b_tvalid(valid),
    .s_axis_c_tdata(psum_reg),
    .s_axis_c_tvalid(valid),
    .aclk(aclk),
    .aresetn(aresetn),
    .m_axis_result_tdata(mac_out),
    .m_axis_result_tvalid(mac_dvalid)    
    );
endmodule