module write_back_module (
    input wire [31:0] rd,
    input wire [31:0] alu,
    input wire [31:0] pc,
    input wire [31:0] ImmGen,
    input wire [31:0] csr_reg,
    input wire [2:0] ToReg,
    output wire [31:0] wr_data
);

    assign wr_data = (ToReg == 3'b000) ? alu :
                     (ToReg == 3'b001) ? pc + 4 :
                     (ToReg == 3'b010) ? rd :
                     (ToReg == 3'b011) ? pc + ImmGen :
                     (ToReg == 3'b100) ? ImmGen :
                     (ToReg == 3'b101) ? csr_reg :
                                         alu;

endmodule
