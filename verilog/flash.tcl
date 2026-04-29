read_verilog { "./srcs/cpu.v" "./srcs/main.v" "./srcs/alu_module.v" "./srcs/control_module.v" "./srcs/write_back_module.v" }

read_xdc "./srcs/Arty-S7-25-Master.xdc"

add_files -norecurse {/home/violet/Documents/Projects/Pipeline/c/program.hex}
set_property file_type {Memory Initialization Files} [get_files {program.hex}]
update_compile_order -fileset sources_1

# place and route
puts "Starting synthesis..."
synth_design -top "main" -part "xc7s25csga324-1"

puts "Running opt_design..."
opt_design

puts "Running place_design..."
place_design

puts "Running route_design..."
route_design

report_utilization -file util.txt
report_timing_summary -file timing.txt

# then check specifically
report_methodology -file method.txt

# most useful for IO specifically
report_io -file io.txt

report_ram_utilization -file ram.txt


puts "Writing bitstream..."
write_bitstream -force "main.bit"


set bitfile   "main.bit"
set mcsfile   "main.mcs"
set flash_size "16"   ;# 16 MByte = 128 Mbit (N25Q128)

open_hw_manager
connect_hw_server
open_hw_target

current_hw_device [get_hw_devices xc7s25_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7s25_0] 0]

write_cfgmem \
    -format mcs \
    -interface spix4 \
    -size $flash_size \
    -loadbit "up 0x0 $bitfile" \
    -file $mcsfile \
    -force

create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7s25_0] 0] [lindex [get_cfgmem_parts {s25fl128sxxxxxx0-spi-x1_x2_x4}] 0]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0]

set_property PROGRAM.ADDRESS_RANGE  {use_file} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.FILES [list "/home/violet/Documents/Projects/Pipeline/verilog/main.mcs" ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.PRM_FILE {} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
startgroup
create_hw_bitstream -hw_device [lindex [get_hw_devices xc7s25_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices xc7s25_0] 0]]; program_hw_devices [lindex [get_hw_devices xc7s25_0] 0]; refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0];

program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]

endgroup
