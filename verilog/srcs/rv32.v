module rv32 (
    input wire clk,
    input wire reset,
    output wire [3:0] out
);

    assign out = Regs[15][3:0];

    // memory addresses
    localparam CODE_BASE = 32'h0000_0000;
    localparam CODE_TOP = 32'h0000_3FFF;
    localparam DATA_BASE = 32'h0000_4000;
    localparam DATA_TOP = 32'h0000_7FFF;

    wire in_data_region = (EXMEMALU >= DATA_BASE && EXMEMALU <= DATA_TOP);

    // parameter declaration
    // type definitions
    localparam R_type = 3'b000, I_type = 3'b001, S_type = 3'b010, B_type = 3'b011, U_type = 3'b100, J_type = 3'b101;

    // nop instruction
    localparam NOP = 32'h00000013;

    // opcode definitions
    localparam LOAD = 5'b00000, LOAD_FP = 5'b00001, MISC_MEM = 5'b00011, OP_IMM = 5'b00100, AUIPC = 5'b00101, 
               STORE = 5'b01000, STORE_FP = 5'b01001, AMO = 5'b01011, OP = 5'b01100, LUI = 5'b01101,
               MADD = 5'b10000, MSUB = 5'b10001, NMSUB = 5'b10010, NMADD = 5'b10011, OP_FP = 5'b10100,
               BRANCH = 5'b11000, JALR = 5'b11001, JAL = 5'b11011, SYSTEM = 5'b11100;

    // alu ctrl definitions
    localparam ADD = 5'b00000, SUB = 5'b00001, XOR = 5'b00010, OR = 5'b00011, AND = 5'b00100, SLL = 5'b00101, 
               SRL = 5'b00110, SRA = 5'b00111, SLT = 5'b01000, SLTU = 5'b01001, MUL = 5'b01010, MULH = 5'b01011, 
               MULHU = 5'b01100, MULHSU = 5'b01101, DIV = 5'b01110, DIVU = 5'b01111, REM = 5'b10000, REMU = 5'b10001;

    // register declaration
    (* ram_style = "block" *) reg [31:0] iMem[4095:0];
    (* ram_style = "block" *) reg [31:0] dMem[4095:0];
    reg [31:0] mem_rdata, dMem_preread;
    reg [31:0] Regs[31:0];

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                Regs[i] <= 32'b0;
        end else if (MEMWB_RegWrite && (MEMWBWR != 0)) begin
            Regs[MEMWBWR] <= wr_data;
        end
    end

    initial begin
        $readmemh("program.hex", iMem);
    end

    reg [31:0] PC;
    reg [31:0] IFIDPC, IFIDIR;
    reg [31:0] IDEXPC, IDEXA, IDEXB, IDEXIG, IDEXRET;
    reg IDEX_RegWrite, IDEX_ALUSrc, IDEX_PCSrcType, IDEX_PCSrc, IDEX_MemWrite, IDEX_MemRead, IDEX_CSRWrite, IDEX_IsConditional;
    reg [2:0] IDEX_ToReg, IDEX_Funct3;
    reg [4:0] IDEX_ALUCtrl, IDEXWR;
    reg [4:0] IDEXRS1, IDEXRS2;
    reg [31:0] EXMEMPC, EXMEMALU, EXMEMB, EXMEMIG, EXMEMRET;
    reg [2:0] EXMEM_Funct3;
    reg [1:0] EXMEM_ByteOff;
    reg [4:0] EXMEMRS2, EXMEMWR;
    reg EXMEM_RegWrite, EXMEM_PCSrc, EXMEM_MemWrite, EXMEM_MemRead, EXMEM_CSRWrite;
    reg [2:0] EXMEM_ToReg;
    reg [31:0] MEMWBPC, MEMWBRD, MEMWBALU, MEMWBIG, MEMWBRET;
    reg [4:0] MEMWBWR;
    reg [2:0] MEMWB_Funct3;
    reg [1:0] MEMWB_ByteOff;
    reg MEMWB_RegWrite, MEMWB_CSRWrite, MEMWB_MemRead;
    reg [2:0] MEMWB_ToReg;
    reg [31:0] EXMEMPC_inst, MEMWBPC_inst;

    // next state regs
    reg [31:0] pc_next;
    wire [31:0] wr_data;

    // control signals
    reg RegWrite, ALUSrc, MemWrite, MemRead, CSRWrite, PCSrc, PCSrcType, IsConditional;
    reg [2:0] ToReg;
    reg [4:0] ALUCtrl;

    // fowarding signals
    reg [1:0] ForwardA, ForwardB, ForwardMem;

    // stall logic
    wire jal_flush = IDEX_PCSrc && !IDEX_IsConditional;
    wire hazard_stall = (IDEX_MemRead && (IDEXWR != 0) && !EXMEM_PCSrc && !jal_flush && ((IDEXWR == IFIDIR[19:15]) || (IDEXWR == IFIDIR[24:20])));

    // variables for byte and half word access
    reg [31:0] raw_word, store_data, existing, merged;

    reg [31:0] imem_rdata;

    // Separate BRAM read block
    always @(posedge clk) begin
        if (reset)
            imem_rdata <= NOP;
        else
            imem_rdata <= iMem[(PC - CODE_BASE) >> 2];
    end

    // stage 1 register assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
            IFIDIR <= NOP;
            IFIDPC <= 0;
        end else if (hazard_stall) begin
        end else begin
            PC <= pc_next;
            if (EXMEM_PCSrc || jal_flush)
                IFIDIR <= NOP;
            else
                IFIDIR <= imem_rdata;
            IFIDPC <= PC;
        end
    end

    // stage 2 register assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IDEX_RegWrite <= 0;
            IDEX_ALUSrc <= 0; 
            IDEX_IsConditional <= 0;
            IDEX_PCSrcType <= 0;
            IDEX_PCSrc <= 0;
            IDEX_MemWrite <= 0;
            IDEX_MemRead <= 0;
            IDEX_CSRWrite <= 0;
            IDEX_ToReg <= 3'b000;
            IDEX_ALUCtrl <= 5'b00000;
            IDEXA <= 0;
            IDEXB <= 0;
            IDEXIG <= 0;
            IDEXWR <= 0;
        end else if (hazard_stall || EXMEM_PCSrc || jal_flush) begin
            IDEX_RegWrite <= 0;
            IDEX_ALUSrc <= 0; 
            IDEX_IsConditional <= 0;
            IDEX_PCSrcType <= 0;
            IDEX_PCSrc <= 0;
            IDEX_MemWrite <= 0;
            IDEX_MemRead <= 0;
            IDEX_CSRWrite <= 0;
            IDEX_ToReg <= 3'b000;
            IDEX_ALUCtrl <= 5'b00000;
        end else begin
            IDEX_RegWrite <= RegWrite;
            IDEX_ALUSrc <= ALUSrc; 
            IDEX_PCSrcType <= PCSrcType;
            IDEX_IsConditional <= IsConditional;
            IDEX_PCSrc <= PCSrc;
            IDEX_MemWrite <= MemWrite;
            IDEX_MemRead <= MemRead;
            IDEX_CSRWrite <= CSRWrite;
            IDEX_ToReg <= ToReg;
            IDEX_ALUCtrl <= ALUCtrl;
            IDEXPC <= IFIDPC;
            IDEXA <= Regs[IFIDIR[19:15]];
            IDEXB <= Regs[IFIDIR[24:20]];
            IDEXIG <= ImmGen;
            IDEXWR <= IFIDIR[11:7];
            IDEXRS1 <= IFIDIR[19:15];
            IDEXRS2 <= IFIDIR[24:20];
            IDEXRET <= IFIDPC + 4;
            IDEX_Funct3 <= funct3;
        end
    end

    // stage 3 register assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            EXMEM_RegWrite <= 0;
            EXMEM_PCSrc <= 0;
            EXMEM_MemWrite <= 0;
            EXMEM_MemRead <= 0;
            EXMEM_CSRWrite <= 0;
            EXMEM_ToReg <= 0;
            EXMEMALU <= 0;
            EXMEMB <= 0;
            EXMEMWR <= 0;
            EXMEMIG <= 0;
        end else if (EXMEM_PCSrc) begin
            EXMEM_MemRead <= 0;
            EXMEM_MemWrite <= 0;
            EXMEM_RegWrite <= 0;
            EXMEM_PCSrc <= 0;
        end else begin
            EXMEM_RegWrite <= IDEX_RegWrite; 
            EXMEM_MemWrite <= IDEX_MemWrite;
            EXMEM_MemRead <= IDEX_MemRead;
            EXMEM_CSRWrite <= IDEX_CSRWrite;
            EXMEM_ToReg <= IDEX_ToReg;
            EXMEMPC_inst <= IDEXPC;
            if (IDEX_PCSrcType)
                EXMEMPC <= (alu1 + IDEXIG) & ~32'b1;
            else
                EXMEMPC <= IDEXPC + IDEXIG;
            if (IDEX_IsConditional) begin
                case (IDEX_Funct3)
                    3'h0: EXMEM_PCSrc <= (alu == 0);    // BEQ
                    3'h1: EXMEM_PCSrc <= (alu != 0);   // BNE
                    3'h4: EXMEM_PCSrc <= (alu != 0);   // BLT:  SLT==1 means less than
                    3'h5: EXMEM_PCSrc <= (alu == 0);    // BGE:  SLT==0 means greater or equal
                    3'h6: EXMEM_PCSrc <= (alu != 0);   // BLTU
                    3'h7: EXMEM_PCSrc <= (alu == 0);    // BGEU
                    default: EXMEM_PCSrc <= 0;
                endcase
            end else begin
                EXMEM_PCSrc <= IDEX_PCSrc;
            end
            EXMEMALU <= alu;
            EXMEMB <= IDEXB;
            EXMEMWR <= IDEXWR;
            EXMEMRS2 <= IDEXRS2;
            EXMEMIG <= IDEXIG;
            EXMEMRET <= IDEXRET;
            EXMEM_Funct3 <= IDEX_Funct3;
            EXMEM_ByteOff <= alu[1:0];
            dMem_preread <= dMem[(alu - DATA_BASE) >> 2];
        end
    end

    // ============================================================
    // Dedicated BRAM block for dMem — replaces the scattered
    // read/write logic that was split across stage 4 and the
    // standalone always @(posedge clk) block.
    // ============================================================

    // Write port — synchronous, unconditional structure so Vivado
    // sees a clean simple-dual-port BRAM write.
    always @(posedge clk) begin
        if (EXMEM_MemWrite && in_data_region) begin
            case (ForwardMem)
                2'b01:   store_data = wr_data;
                2'b10:   store_data = mem_rdata;
                default: store_data = EXMEMB;
            endcase

            existing = dMem_preread; // read-modify-write

            case (EXMEM_Funct3)
                3'h0: begin // SB
                    case (EXMEM_ByteOff)
                        2'b00: merged = {existing[31:8],  store_data[7:0]};
                        2'b01: merged = {existing[31:16], store_data[7:0],  existing[7:0]};
                        2'b10: merged = {existing[31:24], store_data[7:0],  existing[15:0]};
                        2'b11: merged = {store_data[7:0], existing[23:0]};
                    endcase
                end
                3'h1: begin // SH
                    case (EXMEM_ByteOff[1])
                        1'b0: merged = {existing[31:16], store_data[15:0]};
                        1'b1: merged = {store_data[15:0], existing[15:0]};
                    endcase
                end
                3'h2:    merged = store_data; // SW
                default: merged = store_data;
            endcase

            dMem[(EXMEMALU - DATA_BASE) >> 2] <= merged;
        end
    end

    // Read port — synchronous, unconditional enable-style read.
    // Vivado infers this as a BRAM read port with EN.
    // The registered output matches "read-first" or "write-first"
    // BRAM primitives depending on your synthesis settings.
    always @(posedge clk) begin
        if (reset)
            mem_rdata <= 32'b0;
        else if (EXMEM_MemRead)
            mem_rdata <= dMem[(EXMEMALU - DATA_BASE) >> 2];
    end

    // stage 4 register assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MEMWB_RegWrite <= 0;
            MEMWB_CSRWrite <= 0;
            MEMWB_MemRead <= 0;
            MEMWB_ToReg <= 0;
            MEMWBALU <= 0;
            MEMWBWR <= 0;
            MEMWBIG <= 0;
            MEMWBPC <= 0;
        end else begin
            MEMWB_RegWrite <= EXMEM_RegWrite; 
            MEMWB_CSRWrite <= EXMEM_CSRWrite;
            MEMWB_MemRead <= EXMEM_MemRead;
            MEMWB_ToReg <= EXMEM_ToReg;
            MEMWBALU <= EXMEMALU;
            MEMWBWR <= EXMEMWR;
            MEMWBIG <= EXMEMIG;
            MEMWBPC <= EXMEMPC;
            MEMWBRET <= EXMEMRET;
            MEMWBPC_inst <= EXMEMPC_inst;
            MEMWB_Funct3 <= EXMEM_Funct3;
            MEMWB_ByteOff <= EXMEM_ByteOff;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            MEMWBRD <= 32'b0;
        end else if (MEMWB_MemRead) begin
            case (MEMWB_Funct3)
                3'h0: begin // LB
                    case (MEMWB_ByteOff)
                        2'b00: MEMWBRD <= {{24{mem_rdata[7]}},  mem_rdata[7:0]};
                        2'b01: MEMWBRD <= {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                        2'b10: MEMWBRD <= {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                        2'b11: MEMWBRD <= {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                    endcase
                end
                3'h1: begin // LH
                    case (MEMWB_ByteOff[1])
                        1'b0: MEMWBRD <= {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                        1'b1: MEMWBRD <= {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                    endcase
                end
                3'h2: MEMWBRD <= mem_rdata; // LW
                3'h4: begin // LBU
                    case (MEMWB_ByteOff)
                        2'b00: MEMWBRD <= {24'b0, mem_rdata[7:0]};
                        2'b01: MEMWBRD <= {24'b0, mem_rdata[15:8]};
                        2'b10: MEMWBRD <= {24'b0, mem_rdata[23:16]};
                        2'b11: MEMWBRD <= {24'b0, mem_rdata[31:24]};
                    endcase
                end
                3'h5: begin // LHU
                    case (MEMWB_ByteOff[1])
                        1'b0: MEMWBRD <= {16'b0, mem_rdata[15:0]};
                        1'b1: MEMWBRD <= {16'b0, mem_rdata[31:16]};
                    endcase
                end
                default: MEMWBRD <= mem_rdata;
            endcase
        end else begin
            MEMWBRD <= 32'b0;
        end
    end

    // ImmGen creation
    reg [31:0] ImmGen;
    reg [2:0] type;

    // type assignment
    always @* begin
        case (opcode)
            OP:     type = R_type;
            OP_IMM: type = I_type;
            LOAD:   type = I_type;
            STORE:  type = S_type;
            BRANCH: type = B_type;
            JAL:    type = J_type;
            JALR:   type = I_type;
            LUI:    type = U_type;
            AUIPC:  type = U_type;
            SYSTEM: type = I_type;
            default: type = R_type;
        endcase
    end

    always @* begin
        case (type)
            I_type: ImmGen = {{20{IFIDIR[31]}}, IFIDIR[31:20]};
            S_type: ImmGen = {{20{IFIDIR[31]}}, IFIDIR[31:25], IFIDIR[11:7]};
            B_type: ImmGen = {{20{IFIDIR[31]}}, IFIDIR[7], IFIDIR[30:25], IFIDIR[11:8], 1'b0};
            U_type: ImmGen = {IFIDIR[31:12], 12'b0};
            J_type: ImmGen = {{12{IFIDIR[31]}}, IFIDIR[19:12], IFIDIR[20], IFIDIR[30:25], IFIDIR[24:21], 1'b0};
            default: ImmGen = 32'b0;
        endcase
    end

    // alu
    reg [31:0] alu, alu1, alu2;
    
    always @* begin
        case (IDEX_ALUCtrl)
            AND: alu = alu1 & alu2;
            OR: alu = alu1 | alu2;
            ADD: alu = alu1 + alu2;
            XOR: alu = alu1 ^ alu2;
            SLL: alu = alu1 << alu2[4:0];
            SRL: alu = alu1 >> alu2[4:0];
            SUB: alu = alu1 - alu2;
            SRA: alu = $signed(alu1) >>> alu2[4:0];
            SLT: alu = ($signed(alu1) < $signed(alu2)) ? 1 : 0;
            SLTU: alu = (alu1 < alu2) ? 1 : 0;
            default: alu = 32'b0;
        endcase
    end

    // alu inputs control logic
    always @* begin
        case (ForwardA)
            2'b00: alu1 = IDEXA;
            2'b01: alu1 = wr_data;
            2'b10: alu1 = EXMEMALU;
            2'b11: alu1 = mem_rdata;
        endcase
        if (IDEX_ALUSrc)
            alu2 = IDEXIG;
        else
            case (ForwardB)
                2'b00: alu2 = IDEXB;
                2'b01: alu2 = wr_data;
                2'b10: alu2 = EXMEMALU;
                2'b11: alu2 = mem_rdata;
            endcase
    end

    // pc_next control logic
    always @* begin
        if (EXMEM_PCSrc)
            pc_next = EXMEMPC;
        else if (jal_flush && !IDEX_PCSrcType)
            pc_next = IDEXPC + IDEXIG;
        else if (jal_flush && IDEX_PCSrcType)
            pc_next = (alu1 + IDEXIG) & ~32'b1;
        else
            pc_next = PC + 4;
    end

    assign wr_data = (MEMWB_ToReg == 3'b000) ? MEMWBALU :
                     (MEMWB_ToReg == 3'b001) ? MEMWBRET :
                     (MEMWB_ToReg == 3'b010) ? MEMWBRD :
                     (MEMWB_ToReg == 3'b011) ? MEMWBPC_inst + MEMWBIG :
                     (MEMWB_ToReg == 3'b100) ? MEMWBIG :
                                         32'b0;


    wire [4:0] opcode = IFIDIR[6:2];
    wire [2:0] funct3 = IFIDIR[14:12];
    wire [6:0] funct7 = IFIDIR[31:25];
    // control logic
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
                    3'h1: ALUCtrl = SUB;
                    3'h4: ALUCtrl = SLT;
                    3'h5: ALUCtrl = SLT;
                    3'h6: ALUCtrl = SLTU;
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
                        RegWrite = 1'b1;
                        CSRWrite = 1'b1;
                        ToReg  = (IFIDIR[11:7] == 5'b0)  ? 3'b000 : 3'b101;
                    end
                    3'h2: begin
                        RegWrite = 1'b1;
                        CSRWrite = (IFIDIR[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                    end
                    3'h3: begin
                        RegWrite = 1'b1;
                        CSRWrite = (IFIDIR[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                    end
                    3'h5: begin
                        RegWrite = 1'b1;
                        CSRWrite = 1'b1;
                        ToReg  = (IFIDIR[11:7] == 5'b0)  ? 3'b000 : 3'b101;
                    end
                    3'h6: begin
                        RegWrite = 1'b1;
                        CSRWrite = (IFIDIR[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                    end
                    3'h7: begin
                        RegWrite = 1'b1;
                        CSRWrite = (IFIDIR[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        ToReg = 3'b101;
                    end
                    3'h0: begin
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

    // forwarding logic
    always @* begin
        if (EXMEM_RegWrite && (EXMEMWR != 0) && (EXMEMWR == IDEXRS1))
            ForwardA = 2'b10;
        else if (MEMWB_RegWrite && (MEMWBWR != 0) && (MEMWBWR == IDEXRS1) && !MEMWB_MemRead)
            ForwardA = 2'b01;
        else if (MEMWB_RegWrite && (MEMWBWR != 0) && (MEMWBWR == IDEXRS1) && MEMWB_MemRead)
            ForwardA = 2'b11;
        else
            ForwardA = 2'b00;

        if (EXMEM_RegWrite && (EXMEMWR != 0) && (EXMEMWR == IDEXRS2))
            ForwardB = 2'b10;
        else if (MEMWB_RegWrite && (MEMWBWR != 0) && (MEMWBWR == IDEXRS2) && !MEMWB_MemRead)
            ForwardB = 2'b01;
        else if (MEMWB_RegWrite && (MEMWBWR != 0) && (MEMWBWR == IDEXRS2) && MEMWB_MemRead)
            ForwardB = 2'b11;
        else
            ForwardB = 2'b00;


        if (MEMWB_RegWrite && (MEMWBWR == EXMEMRS2) && (MEMWBWR != 0) && !MEMWB_MemRead)
            ForwardMem = 2'b01;
        else if (MEMWB_RegWrite && (MEMWBWR == EXMEMRS2) && (MEMWBWR != 0) && MEMWB_MemRead)
            ForwardMem = 2'b10;
        else
            ForwardMem = 0;
    end
endmodule
