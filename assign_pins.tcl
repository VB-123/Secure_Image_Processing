
# ============================================================
# DE1-SoC VGA Project: Pin Assignments
# Top-level entity: DE1_SoC_Default
# Source: Pin table supplied from the board manual
# ============================================================

# Clock and control inputs
set_location_assignment PIN_AF14 -to ref_clk
set_location_assignment PIN_AE12 -to RST
set_location_assignment PIN_AE11 -to EN
set_location_assignment PIN_AD10 -to {OPCODE[1]}
set_location_assignment PIN_AC9  -to {OPCODE[0]}

# VGA Red
set_location_assignment PIN_A13 -to {VGA_R[0]}
set_location_assignment PIN_C13 -to {VGA_R[1]}
set_location_assignment PIN_E13 -to {VGA_R[2]}
set_location_assignment PIN_B12 -to {VGA_R[3]}
set_location_assignment PIN_C12 -to {VGA_R[4]}
set_location_assignment PIN_D12 -to {VGA_R[5]}
set_location_assignment PIN_E12 -to {VGA_R[6]}
set_location_assignment PIN_F13 -to {VGA_R[7]}

# VGA Green
set_location_assignment PIN_J9  -to {VGA_G[0]}
set_location_assignment PIN_J10 -to {VGA_G[1]}
set_location_assignment PIN_H12 -to {VGA_G[2]}
set_location_assignment PIN_G10 -to {VGA_G[3]}
set_location_assignment PIN_G11 -to {VGA_G[4]}
set_location_assignment PIN_G12 -to {VGA_G[5]}
set_location_assignment PIN_F11 -to {VGA_G[6]}
set_location_assignment PIN_E11 -to {VGA_G[7]}

# VGA Blue
set_location_assignment PIN_B13 -to {VGA_B[0]}
set_location_assignment PIN_G13 -to {VGA_B[1]}
set_location_assignment PIN_H13 -to {VGA_B[2]}
set_location_assignment PIN_F14 -to {VGA_B[3]}
set_location_assignment PIN_H14 -to {VGA_B[4]}
set_location_assignment PIN_F15 -to {VGA_B[5]}
set_location_assignment PIN_G15 -to {VGA_B[6]}
set_location_assignment PIN_J14 -to {VGA_B[7]}

# VGA synchronization and control
set_location_assignment PIN_B11 -to hsync
set_location_assignment PIN_D11 -to vsync
set_location_assignment PIN_F10 -to VGA_BLANK_N
set_location_assignment PIN_C10 -to VGA_SYNC_N
set_location_assignment PIN_A11 -to VGA_CLK

# ============================================================
# I/O standards
# ============================================================

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ref_clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RST
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to {OPCODE[1]}
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to {OPCODE[0]}

foreach i {0 1 2 3 4 5 6 7} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_R\[$i\]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_G\[$i\]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_B\[$i\]
}

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to hsync
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vsync
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_BLANK_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_SYNC_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_CLK

puts "DE1-SoC pin assignments loaded."
