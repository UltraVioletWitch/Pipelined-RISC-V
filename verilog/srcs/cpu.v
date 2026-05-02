module cpu(
    input wire clk,
    input wire reset,
    input wire [31:0] mip,
    output wire we,
    output wire [31:0] mem_addr_r,
    output wire [31:0] mem_addr_w,
    output wire [31:0] din,
    input wire [31:0] dout,
    output reg [31:0] EXMEM_Ctrl,
    output reg [31:0] IDEX_Ctrl
);

    // parameter declarations
    localparam NOP = 32'h0000_0013;

    // opcode definitions
    localparam LOAD = 7'b0000011, LOAD_FP = 7'b0000111, MISC_MEM = 7'b0001111, OP_IMM = 7'b0010011, AUIPC = 7'b0010111, 
               STORE = 7'b0100011, STORE_FP = 7'b0100111, AMO = 7'b0101111, OP = 7'b0110011, LUI = 7'b0110111,
               MADD = 7'b1000011, MSUB = 7'b1000111, NMSUB = 7'b1001011, NMADD = 7'b1001111, OP_FP = 7'b1010011, OP_V = 7'b1010111,
               BRANCH = 7'b1100011, JALR = 7'b1100111, JAL = 7'b1101111, SYSTEM = 7'b1110011, OP_VE = 7'b1110111;

    // machine mode CSRs
    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mie;
    reg [31:0] misa;
    reg [31:0] mhartid;
    reg [31:0] mvendorid;
    reg [31:0] marchid;
    reg [31:0] mimpid;
    reg [31:0] mtval;
    reg [31:0] mcounteren;

    initial begin
        mstatus    = 32'b0;
        mtvec      = 32'b0;
        mscratch   = 32'b0;
        mepc       = 32'b0;
        mcause     = 32'b0;
        mie        = 32'b0;
        misa       = 32'h40001100;
        mhartid    = 32'b0;
        mvendorid  = 32'b0;
        marchid    = 32'b0;
        mimpid     = 32'b0;
        mtval      = 32'b0;
        mcounteren = 32'b0;
    end

    reg [31:0] csr_rdata;

    wire interrupt_pending = mstatus[3] && |(mie & mip);

    wire [31:0] interrupt_cause =
                (mip[11] & mie[11]) ? 32'h8000000B :     // machine external interrupt
                (mip[7]  & mie[7])  ? 32'h80000007 :     // machine timer interrupt
                                      32'h80000003;      // machine software interrupt



    // type definitions
    localparam R_type = 3'b000, I_type = 3'b001, S_type = 3'b010, B_type = 3'b011, U_type = 3'b100, J_type = 3'b101;

    // Control Signal Assignments
    localparam RegWrite = 5'd0, ALUSrc = 5'd1, MemWrite = 5'd2, MemRead = 5'd3, CSRWrite = 5'd4, PCSrc = 5'd5, PCSrcType = 5'd6, IsConditional = 5'd7,
               ToRegStart = 5'd8, ToRegEnd = 5'd10, ALUCtrlStart = 5'd11, ALUCtrlEnd = 5'd15, BranchInvert = 5'd16, Funct3_Start = 5'd17, Funct3_End = 5'd19, MRet = 5'd20;

    // memory definitions
    reg [31:0] Regs[31:0];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            Regs[i] = 32'b0;
    end

    reg [31:0] PC;
    reg [31:0] pc_next;
    reg [31:0] IFID_PC, IFID_IR;
    reg [31:0] IDEX_IG, IDEX_PC, IDEX_CSR;
    reg [11:0] IDEX_CSR_ADDR;
    reg [4:0] IDEX_RS1_ADDR, IDEX_RS2_ADDR, IDEX_RD;
    // Instruction Decode Module
    wire [4:0] rs1    = IFID_IR[19:15];
    wire [4:0] rs2    = IFID_IR[24:20];
    wire [4:0] rd     = IFID_IR[11:7];
    wire [2:0] funct3 = IFID_IR[14:12];
    wire [6:0] funct7 = IFID_IR[31:25];
    wire [11:0] funct12 = IFID_IR[31:20];
    wire [6:0] opcode = IFID_IR[6:0];

    // Immediate Generation
    reg [31:0] ImmGen;
    wire [31:0] ctrl;
    reg [31:0] alu_in1, alu_in2;
    reg [1:0] ForwardA, ForwardB, ForwardMem;
    wire zero;
    wire [31:0] alu_result;
    reg [31:0] EXMEM_RS2, EXMEM_ALU, EXMEM_PC, EXMEM_IG, EXMEM_LD, EXMEM_CSR;
    reg [11:0] EXMEM_CSR_ADDR;
    reg [4:0] EXMEM_RD, EXMEM_RS2_ADDR;
    reg EXMEM_Z;
    reg [31:0] MEMWB_LD, MEMWB_ALU, MEMWB_PC, MEMWB_IG, MEMWB_CSR, MEMWB_Ctrl;
    reg [4:0] MEMWB_RD;
    reg MEMWB_Z;
    reg [31:0] store_data;
    wire [31:0] mem_rdata;
    wire [31:0] wr_data;
    reg [31:0] mem_rrdata, rrdata;
    reg sw_then_ld0, sw_then_ld1, sw_then_ld2;
    wire [31:0] wb_rd = (sw_then_ld1) ? rrdata : MEMWB_LD;

    // hazard and flush detection
    wire jal_flush = IDEX_Ctrl[PCSrc] && !IDEX_Ctrl[IsConditional];
    wire load_hazard = (EXMEM_Ctrl[MemRead] && (EXMEM_RD != 0) && ((EXMEM_RD == IDEX_RS1_ADDR) || (EXMEM_RD == IDEX_RS2_ADDR)));
    wire branch_taken = EXMEM_Ctrl[IsConditional] && (EXMEM_Z ^ EXMEM_Ctrl[BranchInvert]);
    wire take_interrupt = interrupt_pending && !load_hazard && !branch_taken && !jal_flush;

    wire flush = jal_flush || branch_taken || take_interrupt;
    wire stall = load_hazard;

    assign we = EXMEM_Ctrl[MemWrite] && (EXMEM_ALU >= 32'h4000);
    assign din = store_data;
    assign mem_addr_r = alu_result;
    assign mem_addr_w = EXMEM_ALU;
    wire [31:0] i_next;

    /*
    block_ram dMem (
        .clk(clk),
        .we(we),
        .addr_r(mem_addr_r),
        .addr_w(mem_addr_w),
        .din(din),
        .dout(dout)
    );
    */

    instr_rom iMem (
        .clk(clk),
        .rst(reset),
        .en(!load_hazard),
        .addr(pc_next >> 2),
        .dout(i_next)
    );

    // Program Counter Calculation Module
    always @* begin
        if (take_interrupt)
            pc_next = mtvec;
        else if (IDEX_Ctrl[MRet])
            pc_next = mepc;
        else if (branch_taken)
            pc_next = EXMEM_PC + EXMEM_IG;
        else if (jal_flush && !IDEX_Ctrl[PCSrcType])
            pc_next = IDEX_PC + IDEX_IG;
        else if (jal_flush && IDEX_Ctrl[PCSrcType])
            pc_next = (alu_in1 + IDEX_IG) & ~32'b1;
        else
            pc_next = PC + 4;
    end

    // PC assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
        end else if (!stall) begin
            PC <= pc_next;
        end
    end


    // IF/ID assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IFID_PC <= 32'b0;
            IFID_IR <= NOP;
        end else if (flush) begin
            IFID_IR <= NOP;
            IFID_PC <= 32'b0;
        end else if (!stall) begin
            IFID_PC <= PC;
            IFID_IR <= i_next;
        end
    end


    always @* begin
        case (opcode)
            OP_IMM, LOAD, JALR: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[31:20]};
            STORE: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[31:25], IFID_IR[11:7]};
            BRANCH: ImmGen = {{20{IFID_IR[31]}}, IFID_IR[7], IFID_IR[30:25], IFID_IR[11:8], 1'b0};
            LUI, AUIPC: ImmGen = {IFID_IR[31:12], 12'b0};
            JAL: ImmGen = {{12{IFID_IR[31]}}, IFID_IR[19:12], IFID_IR[20], IFID_IR[30:25], IFID_IR[24:21], 1'b0};
            SYSTEM: ImmGen = {27'b0, IFID_IR[19:15]};
            default: ImmGen = 32'b0;
        endcase
    end

    // Control Module

    control_module cm1 (
        .ctrl(ctrl),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .funct12(funct12),
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
            IDEX_CSR   <= 32'b0;
            IDEX_CSR_ADDR  <= 12'b0;
            IDEX_Ctrl <= 32'b0;
        end else if (flush) begin
            IDEX_Ctrl <= 0;
            IDEX_RD <= 0;
        end else if (!stall) begin
            IDEX_RS1_ADDR  <= rs1;
            IDEX_RS2_ADDR  <= rs2;
            IDEX_RD   <= rd;
            IDEX_IG   <= ImmGen;
            IDEX_PC   <= IFID_PC;
            IDEX_CSR   <= csr_rdata;
            IDEX_CSR_ADDR  <= funct12;
            IDEX_Ctrl <= ctrl;
        end
    end

    wire [31:0] exmem_wr_data;
    write_back_module wb_fwd (
        .rd(32'b0),
        .alu(EXMEM_ALU),
        .pc(EXMEM_PC),
        .ImmGen(EXMEM_IG),
        .csr_reg(EXMEM_CSR),
        .ToReg(EXMEM_Ctrl[ToRegEnd:ToRegStart]),
        .wr_data(exmem_wr_data)
    );

    wire csr_modify_op = IDEX_Ctrl[CSRWrite] && 
                     (IDEX_Ctrl[Funct3_End:Funct3_Start] == 3'h2 || 
                      IDEX_Ctrl[Funct3_End:Funct3_Start] == 3'h3 ||
                      IDEX_Ctrl[Funct3_End:Funct3_Start] == 3'h6 ||
                      IDEX_Ctrl[Funct3_End:Funct3_Start] == 3'h7);
    always @* begin
        if (csr_modify_op)
            alu_in1 = IDEX_CSR;
        else
            case (ForwardA)
                2'b00: alu_in1 = Regs[IDEX_RS1_ADDR];
                2'b01: alu_in1 = wr_data;
                2'b10: alu_in1 = exmem_wr_data;
                2'b11: alu_in1 = MEMWB_LD;
            endcase
        if (IDEX_Ctrl[ALUSrc])
            alu_in2 = IDEX_IG;
        else
            case (ForwardB)
                2'b00: alu_in2 = Regs[IDEX_RS2_ADDR];
                2'b01: alu_in2 = wr_data;
                2'b10: alu_in2 = exmem_wr_data;
                2'b11: alu_in2 = MEMWB_LD;
            endcase
    end

    always @* begin
        if (EXMEM_Ctrl[RegWrite] && (EXMEM_RD != 0) && (EXMEM_RD == IDEX_RS1_ADDR))
            ForwardA = 2'b10;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS1_ADDR))
            ForwardA = 2'b01;
        else
            ForwardA = 2'b00;

        if (EXMEM_Ctrl[RegWrite] && (EXMEM_RD != 0) && (EXMEM_RD == IDEX_RS2_ADDR))
            ForwardB = 2'b10;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0) && (MEMWB_RD == IDEX_RS2_ADDR))
            ForwardB = 2'b01;
        else
            ForwardB = 2'b00;


        if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD == EXMEM_RS2_ADDR) && (MEMWB_RD != 0) && EXMEM_Ctrl[MemWrite])
            ForwardMem = 2'b01;
        else if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD == EXMEM_RS2_ADDR) && (MEMWB_RD != 0))
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
            EXMEM_LD <= 32'b0;
            EXMEM_ALU <= 32'b0;
            EXMEM_PC <= 32'b0;
            EXMEM_IG <= 32'b0;
            EXMEM_RS2 <= 32'b0;
            EXMEM_RD <= 5'b0;
            EXMEM_RS2_ADDR <= 5'b0;
            EXMEM_Z <= 1'b0;
            EXMEM_CSR <= 32'b0;
            EXMEM_CSR_ADDR <= 12'b0;
            EXMEM_Ctrl <= 32'b0;
        end else if (flush || stall) begin
            EXMEM_Ctrl <= 32'b0;
        end else begin
            EXMEM_LD <= dout;
            EXMEM_ALU <= alu_result;
            EXMEM_PC <= IDEX_PC;
            EXMEM_IG <= IDEX_IG;
            EXMEM_RS2 <= Regs[IDEX_RS2_ADDR];
            EXMEM_RD <= IDEX_RD;
            EXMEM_RS2_ADDR <= IDEX_RS2_ADDR;
            EXMEM_Z <= zero;
            EXMEM_CSR <= IDEX_CSR;
            EXMEM_CSR_ADDR <= IDEX_CSR_ADDR;
            EXMEM_Ctrl <= IDEX_Ctrl;
        end
    end



    always @(posedge clk) begin
        mem_rrdata <= store_data;
        rrdata <= mem_rrdata;
    end




    always @* begin
        case (ForwardMem)
            2'b01: store_data = wr_data;
            2'b10: store_data = wb_rd;
            default: store_data = Regs[EXMEM_RS2_ADDR];
        endcase
    end

    assign mem_rdata = (IDEX_Ctrl[MemRead] && EXMEM_Ctrl[MemWrite] && (mem_addr_r == mem_addr_w)) ? store_data :
                       (EXMEM_Ctrl[MemRead]) ? dout : 32'b0;

    // MEM/WB assignment
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MEMWB_LD <= 32'b0;
            MEMWB_RD <= 5'b0;
            MEMWB_ALU <= 32'b0;
            MEMWB_PC <= 32'b0;
            MEMWB_IG <= 32'b0;
            MEMWB_Z <= 1'b0;
            MEMWB_CSR <= 32'b0;
            MEMWB_Ctrl <= 32'b0;
        end else begin
            MEMWB_LD <= dout;
            MEMWB_RD <= EXMEM_RD;
            MEMWB_ALU <= EXMEM_ALU;
            MEMWB_PC <= EXMEM_PC;
            MEMWB_IG <= EXMEM_IG;
            MEMWB_Z <= EXMEM_Z;
            MEMWB_CSR <= EXMEM_CSR;
            MEMWB_Ctrl <= EXMEM_Ctrl;
        end
    end



    always @(posedge clk) begin
        if (IDEX_Ctrl[MemRead] && EXMEM_Ctrl[MemWrite] && (mem_addr_w == mem_addr_r))
            sw_then_ld0 <= 1;
        else
            sw_then_ld0 <= 0;

        sw_then_ld1 <= sw_then_ld0;
    end

    always @* begin
        if (EXMEM_Ctrl[CSRWrite] && (EXMEM_CSR_ADDR == funct12))
            csr_rdata = EXMEM_ALU;
        else
            case (funct12)
                12'h300: csr_rdata = mstatus;
                12'h305: csr_rdata = mtvec;
                12'h340: csr_rdata = mscratch;
                12'h341: csr_rdata = mepc;
                12'h342: csr_rdata = mcause;
                12'h304: csr_rdata = mie;
                12'h344: csr_rdata = mip;
                12'h301: csr_rdata = misa;
                12'hF14: csr_rdata = mhartid;
                12'hF11: csr_rdata = mvendorid;
                12'hF12: csr_rdata = marchid;
                12'hF13: csr_rdata = mimpid;
                12'h343: csr_rdata = mtval;
                12'h306: csr_rdata = mcounteren;
                default: csr_rdata = 32'b0;
            endcase
    end

    always @(posedge clk) begin
        if (EXMEM_Ctrl[CSRWrite]) begin
            case (EXMEM_CSR_ADDR)  // you'll need to pipeline the CSR address too
                12'h300: mstatus  <= EXMEM_ALU;  // CSRRW writes alu result
                12'h305: mtvec    <= EXMEM_ALU;
                12'h340: mscratch <= EXMEM_ALU;
                12'h341: mepc     <= EXMEM_ALU;
                12'h342: mcause   <= EXMEM_ALU;
                12'h304: mie      <= EXMEM_ALU;
                12'h343: mtval    <= EXMEM_ALU;
                12'h306: mcounteren <= EXMEM_ALU;
                // read-only: mip, misa, mhartid, mvendorid, marchid, mimpid
            endcase
        end

        if (take_interrupt) begin
            mepc       <= PC;
            mcause     <= interrupt_cause;
            mtval      <= 32'b0;
            mstatus <= {mstatus[31:8], mstatus[3], mstatus[6:4], 1'b0, mstatus[2:0]};
        end else if (IDEX_Ctrl[MRet]) begin
            mstatus <= {mstatus[31:8], 1'b1, mstatus[6:4], mstatus[7], mstatus[2:0]};
        end
    end

    // Write Back Logic Module
    write_back_module wb (
        .rd(wb_rd),
        .alu(MEMWB_ALU),
        .pc(MEMWB_PC),
        .ImmGen(MEMWB_IG),
        .csr_reg(MEMWB_CSR),
        .ToReg(MEMWB_Ctrl[ToRegEnd:ToRegStart]),
        .wr_data(wr_data)
    );

    // Write Back
    always @(posedge clk) begin
        if (MEMWB_Ctrl[RegWrite] && (MEMWB_RD != 0))
            Regs[MEMWB_RD] <= wr_data;
        Regs[0] <= 32'b0;
    end

    assign out = Regs[9][3:0];

endmodule
