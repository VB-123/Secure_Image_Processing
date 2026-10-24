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

module filter(input en, input clk, input rst, input [23:0] rgb_data, output [23:0] ff_img);
    assign ff_img = rgb_data; // Placeholder matching expected 2-cycle routing latencies later
endmodule

module DE1_SoC_Default(input ref_clk, input RST, input [1:0] OPCODE,
							output [7:0] VGA_R, output [7:0] VGA_G, output [7:0] VGA_B, 
							output hsync, output vsync, output VGA_BLANK_N, 
							output VGA_SYNC_N, output VGA_CLK);
	wire CLK;
	reg [18:0] rom1_addr;
	wire [7:0] px_addr;
	wire [23:0] rgb_raw_data, gs_op, hc_op, fil_op, mux_op, vga_data_op;
	reg [23:0] bp_reg1, bp_reg2, bp_reg3;
	wire cHS, cVS, cBN;
	wire [2:0] raw_syncs = {cBN, cHS, cVS};
	wire [2:0] sync_pipe1, sync_pipe2, sync_pipe3, sync_pipe4, vga_signals_op;
	reg [1:0] opcode_history;
   reg frame_restart;
	
	VGA_Audio_0002 PLL(.refclk(ref_clk), .rst(RST),.outclk_0(CLK));
	
	assign VGA_CLK = CLK;
   assign VGA_SYNC_N = 1'b0; 
	
	img_data ROM1(.address(rom1_addr), .clock(CLK), .q(px_addr));
	img_index ROM2(.address(px_addr), .clock(CLK), .q(rgb_raw_data));
	
	gray_scale gsf (.en(OPCODE == 2'b01), .clk(CLK), .rst(RST), .frame_rst(frame_restart), .rgb_data(rgb_raw_data), 
							.gs_img(gs_op));
	
	high_contrast hcf(.en(OPCODE == 2'b10), .clk(CLK), .rst(RST),.frame_rst(frame_restart), .rgb_data(rgb_raw_data),
						.hc_img(hc_op));
						
	filter ff (.en(OPCODE == 2'b11), .clk(CLK), .rst(RST), .rgb_data(rgb_raw_data), 
							.ff_img(fil_op));
	
	// After you implement the hc, ff change the mux inputs.
	mux_4_1 mux(.I0(bp_reg2), .I1(bp_reg3), .I2(bp_reg2), .I3(bp_reg2),
					.sel(OPCODE), .out(mux_op));
	D_FF #(.WIDTH(24)) dff_mux(.D(frame_restart ? 24'd0 : mux_op), .clk(CLK), .clr(RST), .Q(vga_data_op));
	
	video_sync_generator VGA_Sync(.reset(RST), 
											.vga_clk(CLK), 
											.blank_n(cBN),
											.HS(cHS),
											.VS(cVS));
											
	// Buffering for VGA Signals
	D_FF #(.WIDTH(3)) pipe_reg1 (.D(raw_syncs),   .clk(CLK), .clr(RST), .Q(sync_pipe1));
   D_FF #(.WIDTH(3)) pipe_reg2 (.D(sync_pipe1),  .clk(CLK), .clr(RST), .Q(sync_pipe2));
   D_FF #(.WIDTH(3)) pipe_reg3 (.D(sync_pipe2),  .clk(CLK), .clr(RST), .Q(sync_pipe3));
   D_FF #(.WIDTH(3)) pipe_reg4 (.D(sync_pipe3),  .clk(CLK), .clr(RST), .Q(sync_pipe4));
											
	D_FF #(.WIDTH(3)) dff_signals(.D(sync_pipe4), .clk(CLK), .clr(RST), .Q(vga_signals_op));
	
	always @(posedge CLK or posedge RST) begin
        if (RST) begin
            rom1_addr <= 19'd0;
        end
		  else if (frame_restart) begin // Synchronous internal restart check
            rom1_addr <= 19'd0;
			end
		  else if (cHS == 1'b0 && cVS == 1'b0) begin
            rom1_addr <= 19'd0;
        end 
		  else if (cBN == 1'b1) begin
            rom1_addr <= rom1_addr + 19'd1;
        end
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            opcode_history <= 2'b00;
            frame_restart  <= 1'b0;
        end else begin
            opcode_history <= OPCODE; // Track previous clock state
            
            // If the opcode bits change at any point, trigger a 1-cycle hard reset spike
            if (OPCODE != opcode_history) begin
                frame_restart <= 1'b1; 
            end else begin
                frame_restart <= 1'b0;
            end
        end
    end
	always @(posedge CLK or posedge RST) begin
		if (RST) begin
			bp_reg1 <= 24'd0;
			bp_reg2 <= 24'd0;
		end
		else if (frame_restart) begin // Synchronous internal restart check
         bp_reg1 <= 24'd0;
			bp_reg2 <= 24'd0;
		end
		else begin
			bp_reg1 <= rgb_raw_data;
			bp_reg2 <= bp_reg1;
		end
	end
	always @(posedge CLK or posedge RST) begin
		if (RST) begin
			bp_reg3 <= 24'd0;
		end
		else if (frame_restart) begin // Synchronous internal restart check
         bp_reg3 <= 24'd0;
		end
		else begin
			bp_reg3 <= gs_op;
		end
	end
	 
	assign VGA_R       = vga_data_op[23:16];
   assign VGA_G       = vga_data_op[15:8];
   assign VGA_B       = vga_data_op[7:0];
   assign VGA_BLANK_N = vga_signals_op[2];
   assign hsync       = vga_signals_op[1];
   assign vsync       = vga_signals_op[0];
endmodule
