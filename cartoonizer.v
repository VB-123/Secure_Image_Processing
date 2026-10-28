
module cartoonizer #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter integer EDGE_THRESHOLD = 36
)(
    input  wire        en,
    input  wire        clk,
    input  wire        reset,
    input  wire        pixel_valid,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [23:0] rgb_in,
    output reg  [23:0] rgb_out
);

    // One grayscale value per pixel in the previous scanline.
    reg [7:0] line_mem [0:WIDTH-1];

    reg [7:0] left_gray;
    reg [7:0] above_left_gray;

    wire [15:0] gray_sum;
    wire [7:0] current_gray;
    wire [7:0] above_gray;

    wire [7:0] diff_left;
    wire [7:0] diff_above;
    wire [7:0] diff_diagonal;

    wire [9:0] edge_strength;

    // Weighted grayscale: (77R + 150G + 29B) / 256.
    assign gray_sum =
          rgb_in[23:16] * 16'd77
        + rgb_in[15:8]  * 16'd150
        + rgb_in[7:0]   * 16'd29;

    assign current_gray = gray_sum[15:8];

    // Previous-row pixel at the current x coordinate.
    // line_mem is updated only for valid cartoon pixels.
    assign above_gray = line_mem[x];

    // Absolute differences.
    assign diff_left = (current_gray >= left_gray)
                     ? current_gray - left_gray
                     : left_gray - current_gray;

    assign diff_above = (current_gray >= above_gray)
                      ? current_gray - above_gray
                      : above_gray - current_gray;

    assign diff_diagonal = (current_gray >= above_left_gray)
                         ? current_gray - above_left_gray
                         : above_left_gray - current_gray;

    assign edge_strength =
          {2'b00, diff_left}
        + {2'b00, diff_above}
        + {2'b00, diff_diagonal};

    // Quantize each color channel to four levels:
    // 00, 55, AA, FF.
    function [7:0] quantize2;
        input [7:0] channel;
        begin
            quantize2 = {
                channel[7:6],
                channel[7:6],
                channel[7:6],
                channel[7:6]
            };
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            left_gray       <= 8'd0;
            above_left_gray <= 8'd0;
            rgb_out         <= 24'h000000;
        end else if (!en) begin
            // Do not process pixels while another mode is selected.
            left_gray       <= 8'd0;
            above_left_gray <= 8'd0;
            rgb_out         <= 24'h000000;
        end else if (pixel_valid && (x < WIDTH) && (y < HEIGHT)) begin

            // Draw outlines where the neighborhood changes strongly.
            if ((x != 0) && (y != 0) &&
                (edge_strength >= EDGE_THRESHOLD)) begin
                rgb_out <= 24'h000000;
            end else begin
                rgb_out <= {
                    quantize2(rgb_in[23:16]),
                    quantize2(rgb_in[15:8]),
                    quantize2(rgb_in[7:0])
                };
            end

            // Save the current pixel for the next scanline.
            line_mem[x] <= current_gray;

            // Track neighboring pixels.
            if (x == 0) begin
                left_gray       <= current_gray;
                above_left_gray <= above_gray;
            end else begin
                left_gray       <= current_gray;
                above_left_gray <= above_gray;
            end

        end else begin
            rgb_out <= 24'h000000;
        end
    end

endmodule