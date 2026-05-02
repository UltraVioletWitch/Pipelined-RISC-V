module block_ram (
    input clk,
    input we,
    input  [31:0] addr_w,
    input  [31:0] addr_r,
    input  [31:0] din,
    output reg [31:0] dout,
    input wire [31:0] IDEX_Ctrl,
    input wire [31:0] EXMEM_Ctrl
);

localparam DATA_BASE = 32'h0000_4000;

wire [2:0] w_funct3 = EXMEM_Ctrl[19:17];
wire [2:0] r_funct3 = IDEX_Ctrl[19:17];

wire [11:0] waddr = (addr_w - DATA_BASE) >> 2;
wire [11:0] raddr = (addr_r - DATA_BASE) >> 2;

wire data_we = we && (addr_w >= DATA_BASE) && (addr_w < 32'h0000_8000);
wire data_re =       (addr_r >= DATA_BASE) && (addr_r < 32'h0000_8000);

// Byte enables for partial writes
reg [3:0] byte_en;
reg [31:0] din_shifted;

always @(*) begin
    byte_en     = 4'b0000;
    din_shifted = 32'b0;
    if (data_we) begin
        case (w_funct3)
            3'h0: begin // SB
                case (addr_w[1:0])
                    2'b00: begin byte_en = 4'b0001; din_shifted = {24'b0, din[7:0]};        end
                    2'b01: begin byte_en = 4'b0010; din_shifted = {16'b0, din[7:0],  8'b0}; end
                    2'b10: begin byte_en = 4'b0100; din_shifted = {8'b0,  din[7:0], 16'b0}; end
                    2'b11: begin byte_en = 4'b1000; din_shifted = {din[7:0], 24'b0};        end
                endcase
            end
            3'h1: begin // SH
                if (addr_w[1]) begin
                    byte_en     = 4'b1100;
                    din_shifted = {din[15:0], 16'b0};
                end else begin
                    byte_en     = 4'b0011;
                    din_shifted = {16'b0, din[15:0]};
                end
            end
            3'h2: begin // SW
                byte_en     = 4'b1111;
                din_shifted = din;
            end
            default: byte_en = 4'b0000;
        endcase
    end
end

// BRAM primitive - simple dual port, synchronous read
(* ram_style = "block" *) reg [31:0] ram [0:4095];
reg [31:0] dout_raw;

always @(posedge clk) begin
    if (data_we) begin
        if (byte_en[0]) ram[waddr][ 7: 0] <= din_shifted[ 7: 0];
        if (byte_en[1]) ram[waddr][15: 8] <= din_shifted[15: 8];
        if (byte_en[2]) ram[waddr][23:16] <= din_shifted[23:16];
        if (byte_en[3]) ram[waddr][31:24] <= din_shifted[31:24];
    end
    if (data_re)
        dout_raw <= ram[raddr];
end

// Read data register (raw word)

reg [1:0]  addr_r_lsb_q;
reg [2:0]  r_funct3_q;

// Register read-side metadata to align with dout_raw
always @(posedge clk) begin
    addr_r_lsb_q <= addr_r[1:0];
    r_funct3_q   <= r_funct3;
end

// Output formatting (combinational, after BRAM read register)
always @(*) begin
    case (r_funct3_q)
        3'h0: begin // LB
            case (addr_r_lsb_q)
                2'b00: dout = {{24{dout_raw[ 7]}}, dout_raw[ 7: 0]};
                2'b01: dout = {{24{dout_raw[15]}}, dout_raw[15: 8]};
                2'b10: dout = {{24{dout_raw[23]}}, dout_raw[23:16]};
                2'b11: dout = {{24{dout_raw[31]}}, dout_raw[31:24]};
            endcase
        end
        3'h1: begin // LH
            if (addr_r_lsb_q[1])
                dout = {{16{dout_raw[31]}}, dout_raw[31:16]};
            else
                dout = {{16{dout_raw[15]}}, dout_raw[15: 0]};
        end
        3'h2: dout = dout_raw; // LW
        3'h4: begin // LBU
            case (addr_r_lsb_q)
                2'b00: dout = {24'b0, dout_raw[ 7: 0]};
                2'b01: dout = {24'b0, dout_raw[15: 8]};
                2'b10: dout = {24'b0, dout_raw[23:16]};
                2'b11: dout = {24'b0, dout_raw[31:24]};
            endcase
        end
        3'h5: begin // LHU
            if (addr_r_lsb_q[1])
                dout = {16'b0, dout_raw[31:16]};
            else
                dout = {16'b0, dout_raw[15: 0]};
        end
        default: dout = dout_raw;
    endcase
end

endmodule
