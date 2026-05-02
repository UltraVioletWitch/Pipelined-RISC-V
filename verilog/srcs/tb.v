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
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_main);

        clk = 0;
        reset = 1;
        gpio_drive = 0;

        wait_cycles(5);
        reset = 0;

        $display("\n=== START SYSTEM TEST ===");

        // -------------------------
        // Enable interrupts (like your C code)
        // -------------------------
        wait_cycles(20);

        $display("IE = %h", ie_debug);

        // -------------------------
        // Generate GPIO edge
        // -------------------------
        gpio_drive = 16'h0000;
        wait_cycles(10);

        gpio_drive = 16'h0100; // rising edge
        wait_cycles(10);

        // -------------------------
        // CHECK interrupt fired
        // -------------------------
        wait_cycles(5);

        if (irq)
            $display("✅ IRQ ASSERTED");
        else
            $display("❌ IRQ NOT ASSERTED");

        $display("IP = %h", ip_debug);

        // -------------------------
        // wait CPU response
        // -------------------------
        wait_cycles(50);

        $display("GPIO OUT = %h", gpio_out);

        // -------------------------
        // toggle again
        // -------------------------
        gpio_drive = 16'h0000;
        wait_cycles(10);

        gpio_drive = 16'h0100;
        wait_cycles(10);

        wait_cycles(50);

        $display("IP FINAL = %h", ip_debug);
        $display("GPIO OUT FINAL = %h", gpio_out);

        $display("\n=== TEST COMPLETE ===");

        wait_cycles(20);
        $finish;
    end

    always @(posedge clk) begin
        $display("CPU mip = 0x%h", dut.gpio0.gpio_in_wire);
    end


endmodule
