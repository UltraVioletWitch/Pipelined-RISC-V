module control_module (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [11:0] funct12,
    output wire [31:0] ctrl,
    input wire [4:0] rd,
    input wire [4:0] rs1
);

    localparam ADD = 5'b00000, SUB = 5'b00001, XOR = 5'b00010, OR = 5'b00011, AND = 5'b00100, SLL = 5'b00101, 
               SRL = 5'b00110, SRA = 5'b00111, SLT = 5'b01000, SLTU = 5'b01001, MUL = 5'b01010, MULH = 5'b01011, 
               MULHU = 5'b01100, MULHSU = 5'b01101, DIV = 5'b01110, DIVU = 5'b01111, REM = 5'b10000, REMU = 5'b10001,
               ANDN = 5'b10010, PASS = 5'b10011, PASS2 = 5'b10100;

    localparam LOAD = 7'b0000011, LOAD_FP = 7'b0000111, MISC_MEM = 7'b0001111, OP_IMM = 7'b0010011, AUIPC = 7'b0010111, 
               STORE = 7'b0100011, STORE_FP = 7'b0100111, AMO = 7'b0101111, OP = 7'b0110011, LUI = 7'b0110111,
               MADD = 7'b1000011, MSUB = 7'b1000111, NMSUB = 7'b1001011, NMADD = 7'b1001111, OP_FP = 7'b1010011, OP_V = 7'b1010111,
               BRANCH = 7'b1100011, JALR = 7'b1100111, JAL = 7'b1101111, SYSTEM = 7'b1110011, OP_VE = 7'b1110111;

<<<<<<< HEAD
    reg RegWrite, ALUSrc, MemRead, MemWrite, PCSrc, PCSrcType, CSRWrite, IsConditional, BranchInvert, MRet;
=======
    reg RegWrite, ALUSrc, MemRead, MemWrite, PCSrc, PCSrcType, CSRWrite, IsConditional, BranchInvert, MRet, IsEcall, IsEbreak;
>>>>>>> 9257098 (removed vcd files)
    reg [4:0] ALUCtrl;
    reg [2:0] ToReg, Funct3;

    always @* begin
        RegWrite = 0;
        ALUSrc = 0;
        MemRead = 0;
        MemWrite = 0;
        ALUCtrl = ADD;
        PCSrc = 0;
        PCSrcType = 0;
        CSRWrite = 0;
        ToReg = 3'b000;
        IsConditional = 0;
        BranchInvert = 0;
        Funct3 = funct3;
        MRet = 0;
<<<<<<< HEAD
=======
        IsEcall = 0;
        IsEbreak = 0;
>>>>>>> 9257098 (removed vcd files)

        case (opcode)
            OP: begin
                RegWrite = 1;

                case (funct7)
                    7'h00: begin
                        case (funct3)
                            3'h0: ALUCtrl = ADD;
                            3'h1: ALUCtrl = SLL;
                            3'h2: ALUCtrl = SLT;
                            3'h3: ALUCtrl = SLTU;
                            3'h4: ALUCtrl = XOR;
                            3'h5: ALUCtrl = SRL;
                            3'h6: ALUCtrl = OR;
                            3'h7: ALUCtrl = AND;
                        endcase
                    end
                    7'h20: begin
                        case (funct3)
                            3'h0: ALUCtrl = SUB;
                            3'h5: ALUCtrl = SRA;
                            default: ALUCtrl = ADD;
                        endcase
                    end
                    default: ALUCtrl = ADD;
                endcase
            end
            OP_IMM: begin
                RegWrite = 1;
                ALUSrc = 1;

                case (funct3)
                    3'h0: ALUCtrl = ADD;
                    3'h1: ALUCtrl = SLL;
                    3'h2: ALUCtrl = SLT;
                    3'h3: ALUCtrl = SLTU;
                    3'h4: ALUCtrl = XOR;
                    3'h5: begin
                        if (funct7[5] == 1)
                            ALUCtrl = SRA;
                        else
                            ALUCtrl = SRL;
                    end
                    3'h6: ALUCtrl = OR;
                    3'h7: ALUCtrl = AND;
                endcase
            end
            LOAD: begin
                RegWrite = 1;
                ALUSrc = 1;
                MemRead = 1;
                ToReg = 3'b010;
            end
            STORE: begin
                ALUSrc = 1;
                MemWrite = 1;
            end
            BRANCH: begin
                IsConditional = 1;
                case (funct3)
                    3'h0: ALUCtrl = SUB;
                    3'h1: begin ALUCtrl = SUB; BranchInvert = 1; end
                    3'h4: begin ALUCtrl = SLT; BranchInvert = 1; end
                    3'h5: ALUCtrl = SLT;
                    3'h6: begin ALUCtrl = SLTU; BranchInvert = 1; end
                    3'h7: ALUCtrl = SLTU;
                    default: ALUCtrl = SUB;
                endcase
            end
            JAL: begin
                PCSrc = 1;
                RegWrite = 1;
                ToReg = 3'b001;
            end
            JALR: begin
                PCSrc = 1;
                PCSrcType = 1;
                RegWrite = 1;
                ALUSrc = 1;
                ToReg = 3'b001;
            end
            LUI: begin
                RegWrite = 1;
                ToReg = 3'b100;
            end
            AUIPC: begin
                RegWrite = 1;
                ToReg = 3'b011;
            end
            SYSTEM: begin
                case (funct3)
                    3'h1: begin
                        RegWrite = (rd == 5'b0) ? 1'b0 : 1'b1;
                        CSRWrite = 1'b1;
                        ToReg  = (rd == 5'b0)  ? 3'b000 : 3'b101;
                        ALUCtrl = PASS;
                    end
                    3'h2: begin
                        RegWrite = 1'b1;
                        CSRWrite = (rs1 == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                        ALUCtrl = OR;
                    end
                    3'h3: begin
                        RegWrite = 1'b1;
                        CSRWrite = (rs1 == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                        ALUCtrl = ANDN;
                    end
                    3'h5: begin
                        RegWrite = (rd == 5'b0) ? 1'b0 : 1'b1;
                        CSRWrite = 1'b1;
                        ALUSrc   = 1'b1;
                        ToReg  = (rd == 5'b0)  ? 3'b000 : 3'b101;
                        ALUCtrl = PASS2;
                    end
                    3'h6: begin
                        RegWrite = 1'b1;
                        CSRWrite = (rs1 == 5'b0) ? 1'b0 : 1'b1;
                        ALUSrc   = 1'b1;
                        ToReg = 3'b101;
                        ALUCtrl = OR;
                    end
                    3'h7: begin
                        RegWrite = 1'b1;
                        CSRWrite = (rs1 == 5'b0) ? 1'b0 : 1'b1;
                        ALUSrc = 1'b1;
                        ToReg = 3'b101;
                        ALUCtrl = ANDN;
                    end
                    3'h0: begin
                        case (funct12)
<<<<<<< HEAD
=======
                            12'h000: begin
                                IsEcall = 1'b1;
                            end
                            12'h001: begin
                                IsEbreak = 1'b1;
                            end
>>>>>>> 9257098 (removed vcd files)
                            12'h302: begin
                                PCSrc = 1'b1;
                                MRet = 1'b1;
                            end
                            default: begin
                            end
                        endcase
                    end
                endcase
            end
            MISC_MEM: begin
                // nop
            end
            default: begin
                // nop
            end
        endcase
    end

<<<<<<< HEAD
    assign ctrl = {11'b0, MRet,Funct3, BranchInvert, ALUCtrl, ToReg, IsConditional, PCSrcType, PCSrc, CSRWrite, MemRead, MemWrite, ALUSrc, RegWrite};
=======
    assign ctrl = {9'b0, IsEbreak, IsEcall, MRet, Funct3, BranchInvert, ALUCtrl, ToReg, IsConditional, PCSrcType, PCSrc, CSRWrite, MemRead, MemWrite, ALUSrc, RegWrite};
>>>>>>> 9257098 (removed vcd files)

endmodule
