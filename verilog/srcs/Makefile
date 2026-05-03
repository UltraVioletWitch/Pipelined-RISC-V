all: simulate

simulate:
	@iverilog -o sim tb.v cpu.v block_ram.v alu_module.v control_module.v write_back_module.v instr_ram.v main.v gpio_module.v iobuf_stub.v timer_module.v reset_sync.v uart_module.v uart_rx.v uart_tx.v baud_gen.v
	@vvp sim
