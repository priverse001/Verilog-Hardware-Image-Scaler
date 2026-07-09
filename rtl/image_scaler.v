`timescale 1ns / 1ps

module image_scaler #(
    parameter W_IN      = 3840,
    parameter H_IN      = 2400,
    parameter W_OUT     = 1920,
    parameter H_OUT     = 1200,
    parameter CHANNELS  = 3,     
    parameter FRAC_BITS = 8      
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done,
    output reg [7:0] debug_state
);

    localparam IDLE           = 0;
    localparam CALC_COORDS    = 1;
    localparam FETCH_DATA     = 2;
    localparam INTERP_X       = 3;
    localparam INTERP_Y       = 4;
    localparam WRITE_PIXEL    = 5;
    localparam DUMP_FILE      = 6;

    reg [7:0] input_mem  [0:(W_IN * H_IN * CHANNELS - 1)];
    reg [7:0] output_mem [0:(W_OUT * H_OUT * CHANNELS - 1)];

    integer f, i;

    reg [2:0] state;
    reg [15:0] x_out, y_out;
    reg [1:0]  ch;

    reg [31:0] x_in_fixed, y_in_fixed;
    
    reg [15:0] x0, y0;
    reg [15:0] x1, y1;
    reg [7:0]  a, b;

    reg [7:0] I00, I10, I01, I11;

    reg signed [17:0] interp_top;
    reg signed [17:0] interp_bottom;
    reg signed [17:0] result;

    wire [31:0] scale_x = (W_IN << 8) / W_OUT;
    wire [31:0] scale_y = (H_IN << 8) / H_OUT;

    initial begin
        
        $readmemh("input_image.hex", input_mem);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;
            x_out <= 0;
            y_out <= 0;
            ch    <= 0;
            debug_state <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        x_out <= 0;
                        y_out <= 0;
                        ch    <= 0;
                        state <= CALC_COORDS;
                    end
                end

                CALC_COORDS: begin
                    debug_state <= 1;
                    x_in_fixed <= x_out * scale_x;
                    y_in_fixed <= y_out * scale_y;
                    state <= FETCH_DATA;
                end

                FETCH_DATA: begin
                    debug_state <= 2;
                    x0 <= x_in_fixed[31:8];
                    y0 <= y_in_fixed[31:8];
                    a  <= x_in_fixed[7:0];
                    b  <= y_in_fixed[7:0];

                    x1 <= (x0 + 1 < W_IN) ? x0 + 1 : x0;
                    y1 <= (y0 + 1 < H_IN) ? y0 + 1 : y0;

                    I00 <= input_mem[(y0 * W_IN + x0) * CHANNELS + ch];
                    I10 <= input_mem[(y0 * W_IN + x1) * CHANNELS + ch];
                    I01 <= input_mem[(y1 * W_IN + x0) * CHANNELS + ch];
                    I11 <= input_mem[(y1 * W_IN + x1) * CHANNELS + ch];

                    state <= INTERP_X;
                end

                INTERP_X: begin
                    debug_state <= 3;
                    interp_top    <= $signed({1'b0, I00}) + (($signed({1'b0, a}) * ($signed({1'b0, I10}) - $signed({1'b0, I00}))) >>> 8);
                    interp_bottom <= $signed({1'b0, I01}) + (($signed({1'b0, a}) * ($signed({1'b0, I11}) - $signed({1'b0, I01}))) >>> 8);
                    state <= INTERP_Y;
                end

                INTERP_Y: begin
                    debug_state <= 4;
                    result <= interp_top + (($signed({1'b0, b}) * (interp_bottom - interp_top)) >>> 8);
                    state <= WRITE_PIXEL;
                end

                WRITE_PIXEL: begin
                    debug_state <= 5;
                    
                    if (result < 0)
                        output_mem[(y_out * W_OUT + x_out) * CHANNELS + ch] <= 0;
                    else if (result > 255)
                        output_mem[(y_out * W_OUT + x_out) * CHANNELS + ch] <= 255;
                    else
                        output_mem[(y_out * W_OUT + x_out) * CHANNELS + ch] <= result[7:0];

                    if (ch < CHANNELS - 1) begin
                        ch <= ch + 1;
                        state <= FETCH_DATA;
                    end else begin
                        ch <= 0;
                        if (x_out < W_OUT - 1) begin
                            x_out <= x_out + 1;
                            state <= CALC_COORDS;
                        end else begin
                            x_out <= 0;
                            if (y_out < H_OUT - 1) begin
                                y_out <= y_out + 1;
                                state <= CALC_COORDS;
                            end else begin
                                state <= DUMP_FILE;
                            end
                        end
                    end
                end

                DUMP_FILE: begin
                    debug_state <= 6;
                    f = $fopen("output_image.hex", "w");
                    if (f) begin
                        for (i = 0; i < W_OUT * H_OUT * CHANNELS; i = i + 1) begin
                            $fdisplay(f, "%h", output_mem[i]);
                        end
                        $fclose(f);
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
