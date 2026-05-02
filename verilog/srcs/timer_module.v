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

    localparam TIMER_MTIME_H = 32'hFFFF_0000;
    localparam TIMER_MTIME_L = 32'hFFFF_0004;
    localparam TIMER_MTIMECMP_H = 32'hFFFF_0008;
    localparam TIMER_MTIMECMP_L = 32'hFFFF_000C;

    wire [2:0] w_funct3 = EXMEM_Ctrl[19:17];
    wire [2:0] r_funct3 = IDEX_Ctrl[19:17];

    reg [63:0] mtime, mtimecmp;

    assign interrupt = (mtime >= mtimecmp) ? 1'b1 : 1'b0;

    initial begin
        mtime = 64'b0;
        mtimecmp = 64'hFFFF_FFFF_FFFF_FFFF;
    end

    // ── Address decode ────────────────────────────────────────────────────────
    wire timer_re = (addr_r == TIMER_MTIME_H) || (addr_r == TIMER_MTIME_L) ||
                   (addr_r == TIMER_MTIMECMP_H) || (addr_r == TIMER_MTIMECMP_L);
    wire timer_we = we && ((addr_w == TIMER_MTIME_H) || (addr_w == TIMER_MTIME_L) || 
                          (addr_w == TIMER_MTIMECMP_H)  || (addr_w == TIMER_MTIMECMP_L));

    // ── Combinational read mux ────────────────────────────────────────────────
    // Separate from the clocked block so d_read_comb is stable before the
    // clock edge; dout is then registered cleanly from it.
    reg [31:0] d_read_comb;
    always @* begin
        case (addr_r)
            TIMER_MTIME_H:  d_read_comb = mtime[63:32];
            TIMER_MTIME_L:  d_read_comb = mtime[31:0];
            TIMER_MTIMECMP_H: d_read_comb = mtimecmp[63:32];
            TIMER_MTIMECMP_L: d_read_comb = mtimecmp[31:0];
            default:  d_read_comb = 32'b0;
        endcase
    end

    // ── Combinational write mux ───────────────────────────────────────────────
    // Compute the full new 32-bit register value before the clock edge,
    // selecting the correct existing register for the read-modify-write.
    reg [31:0] existing_reg;
    always @* begin
        case (addr_w)
            TIMER_MTIME_H: existing_reg = mtime[63:32];
            TIMER_MTIME_L: existing_reg = mtime[31:0];
            TIMER_MTIMECMP_H:  existing_reg = mtimecmp[63:32];
            TIMER_MTIMECMP_L:  existing_reg = mtimecmp[31:0];
            default:  existing_reg = 32'b0;
        endcase
    end

    reg [31:0] d_write_comb;
    always @* begin
        d_write_comb = existing_reg; // default: no change

        if (timer_we) begin
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
        if (timer_re) begin
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
        if (reset) begin
            mtime    <= 64'b0;
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
        end else if (timer_we) begin
            case (addr_w)
                TIMER_MTIME_H: mtime[63:32] <= d_write_comb;
                TIMER_MTIME_L: mtime[31:0]  <= d_write_comb;
                TIMER_MTIMECMP_H:  mtimecmp[63:32]  <= d_write_comb;
                TIMER_MTIMECMP_L:  mtimecmp[31:0]  <= d_write_comb;
            endcase
        end else begin
            mtime <= mtime + 1;
        end
    end


endmodule
