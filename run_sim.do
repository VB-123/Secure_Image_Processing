vlib work
vmap work work

# 2. Compile your design IP block dependencies
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/V/PLL/VGA_Audio_0002.v
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/V/ROM/img_data.v
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/V/ROM/img_index.v
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/V/video_sync_generator.v

# 3. Compile the core top module and the testbench
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/DE1_SoC_Default.v
vlog C:/Users/VB100/Desktop/Vasanthi_Folder/VLSI_work/Secure_Image_Processing-main/simulation/modelsim/DE1_SoC_Default_tb

# 4. Elaborate the design with Intel IP libraries linked and suppress timescale alerts
vsim -suppress 3009 -L altera_ver -L altera_mf_ver -L altera_lnsim_ver work.DE1_SoC_Default_tb
view wave

add wave -divider "Top-Level Pins"
add wave /DE1_SoC_Default_tb/ref_clk
add wave /DE1_SoC_Default_tb/RST
add wave /DE1_SoC_Default_tb/EN
add wave /DE1_SoC_Default_tb/OPCODE
add wave -hex /DE1_SoC_Default_tb/VGA_R
add wave -hex /DE1_SoC_Default_tb/VGA_G
add wave -hex /DE1_SoC_Default_tb/VGA_B
add wave /DE1_SoC_Default_tb/VGA_BLANK_N

# Add the internal hardware tracking control paths
add wave -divider "UUT Control Path"
add wave /DE1_SoC_Default_tb/UUT/CLK
add wave /DE1_SoC_Default_tb/UUT/frame_restart
add wave -unsigned /DE1_SoC_Default_tb/UUT/rom1_addr
add wave -hex /DE1_SoC_Default_tb/UUT/mux_op
add wave -hex /DE1_SoC_Default_tb/UUT/lfsr

# 5. Execute the entire 25 ms video frame run loop natively
run -all

# 6. Flush the VCD text buffers to disk and close the simulator handle cleanly
quit -sim