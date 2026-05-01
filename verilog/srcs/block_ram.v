module block_ram (
    input clk,
    input we,
    input [31:0] addr_w,
    input [31:0] addr_r,
    input [31:0] din,
    output reg [31:0] dout
);

    localparam DATA_BASE = 32'h0000_4000, DATA_TOP = 32'h0000_8000;

    wire data_re = addr_r >= DATA_BASE && addr_r < DATA_TOP;
    wire data_we = we && addr_w >= DATA_BASE && addr_w < DATA_TOP;

    wire [31:0] data_addr_w = (addr_w - DATA_BASE) >> 2;
    wire [31:0] data_addr_r = (addr_r - DATA_BASE) >> 2;

    (* ram_style = "block" *) reg [31:0] ram[0:4095];

    always @(posedge clk) begin
        if (data_we && data_re) begin
            ram[data_addr_w] <= din;
            dout <= ram[data_addr_r];
        end else if (data_re) begin
            dout <= ram[data_addr_r];
        end else if (data_we) begin
            ram[data_addr_w] <= din;
        end
    end
endmodule
