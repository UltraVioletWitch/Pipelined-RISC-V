module main (
    input wire clk,
    input wire reset,
    inout wire [15:0] gpio
);

    wire [31:0] mem_addr_r, mem_addr_w;
    wire [3:0] out;
    wire [31:0] dout, din;
    wire we;
    wire [31:0] IDEX_Ctrl, EXMEM_Ctrl;

    wire gpio_interrupt;
    wire [31:0] mip;

    assign mip = {20'b0, gpio_interrupt, 11'b0};

    wire [31:0] gpio_dout, data_dout;

    localparam GPIO_BASE = 32'hF000_0000, GPIO_TOP = 32'hF000_0010;

    assign dout = (mem_addr_w >= GPIO_BASE && mem_addr_w <= GPIO_TOP)
                  ? gpio_dout : data_dout;

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
endmodule
