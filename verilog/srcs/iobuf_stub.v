module IOBUF (
    input  wire I,   // data from internal logic
    output wire O,   // data to internal logic
    inout  wire IO,  // physical pin
    input  wire T    // tri-state control (1 = high-Z)
);

    assign IO = (T) ? 1'bz : I;
    assign O  = IO;

endmodule
