`timescale 1ns/1ps

module tb;

reg clk = 0;
reg reset = 1;

wire [3:0] out;

// DUT
cpu dut (
    .clk(clk),
    .reset(reset),
    .out(out)
);

// clock
always #5 clk = ~clk;

integer cycle = 0;

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);

    // release reset
    #20 reset = 0;

    // run long enough for loops/stores
    #200000;

    $display("\n==== FINAL STATE ====");
    $display("x1  = %h", dut.Regs[1]);
    $display("x2  = %h", dut.Regs[2]);
    $display("x13 = %h", dut.Regs[13]);
    $display("x14 = %h", dut.Regs[14]);
    $display("x15 = %h", dut.Regs[15]);

    $display("\n==== DATA MEMORY SAMPLE ====");
    $display("mem[0] = %h", dut.dMem[0]);
    $display("mem[1] = %h", dut.dMem[1]);
    $display("mem[2] = %h", dut.dMem[2]);
    $display("mem[3] = %h", dut.dMem[3]);

    $finish;
end

// cycle monitor
always @(posedge clk) begin
    cycle = cycle + 1;

    // PC tracking
    $display("t=%0t PC=%h x1=%h x2=%h x13=%h x14=%h",
        $time,
        dut.PC,
        dut.Regs[1],
        dut.Regs[2],
        dut.Regs[13],
        dut.Regs[14]
    );

    // detect store activity
    if (dut.EXMEM_Ctrl[2]) begin
        $display(">> STORE PC=%h addr=%h data=%h",
            dut.EXMEM_PC,
            dut.EXMEM_ALU,
            dut.store_data
        );
    end

    // detect load writeback
    if (dut.MEMWB_Ctrl[3]) begin
        $display(">> LOAD WB rd=%0d data=%h",
            dut.MEMWB_RD,
            dut.wr_data
        );
    end
end

endmodule
