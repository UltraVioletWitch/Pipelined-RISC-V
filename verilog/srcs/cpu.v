module cpu(
    input wire clk,
    input wire reset,
    output wire [3:0] out
);

    // parameter declarations
    localparam NOP = 32'h0000_0013;

    // opcode definitions
    localparam LOAD = 7'b0000011, LOAD_FP = 7'b0000111, MISC_MEM = 7'b0001111, OP_IMM = 7'b0010011, AUIPC = 7'b0010111, 
               STORE = 7'b0100011, STORE_FP = 7'b0100111, AMO = 7'b0101111, OP = 7'b0110011, LUI = 7'b0110111,
               MADD = 7'b1000011, MSUB = 7'b1000111, NMSUB = 7'b1001011, NMADD = 7'b1001111, OP_FP = 7'b1010011, OP_V = 7'b1010111,
               BRANCH = 7'b1100011, JALR = 7'b1100111, JAL = 7'b1101111, SYSTEM = 7'b1110011, OP_VE = 7'b1110111;

    // type definitions
    localparam R_type = 3'b000, I_type = 3'b001, S_type = 3'b010, B_type = 3'b011, U_type = 3'b100, J_type = 3'b101;

    // Control Signal Assignments
    localparam RegWrite = 5'd0, ALUSrc = 5'd1, MemWrite = 5'd2, MemRead = 5'd3, CSRWrite = 5'd4, PCSrc = 5'd5, PCSrcType = 5'd6, IsConditional = 5'd7,
               ToRegStart = 5'd8, ToRegEnd = 5'd10, ALUCtrlStart = 5'd11, ALUCtrlEnd = 5'd15, BranchInvert = 5'd16;

    // memory definitions
    (* ram_style = "block" *) reg [31:0] iMem [4095:0];
    (* ram_style = "block" *) reg [31:0] dMem [8191:0];
    reg [31:0] Regs[31:0];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            Regs[i] = 32'b0;
    end

    initial begin
        $readmemh("program.hex", iMem);
    end

    reg [31:0] PC;
    reg [31:0] pc_next;
    reg [31:0] IFID_PC, IFID_IR;
    reg [31:0] IDEX_IG, IDEX_PC, IDEX_Ctrl;
    reg [4:0] IDEX_RS1_ADDR, IDEX_RS2_ADDR, IDEX_RD;
    // Instruction Decode Module
    wire [4:0] rs1    = IFID_IR[19:15];
    wire [4:0] rs2    = IFID_IR[24:20];
    wire [4:0] rd     = IFID_IR[11:7];
    wire [2:0] funct3 = IFID_IR[14:12];
    wire [6:0] funct7 = IFID_IR[31:25];
    wire [6:0] opcode = IFID_IR[6:0];

    // Immediate Generation
    reg [31:0] ImmGen;
    wire [31:0] ctrl;
    reg [31:0] alu_in1, alu_in2;
    reg [1:0] ForwardA, ForwardB, ForwardMem;
    wire zero;
    wire [31:0] alu_result;
    reg [31:0] EXMEM_RS2, EXMEM_ALU, EXMEM_PC, EXMEM_IG, EXMEM_Ctrl;
    reg [4:0] EXMEM_RD, EXMEM_RS2_ADDR;
    reg EXMEM_Z;
    reg [31:0] MEMWB_LD, MEMWB_ALU, MEMWB_PC, MEMWB_IG, MEMWB_Ctrl;
    reg [4:0] MEMWB_RD;
    reg MEMWB_Z;
    wire [31:0] mem_addr = EXMEM_ALU;
    reg [31:0] mem_rdata, store_data;
    wire [31:0] wr_data;

    // hazard and flush detection
    wire jal_flush = IDEX_Ctrl[PCSrc] && !IDEX_Ctrl[IsConditional];
    wire load_hazard = (IDEX_Ctrl[MemRead] && (IDEX_RD != 0) && ((IDEX_RD == rs1) || (IDEX_RD == rs2)));
    wire branch_taken = EXMEM_Ctrl[IsConditional] && (EXMEM_Z ^ EXMEM_Ctrl[BranchInvert]);

    // Program Counter Calculation Module
    always @* begin
        if (branch_taken)
            pc_next = EXMEM_PC + EXMEM_IG;
        else if (jal_flush && !IDEX_Ctrl[PCSrcType])
            pc_next = IDEX_PC + IDEX_IG;
        else if (jal_flush && IDEX_Ctrl[PCSrcType])
            pc_next = (Regs[IDEX_RS1_ADDR] + IDEX_IG) & ~32'b1;
        else
            pc_next = PC + 4;
    end

    // PC assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
        end else if (!load_hazard) begin
            PC <= pc_next;
        end
    end



    // IF/ID assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IFID_PC <= 32'b0;
            IFID_IR <= NOP;
        end else if (jal_flush || branch_taken) begin
            IFID_IR <= NOP;
            IFID_PC <= 32'b0;
        end else if (!load_hazard) begin
            IFID_PC <= PC;
            IFID_IR <= iMem[PC >> 2];
        end
    end


    always @* begin
        case (opcode)
            OP_IMM, LOAD, JALR, SYSTEM: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[31:20]};
            STORE: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[31:25], IFID_IR[11:7]};
            BRANCH: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[7], IFID_IR[30:25], IFID_IR[11:8], 1'b0};
            LUI, AUIPC: ImmGen = {IFID_IR[31:12], 12'b0};
            JAL: ImmGen = {{12{IFID_IR[31]}}, IFID_IR[19:12], IFID_IR[20], IFID_IR[30:25], IFID_IR[24:21], 1'b0};
            default: ImmGen = 32'b0;
        endcase
    end

    // Control Module

    control_module cm1 (
        .ctrl(ctrl),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1(rs1),
        .rd(rd)
    );

    // ID/EX assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IDEX_RS1_ADDR  <= 5'b0;
            IDEX_RS2_ADDR  <= 5'b0;
            IDEX_RD   <= 5'b0;
            IDEX_IG   <= 32'b0;
            IDEX_PC   <= 32'b0;
            IDEX_Ctrl <= 32'b0;
        end else if (jal_flush || branch_taken || load_hazard) begin
            IDEX_Ctrl <= 0;
            IDEX_RD <= 0;
        end else begin
            IDEX_RS1_ADDR  <= rs1;
            IDEX_RS2_ADDR  <= rs2;
            IDEX_RD   <= rd;
            IDEX_IG   <= ImmGen;
            IDEX_PC   <= IFID_PC;
            IDEX_Ctrl <= ctrl;
        end
    end


    // forwarding logic (will implement later)
    always @* begin
        case (ForwardA)
            2'b00: alu_in1 = Regs[IDEX_RS1_ADDR];
            2'b01: alu_in1 = wr_data;
            2'b10: alu_in1 = EXMEM_ALU;
            2'b11: alu_in1 = MEMWB_LD;
        endcase
        if (IDEX_Ctrl[ALUSrc])
            alu_in2 = IDEX_IG;
        else
            case (ForwardB)
                2'b00: alu_in2 = Regs[IDEX_RS2_ADDR];
                2'b01: alu_in2 = wr_data;
                2'b10: alu_in2 = EXMEM_ALU;
                2'b11: alu_in2 = MEMWB_LD;
            endcase
    end

    always @* begin
        if (EXMEM_Ctrl[RegWrite] && (EXMEM_RD != 0) && (EXMEM_RD == IDEX_RS1_ADDR))
            ForwardA = 2'b10;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS1_ADDR) && !MEMWB_Ctrl[MemRead])
            ForwardA = 2'b01;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS1_ADDR) && MEMWB_Ctrl[MemRead])
            ForwardA = 2'b11;
        else
            ForwardA = 2'b00;

        if (EXMEM_Ctrl[RegWrite] && (EXMEM_RD != 0) && (EXMEM_RD == IDEX_RS2_ADDR))
            ForwardB = 2'b10;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS2_ADDR) && !MEMWB_Ctrl[MemRead])
            ForwardB = 2'b01;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS2_ADDR) && MEMWB_Ctrl[MemRead])
            ForwardB = 2'b11;
        else
            ForwardB = 2'b00;


        if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD == EXMEM_RS2_ADDR) && (MEMWB_RD != 0) && !MEMWB_Ctrl[MemRead])
            ForwardMem = 2'b01;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD == EXMEM_RS2_ADDR) && (MEMWB_RD != 0) && MEMWB_Ctrl[MemRead])
            ForwardMem = 2'b10;
        else
            ForwardMem = 0;
    end



    // EX(ALU) stage module
    alu_module alu1 (
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .alu_ctrl(IDEX_Ctrl[ALUCtrlEnd:ALUCtrlStart]),
        .zero(zero),
        .alu_result(alu_result)
    );


    // EX/MEM assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            EXMEM_ALU <= 32'b0;
            EXMEM_PC <= 32'b0;
            EXMEM_IG <= 32'b0;
            EXMEM_RS2 <= 32'b0;
            EXMEM_RD <= 5'b0;
            EXMEM_RS2_ADDR <= 5'b0;
            EXMEM_Z <= 1'b0;
            EXMEM_Ctrl <= 32'b0;
        end else if (jal_flush || branch_taken) begin
            EXMEM_Ctrl <= 32'b0;
        end else begin
            EXMEM_ALU <= alu_result;
            EXMEM_PC <= IDEX_PC;
            EXMEM_IG <= IDEX_IG;
            EXMEM_RS2 <= Regs[IDEX_RS2_ADDR];
            EXMEM_RD <= IDEX_RD;
            EXMEM_RS2_ADDR <= IDEX_RS2_ADDR;
            EXMEM_Z <= zero;
            EXMEM_Ctrl <= IDEX_Ctrl;
        end
    end



    always @* begin
        case (ForwardMem)
            2'b01: store_data = wr_data;
            2'b10: store_data = MEMWB_LD;
            default: store_data = EXMEM_RS2;
        endcase
    end

    // MEM Stage
    always @(posedge clk) begin
        if (EXMEM_Ctrl[MemRead])
            mem_rdata <= dMem[mem_addr >> 2];
        if (EXMEM_Ctrl[MemWrite])
            dMem[mem_addr >> 2] <= store_data;
    end


    // MEM/WB assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MEMWB_LD <= 32'b0;
            MEMWB_RD <= 5'b0;
            MEMWB_ALU <= 32'b0;
            MEMWB_PC <= 32'b0;
            MEMWB_IG <= 32'b0;
            MEMWB_Z <= 1'b0;
            MEMWB_Ctrl <= 32'b0;
        end else if (!jal_flush && !branch_taken) begin
            MEMWB_LD <= mem_rdata;
            MEMWB_RD <= EXMEM_RD;
            MEMWB_ALU <= EXMEM_ALU;
            MEMWB_PC <= EXMEM_PC;
            MEMWB_IG <= EXMEM_IG;
            MEMWB_Z <= EXMEM_Z;
            MEMWB_Ctrl <= EXMEM_Ctrl;
        end else 
            MEMWB_Ctrl <= 32'b0;
    end

    // Write Back Logic Module
    write_back_module wb (
        .rd(MEMWB_LD),
        .alu(MEMWB_ALU),
        .pc(MEMWB_PC),
        .ImmGen(MEMWB_IG),
        .ToReg(MEMWB_Ctrl[ToRegEnd:ToRegStart]),
        .wr_data(wr_data)
    );

    // Write Back
    always @(posedge clk) begin
        if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0))
            Regs[MEMWB_RD] <= wr_data;
        Regs[0] <= 32'b0;
    end

    assign out = Regs[15][3:0];

endmodule
