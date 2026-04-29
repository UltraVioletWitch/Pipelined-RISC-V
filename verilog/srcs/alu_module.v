module alu_module (
    input wire [31:0] alu_in1,
    input wire [31:0] alu_in2,
    input wire [4:0]  alu_ctrl,
    output wire zero,
    output reg [31:0] alu_result
);

    // alu ctrl definitions
    localparam ADD = 5'b00000, SUB = 5'b00001, XOR = 5'b00010, OR = 5'b00011, AND = 5'b00100, SLL = 5'b00101, 
               SRL = 5'b00110, SRA = 5'b00111, SLT = 5'b01000, SLTU = 5'b01001, MUL = 5'b01010, MULH = 5'b01011, 
               MULHU = 5'b01100, MULHSU = 5'b01101, DIV = 5'b01110, DIVU = 5'b01111, REM = 5'b10000, REMU = 5'b10001;

    always @* begin
        case (alu_ctrl)
            AND: alu_result = alu_in1 & alu_in2;
            OR:  alu_result = alu_in1 | alu_in2;
            ADD: alu_result = alu_in1 + alu_in2;
            XOR: alu_result = alu_in1 ^ alu_in2;
            SLL: alu_result = alu_in1 << alu_in2[4:0];
            SRL: alu_result = alu_in1 >> alu_in2[4:0];
            SUB: alu_result = alu_in1 - alu_in2;
            SRA: alu_result = $signed(alu_in1) >>> alu_in2[4:0];
            SLT: alu_result = ($signed(alu_in1) < $signed(alu_in2)) ? 1 : 0;
            SLTU: alu_result = (alu_in1 < alu_in2) ? 1 : 0;
            default: alu_result = 32'b0;
        endcase
    end

    assign zero = (alu_result == 32'b0);

endmodule
