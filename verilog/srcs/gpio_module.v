module gpio_module (
    input clk,
    input wire reset,
    inout [15:0] gpio,
    input wire [31:0] addr_r,
    input wire [31:0] addr_w,
    input wire we,
    input wire [31:0] din,
    output reg [31:0] dout,
    input wire [31:0] EXMEM_Ctrl,
    input wire [31:0] IDEX_Ctrl,
    output wire interrupt
);
    localparam GPIO_IN  = 32'hF000_0000,
               GPIO_OUT = 32'hF000_0004,
               GPIO_DIR = 32'hF000_0008,
               GPIO_IE  = 32'hF000_000C,
               GPIO_IP  = 32'hF000_0010;
 
    wire [2:0] w_funct3 = EXMEM_Ctrl[19:17];
    wire [2:0] r_funct3 = IDEX_Ctrl[19:17];

    reg [31:0] gpio_dir_reg;
    reg [31:0] gpio_out_reg;
    wire [15:0] gpio_in_wire;

    reg [31:0] gpio_ie_reg;
    reg [31:0] gpio_ip_reg;
    reg [15:0] gpio_in_r;

    assign interrupt = |(gpio_ip_reg & gpio_ie_reg);

    initial begin
        gpio_dir_reg = 32'b0;
        gpio_out_reg = 32'b0;
        gpio_ie_reg  = 32'b0;
        gpio_ip_reg  = 32'b0;
        gpio_in_r    = 32'b0;
    end

    // ── Address decode ────────────────────────────────────────────────────────
    wire gpio_re = (addr_r == GPIO_IN) || (addr_r == GPIO_OUT) ||
                   (addr_r == GPIO_DIR) || (addr_r == GPIO_IE) ||
                   (addr_r == GPIO_IP);
    wire gpio_we = we && ((addr_w == GPIO_OUT) || (addr_w == GPIO_DIR)) || 
                          (addr_w == GPIO_IE)  || (addr_w == GPIO_IP);

    // ── Combinational read mux ────────────────────────────────────────────────
    // Separate from the clocked block so d_read_comb is stable before the
    // clock edge; dout is then registered cleanly from it.
    reg [31:0] d_read_comb;
    always @* begin
        case (addr_r)
            GPIO_IN:  d_read_comb = {16'b0, gpio_in_wire};
            GPIO_OUT: d_read_comb = gpio_out_reg;
            GPIO_DIR: d_read_comb = gpio_dir_reg;
            GPIO_IE:  d_read_comb = gpio_ie_reg;
            GPIO_IP:  d_read_comb = gpio_ip_reg;
            default:  d_read_comb = 32'b0;
        endcase
    end

    // ── Combinational write mux ───────────────────────────────────────────────
    // Compute the full new 32-bit register value before the clock edge,
    // selecting the correct existing register for the read-modify-write.
    reg [31:0] existing_reg;
    always @* begin
        case (addr_w)
            GPIO_OUT: existing_reg = gpio_out_reg;
            GPIO_DIR: existing_reg = gpio_dir_reg;
            GPIO_IE:  existing_reg = gpio_ie_reg;
            GPIO_IP:  existing_reg = gpio_ip_reg;
            default:  existing_reg = 32'b0;
        endcase
    end

    reg [31:0] d_write_comb;
    always @* begin
        d_write_comb = existing_reg; // default: no change

        if (gpio_we) begin
            case (w_funct3)
                3'h0: begin // SB — byte write, preserve other bytes
                    case (addr_w[1:0])
                        2'b00: d_write_comb = {existing_reg[31:8],  din[7:0]};
                        2'b01: d_write_comb = {existing_reg[31:16], din[7:0], existing_reg[7:0]};
                        2'b10: d_write_comb = {existing_reg[31:24], din[7:0], existing_reg[15:0]};
                        2'b11: d_write_comb = {din[7:0], existing_reg[23:0]};
                    endcase
                end
                3'h1: begin // SH — halfword write, preserve other halfword
                    if (addr_w[1])
                        d_write_comb = {din[15:0], existing_reg[15:0]};
                    else
                        d_write_comb = {existing_reg[31:16], din[15:0]};
                end
                3'h2: d_write_comb = din; // SW — full word
                default: d_write_comb = existing_reg;
            endcase
        end
    end

    // ── Clocked read (dout) ───────────────────────────────────────────────────
    always @(posedge clk) begin
        if (gpio_re) begin
            case (r_funct3)
                3'h0: begin // LB
                    case (addr_r[1:0])
                        2'b00: dout <= {{24{d_read_comb[7]}},  d_read_comb[7:0]};
                        2'b01: dout <= {{24{d_read_comb[15]}}, d_read_comb[15:8]};
                        2'b10: dout <= {{24{d_read_comb[23]}}, d_read_comb[23:16]};
                        2'b11: dout <= {{24{d_read_comb[31]}}, d_read_comb[31:24]};
                    endcase
                end
                3'h1: begin // LH
                    if (addr_r[1])
                        dout <= {{16{d_read_comb[31]}}, d_read_comb[31:16]};
                    else
                        dout <= {{16{d_read_comb[15]}}, d_read_comb[15:0]};
                end
                3'h2: dout <= d_read_comb; // LW
                3'h4: begin // LBU
                    case (addr_r[1:0])
                        2'b00: dout <= {24'b0, d_read_comb[7:0]};
                        2'b01: dout <= {24'b0, d_read_comb[15:8]};
                        2'b10: dout <= {24'b0, d_read_comb[23:16]};
                        2'b11: dout <= {24'b0, d_read_comb[31:24]};
                    endcase
                end
                3'h5: begin // LHU
                    if (addr_r[1])
                        dout <= {16'b0, d_read_comb[31:16]};
                    else
                        dout <= {16'b0, d_read_comb[15:0]};
                end
                default: dout <= d_read_comb;
            endcase
        end else begin
            dout <= 32'b0;
        end
    end

    // ── Clocked write (gpio_out_reg / gpio_dir_reg) ───────────────────────────
    always @(posedge clk or posedge reset) begin
        gpio_in_r <= gpio_in_wire;

        gpio_ip_reg <= gpio_ip_reg | ({16'b0, gpio_in_wire & ~gpio_in_r} & gpio_ie_reg);

        if (reset) begin
            gpio_in_r    <= 0;
            gpio_dir_reg <= 0;
            gpio_out_reg <= 0;
            gpio_ie_reg  <= 0;
            gpio_ip_reg  <= 0;
        end else if (gpio_we) begin
            case (addr_w)
                GPIO_OUT: gpio_out_reg <= d_write_comb;
                GPIO_DIR: gpio_dir_reg <= d_write_comb;
                GPIO_IE:  gpio_ie_reg  <= d_write_comb;
                GPIO_IP:  gpio_ip_reg  <= gpio_ip_reg & ~d_write_comb;
            endcase
        end
    end

    // ── IOBUF instantiation ───────────────────────────────────────────────────
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gpio_buf
            IOBUF gpio_iobuf (
                .O  (gpio_in_wire[i]),
                .IO (gpio[i]),
                .I  (gpio_out_reg[i]),
                .T  (~gpio_dir_reg[i])  // 1 = input, 0 = output
            );
        end
    endgenerate

endmodule
