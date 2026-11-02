
`timescale 1ns / 1ps

module mux_4_1(
    input [23:0] I0, I1, I2, I3,
    input [1:0] sel,
    output [23:0] out
);

    reg [23:0] out_reg;

    always @(*) begin
        case(sel)
            2'b00: out_reg = I0;
            2'b01: out_reg = I1;
            2'b10: out_reg = I2;
            2'b11: out_reg = I3;
            default: out_reg = I0;
        endcase
    end

    assign out = out_reg;

endmodule


module D_FF #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] D,
    input wire clk,
    input wire clr,
    output reg [WIDTH-1:0] Q
);

    always @(posedge clk) begin
        if (clr)
            Q <= {WIDTH{1'b0}};
        else
            Q <= D;
    end

endmodule


module gray_scale(
    input wire en,
    input wire clk,
    input wire rst,
    input wire frame_rst,
    input wire [23:0] rgb_data,
    output wire [23:0] gs_img
);

    reg [23:0] gs_img_reg;

    wire [15:0] r, g, b, gsum;
    wire [7:0] gray;

    assign r = rgb_data[23:16] * 8'd77;
    assign g = rgb_data[15:8] * 8'd150;
    assign b = rgb_data[7:0] * 8'd29;

    assign gsum = r + g + b;
    assign gray = gsum[15:8];

    assign gs_img = gs_img_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            gs_img_reg <= 24'b0;
        else if (frame_rst)
            gs_img_reg <= 24'b0;
        else if (en)
            gs_img_reg <= {gray, gray, gray};
    end

endmodule


module high_contrast(
    input wire en,
    input wire clk,
    input wire rst,
    input wire frame_rst,
    input wire [23:0] rgb_data,
    output wire [23:0] hc_img
);

    reg [23:0] hc_img_reg;

    wire [7:0] r = rgb_data[23:16];
    wire [7:0] g = rgb_data[15:8];
    wire [7:0] b = rgb_data[7:0];

    wire [15:0] luminance_sum =
          (r * 8'd77)
        + (g * 8'd150)
        + (b * 8'd29);

    wire [7:0] y = luminance_sum[15:8];

    reg [7:0] y_out;

    always @(*) begin
        if (y <= 8'd64)
            y_out = 8'd0;
        else if (y >= 8'd192)
            y_out = 8'd255;
        else
            y_out = (y - 8'd64) << 1;
    end

    reg [3:0] shift_amt;

    always @(*) begin
        if (y <= 8'd90)
            shift_amt = 4'd6;
        else if (y <= 8'd181)
            shift_amt = 4'd7;
        else
            shift_amt = 4'd8;
    end

    wire [15:0] r_product = r * y_out;
    wire [15:0] g_product = g * y_out;
    wire [15:0] b_product = b * y_out;

    wire [15:0] r_scaled = r_product >> shift_amt;
    wire [15:0] g_scaled = g_product >> shift_amt;
    wire [15:0] b_scaled = b_product >> shift_amt;

    always @(posedge clk or posedge rst) begin
        if (rst)
            hc_img_reg <= 24'd0;
        else if (frame_rst)
            hc_img_reg <= 24'd0;
        else if (en) begin
            hc_img_reg <= {
                (r_scaled > 16'd255) ? 8'd255 : r_scaled[7:0],
                (g_scaled > 16'd255) ? 8'd255 : g_scaled[7:0],
                (b_scaled > 16'd255) ? 8'd255 : b_scaled[7:0]
            };
        end
    end

    assign hc_img = hc_img_reg;

endmodule


module cartoonizer #(
    parameter WIDTH = 640,
    parameter HEIGHT = 480,
    parameter EDGE_THRESHOLD = 36
)(
    input wire en,
    input wire clk,
    input wire reset,
    input wire pixel_valid,
    input wire [9:0] x,
    input wire [9:0] y,
    input wire [23:0] rgb_in,
    output reg [23:0] rgb_out
);

    reg [7:0] line_mem [0:WIDTH-1];

    reg [7:0] left_gray;
    reg [7:0] above_left_gray;

    wire [7:0] red = rgb_in[23:16];
    wire [7:0] green = rgb_in[15:8];
    wire [7:0] blue = rgb_in[7:0];

    wire [15:0] gray_sum;

    assign gray_sum =
          (red * 8'd77)
        + (green * 8'd150)
        + (blue * 8'd29);

    wire [7:0] current_gray = gray_sum[15:8];

    wire [7:0] above_gray = line_mem[x];

    wire [7:0] grad_x;
    wire [7:0] grad_y;

    assign grad_x =
        (above_left_gray >= current_gray) ?
        (above_left_gray - current_gray) :
        (current_gray - above_left_gray);

    assign grad_y =
        (above_gray >= left_gray) ?
        (above_gray - left_gray) :
        (left_gray - above_gray);

    wire [8:0] edge_strength =
        {1'b0, grad_x} + {1'b0, grad_y};

    function [7:0] contrast_enhance;
        input [7:0] pixel;
        reg [9:0] scaled;
        begin
            scaled =
                {2'b00, pixel} +
                ({2'b00, pixel} >> 1);

            if (scaled <= 10'd32)
                contrast_enhance = 8'd0;
            else if (scaled >= 10'd287)
                contrast_enhance = 8'd255;
            else
                contrast_enhance = scaled - 10'd32;
        end
    endfunction

    wire [7:0] enhanced_red =
        contrast_enhance(red);

    wire [7:0] enhanced_green =
        contrast_enhance(green);

    wire [7:0] enhanced_blue =
        contrast_enhance(blue);

    wire [7:0] quant_red = {
        enhanced_red[7:5],
        enhanced_red[7:5],
        enhanced_red[7:6]
    };

    wire [7:0] quant_green = {
        enhanced_green[7:5],
        enhanced_green[7:5],
        enhanced_green[7:6]
    };

    wire [7:0] quant_blue = {
        enhanced_blue[7:5],
        enhanced_blue[7:5],
        enhanced_blue[7:6]
    };

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            left_gray <= 8'd0;
            above_left_gray <= 8'd0;
            rgb_out <= 24'd0;
        end
        else if (en && pixel_valid &&
                 (x < WIDTH) && (y < HEIGHT)) begin

            line_mem[x] <= current_gray;

            left_gray <= current_gray;
            above_left_gray <= above_gray;

            if ((x == 0) || (y == 0)) begin
                rgb_out <= {
                    quant_red,
                    quant_green,
                    quant_blue
                };
            end
            else if (edge_strength >= EDGE_THRESHOLD) begin
                rgb_out <= 24'h000000;
            end
            else begin
                rgb_out <= {
                    quant_red,
                    quant_green,
                    quant_blue
                };
            end
        end
    end

endmodule


module DE1_SoC_Default(
    input wire ref_clk,
    input wire RST,
    input wire [1:0] OPCODE,

    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,

    output wire hsync,
    output wire vsync,

    output wire VGA_BLANK_N,
    output wire VGA_SYNC_N,
    output wire VGA_CLK
);

    wire CLK;

    VGA_Audio_0002 PLL (
        .refclk(ref_clk),
        .rst(RST),
        .outclk_0(CLK)
    );

    assign VGA_CLK = CLK;
    assign VGA_SYNC_N = 1'b0;

    reg [18:0] rom1_addr;

    wire [7:0] px_addr;
    wire [23:0] rgb_raw_data;

    img_data ROM1 (
        .address(rom1_addr),
        .clock(CLK),
        .q(px_addr)
    );

    img_index ROM2 (
        .address(px_addr),
        .clock(CLK),
        .q(rgb_raw_data)
    );

    reg [1:0] opcode_history;
    reg frame_restart;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            opcode_history <= 2'b00;
            frame_restart <= 1'b0;
        end
        else begin
            opcode_history <= OPCODE;
            frame_restart <= (OPCODE != opcode_history);
        end
    end

    wire cHS, cVS, cBN;

    video_sync_generator VGA_Sync (
        .reset(RST),
        .vga_clk(CLK),
        .blank_n(cBN),
        .HS(cHS),
        .VS(cVS)
    );

    wire [2:0] raw_syncs;
    wire [2:0] sync_pipe1;
    wire [2:0] sync_pipe2;
    wire [2:0] sync_pipe3;
    wire [2:0] sync_pipe4;
    wire [2:0] vga_signals_op;

    assign raw_syncs = {cBN, cHS, cVS};

    D_FF #(.WIDTH(3)) pipe_reg1 (
        .D(raw_syncs),
        .clk(CLK),
        .clr(RST),
        .Q(sync_pipe1)
    );

    D_FF #(.WIDTH(3)) pipe_reg2 (
        .D(sync_pipe1),
        .clk(CLK),
        .clr(RST),
        .Q(sync_pipe2)
    );

    D_FF #(.WIDTH(3)) pipe_reg3 (
        .D(sync_pipe2),
        .clk(CLK),
        .clr(RST),
        .Q(sync_pipe3)
    );

    D_FF #(.WIDTH(3)) pipe_reg4 (
        .D(sync_pipe3),
        .clk(CLK),
        .clr(RST),
        .Q(sync_pipe4)
    );

    D_FF #(.WIDTH(3)) pipe_reg5 (
        .D(sync_pipe4),
        .clk(CLK),
        .clr(RST),
        .Q(vga_signals_op)
    );

    reg [9:0] pixel_x;
    reg [9:0] pixel_y;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            rom1_addr <= 19'd0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end
        else if (frame_restart) begin
            rom1_addr <= 19'd0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end
        else if (!cHS && !cVS) begin
            rom1_addr <= 19'd0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end
        else if (cBN) begin
            if (rom1_addr == 19'd307199)
                rom1_addr <= 19'd0;
            else
                rom1_addr <= rom1_addr + 19'd1;

            if (pixel_x == 10'd639) begin
                pixel_x <= 10'd0;
                if (pixel_y == 10'd479)
                    pixel_y <= 10'd0;
                else
                    pixel_y <= pixel_y + 10'd1;
            end
            else begin
                pixel_x <= pixel_x + 10'd1;
            end
        end
    end

    reg [9:0] x_d1, x_d2;
    reg [9:0] y_d1, y_d2;

    reg valid_d1, valid_d2;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            x_d1 <= 10'd0;
            x_d2 <= 10'd0;
            y_d1 <= 10'd0;
            y_d2 <= 10'd0;
            valid_d1 <= 1'b0;
            valid_d2 <= 1'b0;
        end
        else if (frame_restart) begin
            x_d1 <= 10'd0;
            x_d2 <= 10'd0;
            y_d1 <= 10'd0;
            y_d2 <= 10'd0;
            valid_d1 <= 1'b0;
            valid_d2 <= 1'b0;
        end
        else begin
            x_d1 <= pixel_x;
            x_d2 <= x_d1;
            y_d1 <= pixel_y;
            y_d2 <= y_d1;
            valid_d1 <= cBN;
            valid_d2 <= valid_d1;
        end
    end

    wire [9:0] cartoon_x = x_d2;
    wire [9:0] cartoon_y = y_d2;

    reg [23:0] bp_reg1;
    reg [23:0] bp_reg2;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            bp_reg1 <= 24'd0;
            bp_reg2 <= 24'd0;
        end
        else if (frame_restart) begin
            bp_reg1 <= 24'd0;
            bp_reg2 <= 24'd0;
        end
        else begin
            bp_reg1 <= rgb_raw_data;
            bp_reg2 <= bp_reg1;
        end
    end

    wire [23:0] gs_op;
    reg [23:0] gs_delay;

    gray_scale gsf (
        .en(OPCODE == 2'b01),
        .clk(CLK),
        .rst(RST),
        .frame_rst(frame_restart),
        .rgb_data(rgb_raw_data),
        .gs_img(gs_op)
    );

    always @(posedge CLK or posedge RST) begin
        if (RST)
            gs_delay <= 24'd0;
        else if (frame_restart)
            gs_delay <= 24'd0;
        else
            gs_delay <= gs_op;
    end

    wire [23:0] hc_op;
    reg [23:0] hc_delay;

    high_contrast hcf (
        .en(OPCODE == 2'b10),
        .clk(CLK),
        .rst(RST),
        .frame_rst(frame_restart),
        .rgb_data(rgb_raw_data),
        .hc_img(hc_op)
    );

    always @(posedge CLK or posedge RST) begin
        if (RST)
            hc_delay <= 24'd0;
        else if (frame_restart)
            hc_delay <= 24'd0;
        else
            hc_delay <= hc_op;
    end

    wire [23:0] cartoon_op;
    reg [23:0] cartoon_delay;

    cartoonizer #(
        .WIDTH(640),
        .HEIGHT(480),
        .EDGE_THRESHOLD(36)
    ) cartoon (
        .en(OPCODE == 2'b11),
        .clk(CLK),
        .reset(RST | frame_restart),
        .pixel_valid(
            valid_d2 &&
            (cartoon_x < 10'd640) &&
            (cartoon_y < 10'd480)
        ),
        .x(cartoon_x),
        .y(cartoon_y),
        .rgb_in(rgb_raw_data),
        .rgb_out(cartoon_op)
    );

    always @(posedge CLK or posedge RST) begin
        if (RST)
            cartoon_delay <= 24'd0;
        else if (frame_restart)
            cartoon_delay <= 24'd0;
        else
            cartoon_delay <= cartoon_op;
    end

    wire [23:0] mux_op;
    wire [23:0] vga_data_op;

    mux_4_1 mux (
        .I0(bp_reg2),
        .I1(gs_delay),
        .I2(hc_delay),
        .I3(cartoon_delay),
        .sel(OPCODE),
        .out(mux_op)
    );

    D_FF #(.WIDTH(24)) dff_mux (
        .D(frame_restart ? 24'd0 : mux_op),
        .clk(CLK),
        .clr(RST),
        .Q(vga_data_op)
    );

    assign VGA_R =
        vga_signals_op[2] ? vga_data_op[23:16] : 8'h00;

    assign VGA_G =
        vga_signals_op[2] ? vga_data_op[15:8] : 8'h00;

    assign VGA_B =
        vga_signals_op[2] ? vga_data_op[7:0] : 8'h00;

    assign VGA_BLANK_N = vga_signals_op[2];

    assign hsync = vga_signals_op[1];
    assign vsync = vga_signals_op[0];

endmodule
