`timescale 1 ns / 1 ps

module DE1_SoC_Default_tb;

    reg        tb_ref_clk;
    reg        tb_rst;       // reset
    reg  [1:0] tb_opcode;   
    wire [7:0] vga_r;
    wire [7:0] vga_g;
    wire [7:0] vga_b;
    wire        hsync;
    wire        vsync;
    wire        vga_blank_n;
    wire        vga_sync_n;
    wire        vga_clk;


    DE1_SoC_Default UUT (
        .ref_clk     (tb_ref_clk),   // 50 MHz input reference clock
        .RST         (tb_rst),       // Active-high master reset input
        .OPCODE      (tb_opcode),   
        .VGA_R       (vga_r),
        .VGA_G       (vga_g),
        .VGA_B       (vga_b),
        .hsync       (hsync),
        .vsync       (vsync),
        .VGA_BLANK_N (vga_blank_n),
        .VGA_SYNC_N  (vga_sync_n),
        .VGA_CLK     (vga_clk)
    );

    initial begin
        tb_ref_clk = 1'b0;
    end
    always begin
        #10 tb_ref_clk = ~tb_ref_clk;
    end

    initial begin
        tb_rst    = 1'b1;   
        tb_opcode = 2'b00;
     
        #100;
        @(posedge tb_ref_clk);
        tb_rst = 1'b0;        
	$display("[TB STATUS @ %0d ns] System Reset Released. Initializing Bypass Mode (00)...", $time);

        #8000; // Bypass

        @(posedge UUT.CLK);         
	tb_opcode = 2'b01;        
	$display("[TB INTERRUPT @ %0d ns] Switch Triggered! OPCODE shifted to Grayscale (01) mid-frame.", $time);

        #12000;

	tb_opcode = 2'b10;

	$display("[TB INTERRUPT @ %0t] OPCODE changed to 10", $time);
	#10000;
	$display("[TB STATUS @ %0t] Verification complete.", $time);
	$stop;
    end

    initial begin
        #120; 
        $monitor("Time=%60d ns | Mode=%b | Internal_Addr=%6d | Pins: R=%h G=%h B=%h | HS=%b VS=%b BLANK_N=%b | RESTART=%b", 
                 $time, tb_opcode, UUT.rom1_addr, vga_r, vga_g, vga_b, hsync, vsync, vga_blank_n, UUT.frame_restart);
    end
	 
endmodule
