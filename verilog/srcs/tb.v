`timescale 1ns/1ps

module cpu_tb;
    reg clk, reset;
    wire [3:0] out;

    main dut (
        .clk(clk),
        .reset(reset),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, cpu_tb);
        clk = 0;
        reset = 1;
        repeat(4) @(posedge clk);
        reset = 0;
        repeat(100) @(posedge clk);
        $finish;
    end

    // print every cycle
    integer cycle;
    initial begin
        cycle = 0;
        @(negedge reset);
        forever begin
            @(posedge clk);
            /*$display("CYC=%0d PC=%h IR=%h | x3=%0d x4=%0d x5=%0d x6=%0d x8=%0d x9=%h x10=%h x11=%0d x12=%0d x13=%0d x14=%0d x15=%0d x17=%0d | EXMEM_ALU=%h EXMEM_Ctrl=%b EXMEM_RD=%0d | mem_addr_r=%h mem_addr_w=%h we=%b dout=%0d din=%0d | ForwardA=%b ForwardB=%b ForwardMem=%b | load_haz=%b branch=%b jal=%b | alu_in1=%h alu_in2=%h alu_out=%h",
                cycle,
                dut.PC, dut.IFID_IR, dut.Regs[3], dut.Regs[4],
                dut.Regs[5], dut.Regs[6], dut.Regs[8],
                dut.Regs[9], dut.Regs[10],
                dut.Regs[11], dut.Regs[12], dut.Regs[13],
                dut.Regs[14], dut.Regs[15], dut.Regs[17],
                dut.EXMEM_ALU, dut.EXMEM_Ctrl, dut.EXMEM_RD,
                dut.mem_addr_r, dut.mem_addr_w,
                dut.we, dut.dout, dut.din,
                dut.ForwardA, dut.ForwardB, dut.ForwardMem,
                dut.load_hazard, dut.branch_taken, dut.jal_flush,
                dut.alu_in1, dut.alu_in2, dut.alu_result);*/
            $monitor("addr_r=%0d addr_w=%0d we=%b dout=%0d din=%0d", 
          mem_addr_r, dut.mem_addr_w, dut.we, dout, din);
            cycle = cycle + 1;
        end
    end

    // catch when registers change
    always @(dut.Regs[14]) $display("*** x14 changed to %0d at cycle approx %0t", dut.Regs[14], $time);
    always @(dut.Regs[15]) $display("*** x15 changed to %0d at cycle approx %0t", dut.Regs[15], $time);
    always @(dut.Regs[6])  $display("*** x6  changed to %0d at cycle approx %0t", dut.Regs[6],  $time);

    // catch bad memory reads
    always @(posedge clk) begin
        if (dut.EXMEM_Ctrl[3]) // MemRead
            $display(">>> LOAD  addr_r=%h dout=%0d EXMEM_RD=%0d", 
                dut.mem_addr_r, dut.dout, dut.EXMEM_RD);
        if (dut.we)
            $display(">>> STORE addr_w=%h din=%0d",
                dut.mem_addr_w, dut.din);
    end

endmodule
