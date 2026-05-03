module main (
    input wire clk_100MHz,
    input wire reset,
    inout wire [15:0] gpio,
    input wire uart_rx,
    output wire uart_tx
);

    wire clk, locked;

    clk_wiz_0 clkgen (
        .clk_in1(clk_100MHz),
        .clk_out1(clk),
        .reset(reset),
        .locked(locked)
    );

    wire cpu_reset;
    reset_sync rs (
        .clk(clk),
        .async_rst(reset),
        .locked(locked),
        .sync_rst(cpu_reset)
    );

    wire [31:0] mem_addr_r, mem_addr_w;
<<<<<<< HEAD
    wire [31:0] dout, din;
    wire we;
    wire [31:0] IDEX_Ctrl, EXMEM_Ctrl;

    wire gpio_interrupt, timer_interrupt;
    wire [31:0] mip;

    assign mip = {20'b0, gpio_interrupt, 3'b0, timer_interrupt, 7'b0};

    wire [31:0] gpio_dout, data_dout, timer_dout;

    localparam GPIO_BASE = 32'hF000_0000, GPIO_TOP = 32'hF000_0010,
               TIMER_BASE = 32'hFFFF_0000, TIMER_TOP = 32'hFFFF_000C;

    wire is_gpio = mem_addr_w >= GPIO_BASE && mem_addr_w <= GPIO_TOP;
    wire is_timer = mem_addr_w >= TIMER_BASE && mem_addr_w <= TIMER_TOP;

    assign dout = is_gpio  ? gpio_dout  :
                  is_timer ? timer_dout :
                             data_dout;

    cpu core (
        .clk(clk),
        .reset(reset),
=======
    wire [31:0] dout, din, i_next, pc_next;
    wire we, load_hazard;
    wire [31:0] IDEX_Ctrl, EXMEM_Ctrl;

    wire gpio_interrupt, timer_interrupt, uart_interrupt;
    wire external_interrupt = gpio_interrupt || uart_interrupt;
    wire [31:0] mip;

    assign mip = {20'b0, external_interrupt, 3'b0, timer_interrupt, 7'b0};

    wire [31:0] gpio_dout, data_dout, timer_dout, uart_dout, rom_dout;

    localparam GPIO_BASE = 32'hF000_0000, GPIO_TOP = 32'hF000_0010,
               TIMER_BASE = 32'hFFFF_0000, TIMER_TOP = 32'hFFFF_000C,
               UART_BASE = 32'hF000_1000, UART_TOP = 32'hF000_100C,
               DATA_BASE = 32'h0000_4000, DATA_TOP = 32'h0000_7FFF,
               CODE_BASE = 32'h0000_0000, CODE_TOP = 32'h0000_3FFF;

    wire is_gpio = mem_addr_w >= GPIO_BASE && mem_addr_w <= GPIO_TOP;
    wire is_timer = mem_addr_w >= TIMER_BASE && mem_addr_w <= TIMER_TOP;
    wire is_uart = mem_addr_w >= UART_BASE && mem_addr_w <= UART_TOP;
    wire is_data = mem_addr_w >= DATA_BASE && mem_addr_w <= DATA_TOP;
    wire is_code = mem_addr_w >= CODE_BASE && mem_addr_w <= CODE_TOP;

    assign dout = is_gpio  ? gpio_dout  :
                  is_timer ? timer_dout :
                  is_uart  ? uart_dout  :
                  is_data  ? data_dout  :
                  is_code  ? rom_dout   :
                             32'b0;

    cpu core (
        .clk(clk),
        .reset(cpu_reset),
        .mip(mip),
        .mem_addr_r(mem_addr_r),
        .mem_addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl),
        .pc_next(pc_next),
        .load_hazard(load_hazard),
        .i_next(i_next)
    );

    instr_ram iMem (
        .clk(clk),
        .reset(cpu_reset),
        .en(!load_hazard),
        .addr(pc_next),
        .dout(i_next),
        .data_addr(mem_addr_r),
        .data_dout(rom_dout),
        .IDEX_Ctrl(IDEX_Ctrl)
    );

    block_ram dMem (
        .clk(clk),
        .we(we),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .din(din),
        .dout(data_dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl)
    );

    gpio_module gpio0 (
        .clk(clk),
        .reset(cpu_reset),
        .gpio(gpio),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(gpio_dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl),
        .interrupt(gpio_interrupt)
    );

    timer_module timer (
        .clk(clk),
        .reset(cpu_reset),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(timer_dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl),
        .interrupt(timer_interrupt)
    );

    uart_module uart (
        .clk(clk),
        .reset(cpu_reset),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .din(din),
        .we(we),
        .dout(uart_dout),
        .EXMEM_Ctrl(EXMEM_Ctrl),
        .IDEX_Ctrl(IDEX_Ctrl),
        .interrupt(uart_interrupt),
        .rx(uart_rx),
        .tx(uart_tx)
    );

endmodule
