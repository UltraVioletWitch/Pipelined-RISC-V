all: simulate

simulate:
	@iverilog -o sim tb.v cpu.v block_ram.v alu_module.v control_module.v write_back_module.v instr_rom.v main.v gpio_module.v iobuf_stub.v timer_module.v
	@vvp sim
