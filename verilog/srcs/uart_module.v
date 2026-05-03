module uart_module (
    input wire clk, reset,
    input wire [31:0] addr_w, addr_r, din,
    input wire we,
    output reg [31:0] dout,
    input wire [31:0] EXMEM_Ctrl, IDEX_Ctrl,
    output wire interrupt,
    input wire rx,
    output wire tx
);

    localparam UART_TX = 32'hF000_1000,
               UART_RX = 32'hF000_1004,
               UART_IP = 32'hF000_1008,
               UART_IE = 32'hF000_100C;

    wire [2:0] w_funct3 = EXMEM_Ctrl[19:17];
    wire [2:0] r_funct3 = IDEX_Ctrl[19:17];

    reg [31:0] uart_tx_reg, uart_ip_reg, uart_ie_reg;

    assign interrupt = |(uart_ip_reg & uart_ie_reg);

    wire [7:0] tx_data = uart_tx_reg[7:0];
    wire [7:0] rx_data;
    reg tx_start, tx_start_r;
    wire tx_active, tx_done;
    wire rx_ready;
    wire tick_tx, tick_rx;
    reg [7:0] rx_data_latch;

    // ── Address decode ────────────────────────────────────────────────────────
    wire uart_re = (addr_r == UART_TX) || (addr_r == UART_RX) ||
                   (addr_r == UART_IP) || (addr_r == UART_IE);
    wire uart_we = we && ((addr_w == UART_TX) || (addr_w == UART_IP) || 
                          (addr_w == UART_IE));

    // ── Combinational read mux ────────────────────────────────────────────────
    // Separate from the clocked block so d_read_comb is stable before the
    // clock edge; dout is then registered cleanly from it.
    reg [31:0] d_read_comb;
    always @* begin
        case (addr_r)
            UART_TX:  d_read_comb = uart_tx_reg;
            UART_RX:  d_read_comb = {24'b0, rx_data_latch};
            UART_IP:  d_read_comb = uart_ip_reg;
            UART_IE:  d_read_comb = uart_ie_reg;
            default:  d_read_comb = 32'b0;
        endcase
    end

    // ── Combinational write mux ───────────────────────────────────────────────
    // Compute the full new 32-bit register value before the clock edge,
    // selecting the correct existing register for the read-modify-write.
    reg [31:0] existing_reg;
    always @* begin
        case (addr_w)
            UART_TX:  existing_reg = uart_tx_reg;
            UART_IP:  existing_reg = uart_ip_reg;
            UART_IE:  existing_reg = uart_ie_reg;
            default:  existing_reg = 32'b0;
        endcase
    end

    reg [31:0] d_write_comb;
    always @* begin
        d_write_comb = existing_reg; // default: no change

        if (uart_we) begin
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
        if (uart_re) begin
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

    // ── Clocked write ───────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_tx_reg <= 0;
            uart_ip_reg <= 0;
            uart_ie_reg <= 0;
            tx_start <= 0;
        end else begin
            uart_ip_reg <= uart_ip_reg | {30'b0, rx_ready, tx_done};
            tx_start <= tx_start_r;
            tx_start_r <= 0;
            if (uart_we) begin
                case (addr_w)
                    UART_TX: begin
                        uart_tx_reg <= d_write_comb;
                        tx_start_r <= 1;
                    end
                    UART_IP: uart_ip_reg <= uart_ip_reg & ~d_write_comb;
                    UART_IE: uart_ie_reg <= d_write_comb;
                endcase
            end
        end
    end

    // UART Module Definition
    baud_gen bg0 (
        .clk (clk),
        .reset (reset),
        .baud_tick_tx (tick_tx),
        .baud_tick_rx (tick_rx)
    );

    uart_tx tx0 (
        .clk (clk),
        .reset (reset),
        .baud_tick (tick_tx),
        .tx_start (tx_start),
        .tx_data (uart_tx_reg[7:0]),
        .tx_busy (tx_active),
        .tx_line (tx),
        .tx_done (tx_done)
    );

    uart_rx rx0 (
        .clk (clk),
        .reset (reset),
        .rx (rx),
        .baud_tick_rx (tick_rx),
        .data_valid (rx_ready),
        .data_out (rx_data)
    );

    always @(posedge clk or posedge reset) begin
        if (reset)
            rx_data_latch <= 0;
        else if (rx_ready)
            rx_data_latch <= rx_data;
    end

endmodule
