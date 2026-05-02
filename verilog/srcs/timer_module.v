module timer_module (
    input clk,
    input reset,
    input wire [31:0] addr_r,
    input wire [31:0] addr_w,
    input wire we,
    input wire [31:0] din,
    output reg [31:0] dout,
    input wire [31:0] EXMEM_Ctrl,
    input wire [31:0] IDEX_Ctrl,
    output wire interrupt
);

endmodule
