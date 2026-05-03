module instr_rom (
    input clk,
    input reset,
    input en,
    input [31:0] addr,
    output reg [31:0] dout,
    input wire [31:0] data_addr,
    output reg [31:0] data_dout,
    input wire [31:0] IDEX_Ctrl
);

    localparam CODE_BASE = 32'h0000_0000, CODE_TOP = 32'h0000_3FFF;

    wire [2:0] r_funct3 = IDEX_Ctrl[19:17];

    wire [11:0] raddr = (data_addr - CODE_BASE) >> 2;
    wire [11:0] iaddr = (addr - CODE_BASE) >> 2;
    wire data_re = (data_addr >= CODE_BASE) && (data_addr <= CODE_TOP);

    (* rom_style = "block" *) reg [31:0] rom [0:4095];
    initial $readmemh("program.hex", rom);

    reg [31:0] dout_raw;
    always @(posedge clk) begin
        if (reset)
            dout <= rom[0];
        else if (en)
            dout <= rom[iaddr];
    end

    always @(posedge clk) begin
        if (data_re)
            dout_raw <= rom[raddr];
        else
            dout_raw <= 32'b0;
    end

    reg [1:0]  addr_r_lsb_q;
    reg [2:0]  r_funct3_q;

    always @(posedge clk) begin
        addr_r_lsb_q <= data_addr[1:0];
        r_funct3_q   <= r_funct3;
    end

    // Output formatting (combinational, after BRAM read register)
    always @(*) begin
        case (r_funct3_q)
            3'h0: begin // LB
                case (addr_r_lsb_q)
                    2'b00: data_dout = {{24{dout_raw[ 7]}}, dout_raw[ 7: 0]};
                    2'b01: data_dout = {{24{dout_raw[15]}}, dout_raw[15: 8]};
                    2'b10: data_dout = {{24{dout_raw[23]}}, dout_raw[23:16]};
                    2'b11: data_dout = {{24{dout_raw[31]}}, dout_raw[31:24]};
                endcase
            end
            3'h1: begin // LH
                if (addr_r_lsb_q[1])
                    data_dout = {{16{dout_raw[31]}}, dout_raw[31:16]};
                else
                    data_dout = {{16{dout_raw[15]}}, dout_raw[15: 0]};
            end
            3'h2: data_dout = dout_raw; // LW
            3'h4: begin // LBU
                case (addr_r_lsb_q)
                    2'b00: data_dout = {24'b0, dout_raw[ 7: 0]};
                    2'b01: data_dout = {24'b0, dout_raw[15: 8]};
                    2'b10: data_dout = {24'b0, dout_raw[23:16]};
                    2'b11: data_dout = {24'b0, dout_raw[31:24]};
                endcase
            end
            3'h5: begin // LHU
                if (addr_r_lsb_q[1])
                    data_dout = {16'b0, dout_raw[31:16]};
                else
                    data_dout = {16'b0, dout_raw[15: 0]};
            end
            default: data_dout = dout_raw;
        endcase
    end
endmodule
