module uart_rx #(
    parameter DATA_BITS = 8
)(
    input  wire clk,
    input  wire reset,

    input  wire rx,              // serial input
    input  wire baud_tick_rx,    // 16x oversampling tick

    output reg  [DATA_BITS-1:0] data_out,
    output reg  data_valid
);

    // ------------------------------------------------------------
    // State machine
    // ------------------------------------------------------------
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;

    reg [3:0] tick_cnt;
    reg [2:0] bit_idx;
    reg [DATA_BITS-1:0] rx_shift;

    // ------------------------------------------------------------
    // 2-flop synchronizer (critical for real UART)
    // ------------------------------------------------------------
    reg rx_meta, rx_sync;

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    // ------------------------------------------------------------
    // UART RX FSM (textbook 16x oversampling)
    // ------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            tick_cnt   <= 0;
            bit_idx    <= 0;
            rx_shift   <= 0;
            data_out   <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0; // pulse

            if (baud_tick_rx) begin

                case (state)

                // ------------------------------------------------
                // IDLE: wait for falling edge (start bit)
                // ------------------------------------------------
                IDLE: begin
                    tick_cnt <= 0;
                    bit_idx  <= 0;

                    if (rx_sync == 1'b0) begin
                        state    <= START;
                        tick_cnt <= 0;
                    end
                end

                // ------------------------------------------------
                // START: validate start bit at middle (8/16)
                // ------------------------------------------------
                START: begin
                    tick_cnt <= tick_cnt + 1;

                    if (tick_cnt == 7) begin
                        if (rx_sync == 1'b0) begin
                            state    <= DATA;
                            tick_cnt <= 0;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                // ------------------------------------------------
                // DATA: sample each bit at center (tick 7)
                // ------------------------------------------------
                DATA: begin
                    tick_cnt <= tick_cnt + 1;

                    if (tick_cnt == 7) begin
                        rx_shift[bit_idx] <= rx_sync;
                    end

                    if (tick_cnt == 15) begin
                        tick_cnt <= 0;

                        if (bit_idx == DATA_BITS - 1) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end
                end

                // ------------------------------------------------
                // STOP: verify stop bit, then output byte
                // ------------------------------------------------
                STOP: begin
                    tick_cnt <= tick_cnt + 1;

                    if (tick_cnt == 7) begin
                        // optional stop-bit check:
                        // if (rx_sync != 1) error;
                    end

                    if (tick_cnt == 15) begin
                        data_out   <= rx_shift;
                        data_valid <= 1'b1;

                        state    <= IDLE;
                        tick_cnt <= 0;
                    end
                end

                endcase
            end
        end
    end

endmodule
