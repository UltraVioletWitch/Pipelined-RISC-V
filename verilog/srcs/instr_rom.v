module instr_rom (
    input clk,
    input rst,
    input en,
    input [31:0] addr,
    output reg [31:0] dout
);
    (* rom_style = "block" *) reg [31:0] rom [0:4095];
    initial $readmemh("program.hex", rom);
    always @(posedge clk) begin
        if (rst)
            dout <= rom[0];
        else if (en)
            dout <= rom[addr];
    end
endmodule
