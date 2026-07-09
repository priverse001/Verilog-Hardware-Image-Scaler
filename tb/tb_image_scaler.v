`timescale 1ns / 1ps

module tb_image_scaler;

    parameter W_IN      = 3840;
    parameter H_IN      = 2400;
    parameter W_OUT     = 1920;
    parameter H_OUT     = 1200;
    parameter CHANNELS  = 3;    

    reg clk;
    reg rst;
    reg start;
    wire done;
    wire [7:0] debug_state;

    image_scaler #(
        .W_IN(W_IN),
        .H_IN(H_IN),
        .W_OUT(W_OUT),
        .H_OUT(H_OUT),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .debug_state(debug_state)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;


        #100 rst = 0;
        #50;

        start = 1;
        #100 start = 0; 

        wait(done);
        
        #100 $finish;
    end

endmodule
