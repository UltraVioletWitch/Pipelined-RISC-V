`timescale 1ns/1ps

<<<<<<< HEAD
module tb_main;

    reg clk;
    reg reset;
    wire [15:0] gpio;
=======
// =============================================================================
//  tb_main.v — Testbench for RISC-V SoC (RV32I, 4-5 stage pipeline)
//  Simulator : Icarus Verilog (iverilog + vvp)
//  CPU clock : 50 MHz (generated internally by clk_wiz_0 stub from 100 MHz)
//  UART      : 115200 baud @ 50 MHz  →  ~434 clocks/bit
//
//  Usage:
//    iverilog -g2012 -o tb_main.vvp tb_main.v main.v cpu.v block_ram.v \
//             gpio_module.v timer_module.v uart_module.v \
//             reset_sync.v
//    vvp tb_main.vvp
//
//  The testbench provides stubs for clk_wiz_0 and reset_sync so you do NOT
//  need to include Xilinx simulation models.  Remove the stubs below if you
//  prefer to use the real IP simulation models.
//
//  Memory initialisation:
//    Place your compiled hex image as  "program.hex"  in the working directory.
//    The hex file must cover both instruction and data regions packed into a
//    single word-addressed file starting at address 0.
//    Adjust MEM_HEX_FILE, IMEM_BASE, and MEM_WORDS below to match your
//    linker script if needed.
// =============================================================================
>>>>>>> 9257098 (removed vcd files)

// ---------------------------------------------------------------------------
//  Tuneable parameters — edit these to match your design
// ---------------------------------------------------------------------------
`define MEM_HEX_FILE  "program.hex"   // path to $readmemh hex image
`define MEM_WORDS     16384           // 64 KB  (word-addressed)
`define IMEM_BASE     32'h0000_0000   // start of instruction memory
`define DATA_BASE     32'h0000_4000   // start of data memory (matches RTL)

`define CLK_PERIOD_NS 10              // 100 MHz board clock fed to clk_wiz_0
`define SIM_TIMEOUT   20_000_000      // ns — abort if nothing interesting happens

`define UART_BAUD     115200
`define CPU_CLK_HZ    50_000_000
`define CLKS_PER_BIT  (`CPU_CLK_HZ / `UART_BAUD)   // 434

// ---------------------------------------------------------------------------
//  Testbench top
// ---------------------------------------------------------------------------
module tb_main;

    // -----------------------------------------------------------------------
    //  DUT signals
    // -----------------------------------------------------------------------
    reg         clk_100MHz = 0;
    reg         reset      = 1;
    wire [15:0] gpio;
    reg         uart_rx    = 1;   // idle high
    wire        uart_tx;

    // GPIO pin drive — lower 10 bits are outputs (GPIO_DIR=0x3FF in C code)
    // Upper 6 bits are inputs (buttons/switches).  Drive them low by default.
    reg  [15:0] gpio_drive = 16'b0;
    // Bidirectional gpio: outputs are driven by DUT, inputs by testbench
    // We use a simple model: drive only the input pins
    assign gpio = gpio_drive;   // will be overridden by DUT for output pins

    // -----------------------------------------------------------------------
    //  Clock  (100 MHz board clock)
    // -----------------------------------------------------------------------
    always #(`CLK_PERIOD_NS/2) clk_100MHz = ~clk_100MHz;

    // -----------------------------------------------------------------------
    //  DUT instantiation
    // -----------------------------------------------------------------------
    main dut (
<<<<<<< HEAD
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
=======
        .clk_100MHz (clk_100MHz),
        .reset      (reset),
        .gpio       (gpio),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx)
    );

    // -----------------------------------------------------------------------
    //  Shared memory image  (loaded once, used by both instruction and data
    //  memory stubs if your design uses a unified hex file)
    // -----------------------------------------------------------------------
    reg [31:0] mem_image [`MEM_WORDS-1:0];
>>>>>>> 9257098 (removed vcd files)

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
<<<<<<< HEAD
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
=======
        $readmemh(`MEM_HEX_FILE, mem_image);
        $display("[TB] Loaded %0s", `MEM_HEX_FILE);
    end

    // -----------------------------------------------------------------------
    //  Reset sequence
    // -----------------------------------------------------------------------
    initial begin
        reset = 1;
        repeat (20) @(posedge clk_100MHz);
        reset = 0;
        $display("[TB] Reset released at %0t ns", $time);
    end

    // -----------------------------------------------------------------------
    //  UART TX monitor
    //  Captures bytes sent by the CPU on uart_tx and prints them to console.
    //  Protocol: 1 start bit (low), 8 data bits LSB-first, 1 stop bit (high)
    // -----------------------------------------------------------------------
    integer uart_byte_count = 0;

    task automatic uart_capture_byte;
        integer i;
        reg [7:0] rx_byte;
        reg       sample;
    begin
        // Wait for start bit (falling edge)
        @(negedge uart_tx);

        // Move to centre of start bit and verify it is still low
        #((`CLKS_PER_BIT * `CLK_PERIOD_NS) / 2);
        if (uart_tx !== 1'b0) begin
            $display("[UART-MON] False start bit at %0t ns", $time);
            disable uart_capture_byte;
        end

        // Sample 8 data bits, each `CLKS_PER_BIT clocks apart
        for (i = 0; i < 8; i = i + 1) begin
            #(`CLKS_PER_BIT * `CLK_PERIOD_NS);
            rx_byte[i] = uart_tx;
        end

        // Stop bit
        #(`CLKS_PER_BIT * `CLK_PERIOD_NS);
        if (uart_tx !== 1'b1)
            $display("[UART-MON] WARNING — stop bit not high at %0t ns", $time);

        uart_byte_count = uart_byte_count + 1;
        $write("[UART-TX] byte %0d = 0x%02X '%s' at %0t ns\n",
               uart_byte_count, rx_byte,
               (rx_byte >= 8'h20 && rx_byte <= 8'h7E) ? rx_byte : 8'h2E,
               $time);
    end
    endtask

    // Run UART monitor in a continuous loop
    initial begin
        // Wait for reset to deassert
        @(negedge reset);
        forever begin
            uart_capture_byte;
        end
    end

    // Add to your initial block after reset
    always @(uart_tx) begin
        $display("[TX-LINE] uart_tx = %b at %0t ns", uart_tx, $time);
    end

    // -----------------------------------------------------------------------
    //  GPIO output monitor
    //  Prints whenever GPIO_OUT changes (lower 10 bits driven as outputs)
    // -----------------------------------------------------------------------
    reg [15:0] gpio_prev = 16'hFFFF;

    always @(gpio) begin
        if (gpio !== gpio_prev) begin
            $display("[GPIO-OUT] GPIO = 0x%04X  (LEDs[9:0] = %010b)  at %0t ns",
                     gpio, gpio[9:0], $time);
            gpio_prev = gpio;
        end
    end

    // -----------------------------------------------------------------------
    //  Timer interrupt monitor
    //  Watches the mip wire through the DUT hierarchy — adjust path if needed
    // -----------------------------------------------------------------------
    // Uncomment and fix hierarchical path if your simulator supports it:
    // wire timer_irq = dut.timer_interrupt;
    // always @(posedge timer_irq)
    //     $display("[TIMER-IRQ] Timer interrupt fired at %0t ns", $time);

    // -----------------------------------------------------------------------
    //  UART RX stimulus helper — send a byte from testbench to CPU
    // -----------------------------------------------------------------------
    task automatic uart_send_byte;
        input [7:0] tx_byte;
        integer i;
    begin
        $display("[UART-RX-STIM] Sending 0x%02X '%s'", tx_byte,
                 (tx_byte >= 8'h20 && tx_byte <= 8'h7E) ? tx_byte : 8'h2E);
        // Start bit
        uart_rx = 0;
        #(`CLKS_PER_BIT * `CLK_PERIOD_NS);
        // Data bits LSB first
        for (i = 0; i < 8; i = i + 1) begin
            uart_rx = tx_byte[i];
            #(`CLKS_PER_BIT * `CLK_PERIOD_NS);
        end
        // Stop bit
        uart_rx = 1;
        #(`CLKS_PER_BIT * `CLK_PERIOD_NS);
    end
    endtask

    // -----------------------------------------------------------------------
    //  GPIO interrupt stimulus
    //  Pulse a GPIO input pin to trigger external interrupt
    // -----------------------------------------------------------------------
    task automatic gpio_pulse_input;
        input [15:0] pin_mask;
        input integer pulse_ns;
    begin
        $display("[GPIO-STIM] Pulsing GPIO input pins 0x%04X for %0d ns", pin_mask, pulse_ns);
        gpio_drive = gpio_drive | pin_mask;
        #(pulse_ns);
        gpio_drive = gpio_drive & ~pin_mask;
    end
    endtask

    // -----------------------------------------------------------------------
    //  Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_main.vcd");
        $dumpvars(0, tb_main);

        // Wait for reset
        @(negedge reset);
        $display("[TB] Simulation started. CPU clock = 50 MHz, UART = 115200 baud");
        $display("[TB] Waiting for first timer tick (~%0d us)...",
                 (`CPU_CLK_HZ / `UART_BAUD));  // rough indicator

        // --- Test 1: Wait for first timer interrupt and LED change -----------
        // Timer fires after 12_500_000 cycles @ 50 MHz = 250 ms = 250_000_000 ns
        // That is too long for a sim, so we just wait a short time and check
        // GPIO changes.  To speed up, consider making TIMER_INTERVAL a
        // parameter you can override in simulation.
        #5_000_000;  // 5 ms — enough for init, not enough for timer tick
        $display("[TB] --- Test 1 complete: basic init OK if no X/Z on outputs ---");

        // --- Test 2: Send a UART RX byte, expect echo back ------------------
        $display("[TB] --- Test 2: Sending UART byte 0x41 ('A'), expect echo ---");
        #1000;
        uart_send_byte(8'h41);  // 'A'
        // Give CPU time to process RX interrupt and echo back
        #(50 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        $display("[TB] --- Test 2 complete: check UART-TX log above for 0x41 ---");

        // --- Test 3: Trigger GPIO interrupt, expect "EXT IRQ fired\r\n" -----
        $display("[TB] --- Test 3: Triggering GPIO interrupt ---");
        #1000;
        gpio_pulse_input(16'hFC00, 1000);  // pulse upper 6 input pins
        // Give CPU time to handle interrupt and send the string
        // "EXT IRQ fired\r\n" = 15 bytes @ ~434*10ns/bit*10bits = ~43us/byte
        #(15 * `CLKS_PER_BIT * `CLK_PERIOD_NS * 12);
        $display("[TB] --- Test 3 complete: check UART-TX log for 'EXT IRQ fired' ---");

        // --- Test 4: Send several bytes, check each echoes ------------------
        $display("[TB] --- Test 4: Sending 'Hello' byte by byte ---");
        uart_send_byte(8'h48); // H
        #(5 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        uart_send_byte(8'h65); // e
        #(5 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        uart_send_byte(8'h6C); // l
        #(5 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        uart_send_byte(8'h6C); // l
        #(5 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        uart_send_byte(8'h6F); // o
        #(20 * `CLKS_PER_BIT * `CLK_PERIOD_NS);
        $display("[TB] --- Test 4 complete ---");

        $display("[TB] All tests complete. Total UART bytes received: %0d", uart_byte_count);
        $display("[TB] Ending simulation.");
        $finish;
    end

    // -----------------------------------------------------------------------
    //  Global timeout watchdog
    // -----------------------------------------------------------------------
    initial begin
        #(`SIM_TIMEOUT);
        $display("[TB] TIMEOUT after %0d ns — simulation aborted.", `SIM_TIMEOUT);
        $display("[TB]   UART bytes captured so far: %0d", uart_byte_count);
        $finish;
>>>>>>> 9257098 (removed vcd files)
    end


endmodule

// =============================================================================
//  STUB: clk_wiz_0
//  Replaces Xilinx IP for simulation.  Divides 100 MHz → 50 MHz.
//  Remove this block if you are using the real Xilinx simulation model.
// =============================================================================
module clk_wiz_0 (
    input  wire clk_in1,
    output reg  clk_out1,
    input  wire reset,
    output wire locked
);
    // 50 MHz = toggle every 10 ns (half of 100 MHz)
    initial clk_out1 = 0;
    always @(posedge clk_in1 or posedge reset) begin
        if (reset)
            clk_out1 <= 0;
        else
            clk_out1 <= ~clk_out1;
    end
    // locked goes high after a short delay post-reset
    reg locked_r = 0;
    always @(posedge clk_in1) begin
        if (reset)
            locked_r <= 0;
        else
            locked_r <= 1;
    end
    assign locked = locked_r;
endmodule
