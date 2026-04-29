module main (
    input wire clk,
    input wire reset,
    output wire [3:0] out
);
    cpu core (
        .clk(clk),
        .reset(reset),
        .out(out)
    );

endmodule
