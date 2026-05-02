`timescale 1ns/1ps

module tb_main;

    reg clk;
    reg reset;
    wire [15:0] gpio;

    main dut (
        .clk(clk),
        .reset(reset),
        .gpio(gpio)
    );

    reg [15:0] gpio_tb_out;
    reg [15:0] gpio_drive;

    wire [15:0] gpio_dir = dut.gpio0.gpio_dir_reg;

    // per-bit tri-state model (correct)
    genvar i;

    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign gpio[i] = (gpio_dir[i] == 1'b0) ? gpio_tb_out[i] : 1'bz;
        end
    endgenerate

    always #5 clk = ~clk;

    // -------------------------
    // wait helper
    // -------------------------
    task wait_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // -------------------------
    // peek internal GPIO regs (DEBUG ONLY)
    // -------------------------
    wire [31:0] ip_debug = dut.gpio0.gpio_ip_reg;
    wire [31:0] ie_debug = dut.gpio0.gpio_ie_reg;
    wire        irq      = dut.gpio_interrupt;
    wire [31:0] gpio_out = dut.gpio0.gpio_out_reg;

    initial begin
        $dumpvars(0, tb_main);

        clk = 0;
        reset = 1;
        gpio_drive = 0;

        wait_cycles(5);
        reset = 0;


        // -------------------------
        // Enable interrupts (like your C code)
        // -------------------------
        wait_cycles(20);


        // -------------------------
        // Generate GPIO edge
        // -------------------------
        gpio_drive = 16'h0000;
        wait_cycles(10);

        //gpio_drive = 16'h0100; // rising edge
        wait_cycles(10);

        // -------------------------
        // CHECK interrupt fired
        // -------------------------
        wait_cycles(5);

        // -------------------------
        // wait CPU response
        // -------------------------
        wait_cycles(50);


        // -------------------------
        // toggle again
        // -------------------------
        gpio_drive = 16'h0000;
        wait_cycles(10);

        //gpio_drive = 16'h0100;
        wait_cycles(10);

        wait_cycles(50);


        wait_cycles(5000);
        $finish;
    end

    reg [6:0] IDEX_OPCODE;
    always @(posedge clk) begin
        IDEX_OPCODE <= dut.core.opcode;
        if (1)
            $display("PC = 0x%h, load_hazard = 0x%h, branch_taken = 0x%h, EXMEM_ALU = 0x%h", dut.core.EXMEM_PC, dut.core.load_hazard, dut.core.branch_taken, dut.core.EXMEM_ALU);
            $display("ForwardA = %b, ForwardB = %b, ForawrdMem = %b, alu_in1 = 0x%h, alu_in2 = 0x%h", dut.core.ForwardA, dut.core.ForwardB, dut.core.ForwardMem, dut.core.alu_in1, dut.core.alu_in2);
            $display("wr_data = %h, a5 = %h, TimerState = %h", dut.core.mie, dut.gpio, dut.core.mepc);
    end


endmodule
