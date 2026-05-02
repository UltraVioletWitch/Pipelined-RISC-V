module main (
    input wire clk,
    input wire reset,
    inout wire [15:0] gpio
);

    wire [31:0] mem_addr_r, mem_addr_w;
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
        .mip(mip),
        .mem_addr_r(mem_addr_r),
        .mem_addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl)
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
        .reset(reset),
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
        .reset(reset),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(timer_dout),
        .IDEX_Ctrl(IDEX_Ctrl),
        .EXMEM_Ctrl(EXMEM_Ctrl),
        .interrupt(timer_interrupt)
    );
endmodule
