module gpio_module (
    input clk,
    inout [15:0] gpio,
    input wire [31:0] addr_r,
    input wire [31:0] addr_w,
    input wire we,
    input wire [31:0] din,
    output reg [31:0] dout
);
    localparam GPIO_IN = 32'hF000_0000, GPIO_OUT = 32'hF000_0004, GPIO_DIR = 32'hF000_0008;

    reg [31:0] gpio_dir_reg;
    reg [31:0] gpio_out_reg;
    wire [15:0] gpio_in_wire;   // driven purely by IOBUFs

    wire [31:0] gpio_addr_w = (addr_w - GPIO_IN) >> 2;
    wire [31:0] gpio_addr_r = (addr_r - GPIO_IN) >> 2;

    initial begin
        gpio_dir_reg = 0;
        gpio_out_reg = 0;
    end

    wire gpio_re = (addr_r >= GPIO_IN && addr_r <= GPIO_DIR);
    wire gpio_we = we && (addr_w >= GPIO_OUT && addr_w <= GPIO_DIR);

    always @(posedge clk) begin
        if (gpio_re) begin
            case (addr_r)
                GPIO_IN:  dout <= {16'b0, gpio_in_wire};  // read live wire
                GPIO_OUT: dout <= gpio_out_reg;
                GPIO_DIR: dout <= gpio_dir_reg;
                default:  dout <= 32'b0;
            endcase
        end else begin
            dout <= 32'b0;
        end

        if (gpio_we) begin
            case (addr_w)
                GPIO_OUT: gpio_out_reg <= din;
                GPIO_DIR: gpio_dir_reg <= din;
            endcase
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gpio_buf
            IOBUF gpio_iobuf (
                .O  (gpio_in_wire[i]),      // wire, not reg
                .IO (gpio[i]),
                .I  (gpio_out_reg[i]),
                .T  (~gpio_dir_reg[i])
            );
        end
    endgenerate
endmodule
