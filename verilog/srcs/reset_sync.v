module reset_sync (
    input wire clk,
    input wire async_rst,
    input wire locked,
    output reg sync_rst
);

    reg stage1;

    always @(posedge clk or posedge async_rst) begin
        if (async_rst || !locked) begin
            stage1 <= 1'b1;
            sync_rst <= 1'b1;
        end else begin
            stage1 <= 1'b0;
            sync_rst <= stage1;
        end
    end
endmodule
