module mux_4_1(input [23:0] I0, I1, I2, I3, input[1:0] sel, output [23:0] out);
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
    input  wire [WIDTH-1:0] D, 
    input  wire             clk, 
    input  wire             clr, 
    output reg  [WIDTH-1:0] Q
);
    always @(posedge clk) begin
        if (clr) begin 
            Q <= {WIDTH{1'b0}};
        end else begin
            Q <= D;
        end
    end
endmodule

module gray_scale(input wire en, input wire clk, input wire rst, input wire frame_rst, input wire [23:0] rgb_data, output wire [23:0] gs_img);
    //Use 0.299*R + 0.587*G + 0.114*B - luminosity weighted method
	// (77*R + 150*G + 29*B)/256 : >>8
	reg [23:0] gs_img_reg;
	wire [15:0] r,g,b, gsum;
	wire [7:0] gray;
	assign r = rgb_data[23:16] * 8'd77;
	assign g = rgb_data[15:8] * 8'd150;
	assign b = rgb_data[7:0] * 8'd29;
	assign gsum = r + g + b;
	assign gray = gsum[15:8];// Basically >>8, but without the shift.
	assign gs_img = gs_img_reg;
	always @(posedge clk or posedge rst)begin
	   if (rst) begin
	       gs_img_reg <= 24'b0;
	   end
	   else if (frame_rst) begin
	       gs_img_reg <= 24'b0;
	   end
	   else if (en) begin
	       gs_img_reg <= {gray, gray, gray};
	   end   
	end
endmodule

module high_contrast(
    input en, input clk, input rst, input frame_rst,
    input [23:0] rgb_data,
    output wire [23:0] hc_img
);
    reg [23:0] hc_img_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            hc_img_reg <= 24'd0;
        else if (frame_rst)
            hc_img_reg <= 24'd0;
        else
            hc_img_reg <= rgb_data;
    end

    assign hc_img = hc_img_reg;
endmodule

module cartoonizer #(
    parameter WIDTH = 640,
    parameter HEIGHT = 480,
    parameter EDGE_THRESHOLD = 36
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        en,
    input  wire        pixel_valid,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [23:0] rgb_in,
    output reg  [23:0] rgb_out
);

    // One previous image row of grayscale pixels
    reg [7:0] line_mem [0:WIDTH-1];

    // Previous-row and previous-column pixel values
    reg [7:0] left_gray;
    reg [7:0] above_left_gray;

    // RGB components
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    assign red   = rgb_in[23:16];
    assign green = rgb_in[15:8];
    assign blue  = rgb_in[7:0];

    // RGB to grayscale
    wire [15:0] gray_sum;

    assign gray_sum =
          (red   * 8'd77)
        + (green * 8'd150)
        + (blue  * 8'd29);

    wire [7:0] current_gray;
    assign current_gray = gray_sum[15:8];

    // Pixel directly above the current pixel
    wire [7:0] above_gray;
    assign above_gray = line_mem[x];

    // Roberts Cross 2x2 diagonal gradients
    wire [7:0] Gx;
    wire [7:0] Gy;

    // Gx = |A - D|
    assign Gx = (above_left_gray >= current_gray)
              ? (above_left_gray - current_gray)
              : (current_gray - above_left_gray);

    // Gy = |B - C|
    assign Gy = (above_gray >= left_gray)
              ? (above_gray - left_gray)
              : (left_gray - above_gray);

    // Approximate Roberts Cross magnitude
    wire [8:0] edge_strength;

    assign edge_strength = {1'b0, Gx} + {1'b0, Gy};

    // Sequential pixel processing
    always @(posedge clk) begin
        if (reset) begin
            left_gray       <= 8'd0;
            above_left_gray <= 8'd0;
            rgb_out         <= 24'd0;
        end
        else if (en && pixel_valid && x < WIDTH && y < HEIGHT) begin

            // Save current grayscale pixel for the next image row
            line_mem[x] <= current_gray;

            // Update neighboring pixel registers.
            // Preserve above_gray at x=0 for the next pixel.
            left_gray       <= current_gray;
            above_left_gray <= above_gray;

            // Border handling: do not detect edges where the
            // required 2x2 neighborhood is incomplete.
            if ((x == 0) || (y == 0)) begin
                rgb_out <= rgb_in;
            end

            // Roberts Cross edge decision
            else if (edge_strength >= EDGE_THRESHOLD) begin
                rgb_out <= 24'h000000;
            end

            // Non-edge pixel: preserve original RGB color
            else begin
                rgb_out <= rgb_in;
            end
        end
    end
endmodule

module DE1_SoC_Default(
    input  wire       ref_clk,
    input  wire       RST,
    input  wire [1:0] OPCODE,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       hsync,
    output wire       vsync,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    //==================================================
    // 1. CLOCK
    //==================================================

    wire CLK;

    VGA_Audio_0002 PLL (
        .refclk(ref_clk),
        .rst(RST),
        .outclk_0(CLK)
    );

    assign VGA_CLK    = CLK;
    assign VGA_SYNC_N = 1'b0;

    //==================================================
    // 2. ROM
    //==================================================

    reg  [18:0] rom1_addr;
    wire [7:0]  px_addr;
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

    //==================================================
    // 3. OPCODE CHANGE DETECTION
    //==================================================

    reg [1:0] opcode_history;
    reg frame_restart;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            opcode_history <= 2'b00;
            frame_restart  <= 1'b0;
        end else begin
            opcode_history <= OPCODE;
            frame_restart <= (OPCODE != opcode_history);
        end
    end

    //==================================================
    // 4. VGA SYNCHRONIZATION
    //==================================================

    wire cHS, cVS, cBN;

    video_sync_generator VGA_Sync (
        .reset(RST),
        .vga_clk(CLK),
        .blank_n(cBN),
        .HS(cHS),
        .VS(cVS)
    );

    wire [2:0] raw_syncs;
    wire [2:0] sync_pipe1, sync_pipe2;
    wire [2:0] sync_pipe3, sync_pipe4;
    wire [2:0] vga_signals_op;

    assign raw_syncs = {cBN, cHS, cVS};

    D_FF #(.WIDTH(3)) pipe_reg1 (
        .D(raw_syncs), .clk(CLK), .clr(RST), .Q(sync_pipe1)
    );

    D_FF #(.WIDTH(3)) pipe_reg2 (
        .D(sync_pipe1), .clk(CLK), .clr(RST), .Q(sync_pipe2)
    );

    D_FF #(.WIDTH(3)) pipe_reg3 (
        .D(sync_pipe2), .clk(CLK), .clr(RST), .Q(sync_pipe3)
    );

    D_FF #(.WIDTH(3)) pipe_reg4 (
        .D(sync_pipe3), .clk(CLK), .clr(RST), .Q(sync_pipe4)
    );

    D_FF #(.WIDTH(3)) pipe_reg5 (
        .D(sync_pipe4), .clk(CLK), .clr(RST), .Q(vga_signals_op)
    );

    //==================================================
    // 5. ROM ADDRESS COUNTER
    //
    // Assumes cBN is active high during visible pixels.
    //==================================================

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            rom1_addr <= 19'd0;
        end else if (frame_restart) begin
            rom1_addr <= 19'd0;
        end else if (!cHS && !cVS) begin
            rom1_addr <= 19'd0;
        end else if (cBN) begin
            if (rom1_addr == 19'd307199)
                rom1_addr <= 19'd0;
            else
                rom1_addr <= rom1_addr + 19'd1;
        end
    end

    //==================================================
    // 6. ORIGINAL RGB PIPELINE
    //==================================================

    reg [23:0] bp_reg1, bp_reg2;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            bp_reg1 <= 24'd0;
            bp_reg2 <= 24'd0;
        end else if (frame_restart) begin
            bp_reg1 <= 24'd0;
            bp_reg2 <= 24'd0;
        end else begin
            bp_reg1 <= rgb_raw_data;
            bp_reg2 <= bp_reg1;
        end
    end

    //==================================================
    // 7. GRAYSCALE
    //==================================================

    wire [23:0] gs_op;
    reg  [23:0] gs_delay;

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

    //==================================================
    // 8. HIGH CONTRAST
    //==================================================

    wire [23:0] hc_op;
    reg  [23:0] hc_delay;

    high_contrast hcf (
        .en(OPCODE == 2'b10),
        .clk(CLK),
        .rst(RST),
        .frame_rst(frame_restart),
        .rgb_data(rgb_raw_data),
        .hc_img(hc_op)
    );

    // Align the high-contrast path with the RGB path.
    always @(posedge CLK or posedge RST) begin
        if (RST)
            hc_delay <= 24'd0;
        else if (frame_restart)
            hc_delay <= 24'd0;
        else
            hc_delay <= hc_op;
    end

    //==================================================
    // 9. CARTOONIZER — OPCODE 11
    //==================================================

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
	.linear_addr(rom1_addr),
        .rgb_in(rgb_raw_data),
        .rgb_out(cartoon_op)
    );

    // Match the extra output register used by the other processing paths.
    always @(posedge CLK or posedge RST) begin
        if (RST)
            cartoon_delay <= 24'd0;
        else if (frame_restart)
            cartoon_delay <= 24'd0;
        else
            cartoon_delay <= cartoon_op;
    end
    //==================================================
    // 10. FOUR-MODE MULTIPLEXER
    //
    // OPCODE 00 = Original
    // OPCODE 01 = Grayscale
    // OPCODE 10 = High contrast
    // OPCODE 11 = Cartoon
    //==================================================

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

    //==================================================
    // 11. VGA OUTPUT
    //==================================================

    assign VGA_R = vga_signals_op[2]
                 ? vga_data_op[23:16] : 8'h00;

    assign VGA_G = vga_signals_op[2]
                 ? vga_data_op[15:8] : 8'h00;

    assign VGA_B = vga_signals_op[2]
                 ? vga_data_op[7:0] : 8'h00;

    assign VGA_BLANK_N = vga_signals_op[2];
    assign hsync       = vga_signals_op[1];
    assign vsync       = vga_signals_op[0];

endmodule
