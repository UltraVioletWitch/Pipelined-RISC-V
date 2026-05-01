module main (
    input wire clk,
    input wire reset,
    inout wire [15:0] gpio
);

    wire [31:0] mem_addr_r, mem_addr_w;
    wire [3:0] out;
    wire [31:0] dout, din;
    wire we;

    wire [31:0] gpio_dout, data_dout;

    localparam GPIO_BASE = 32'hF000_0000, GPIO_TOP = 32'hF000_0008;

    assign dout = (mem_addr_r >= GPIO_BASE && mem_addr_r <= GPIO_TOP)
                  ? gpio_dout : data_dout;

    cpu core (
        .clk(clk),
        .reset(reset),
        .out(out),
        .mem_addr_r(mem_addr_r),
        .mem_addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(dout)
    );

    block_ram dMem (
        .clk(clk),
        .we(we),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .din(din),
        .dout(data_dout)
    );

    gpio_module gpio0 (
        .clk(clk),
        .gpio(gpio),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .we(we),
        .din(din),
        .dout(gpio_dout)
    );
endmodule
