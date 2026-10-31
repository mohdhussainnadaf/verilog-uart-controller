module baud_rate_gen (
    input wire clk, rst_n,
    input wire [15:0] dvsr,
    output wire tick
);
    reg [15:0] r_reg, r_next;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) r_reg <= 16'd0; else r_reg <= r_next;
    always @(*)
        if (r_reg == dvsr) r_next = 16'd0; else r_next = r_reg + 1'b1;
    assign tick = (r_reg == dvsr);
endmodule

module rx_synchronizer (
    input wire clk, rst_n, async_rx,
    output reg sync_rx
);
    reg q1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin q1 <= 1'b1; sync_rx <= 1'b1; end
        else begin q1 <= async_rx; sync_rx <= q1; end
    end
endmodule

module uart_rx #(parameter DBIT = 8, SB_TICK = 16)(
    input wire clk, rst_n, rx, s_tick,
    output reg rx_done_tick,
    output wire [DBIT-1:0] dout,
    output reg frame_err
);
    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state_reg, state_next;
    reg [3:0] s_reg, s_next;
    reg [2:0] n_reg, n_next;
    reg [7:0] b_reg, b_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE; s_reg <= 0; n_reg <= 0; b_reg <= 0;
        end else begin
            state_reg <= state_next; s_reg <= s_next; n_reg <= n_next; b_reg <= b_next;
        end
    end

    always @(*) begin
        state_next = state_reg; s_next = s_reg; n_next = n_reg; b_next = b_reg;
        rx_done_tick = 1'b0; frame_err = 1'b0;
        case (state_reg)
            IDLE: if (~rx) begin state_next = START; s_next = 0; end
            START: if (s_tick) begin
                if (s_reg == 7) begin state_next = DATA; s_next = 0; n_next = 0; end
                else s_next = s_reg + 1;
            end
            DATA: if (s_tick) begin
                if (s_reg == 15) begin
                    s_next = 0; b_next = {rx, b_reg[7:1]};
                    if (n_reg == DBIT - 1) state_next = STOP;
                    else n_next = n_reg + 1;
                end else s_next = s_reg + 1;
            end
            STOP: if (s_tick) begin
                if (s_reg == SB_TICK - 1) begin
                    if (~rx) frame_err = 1'b1;
                    rx_done_tick = 1'b1; state_next = IDLE;
                end else s_next = s_reg + 1;
            end
        endcase
    end
    assign dout = b_reg;
endmodule

module uart_tx #(parameter DBIT = 8, SB_TICK = 16)(
    input wire clk, rst_n, tx_start, s_tick,
    input wire [DBIT-1:0] din,
    output reg tx_done_tick, tx
);
    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state_reg, state_next;
    reg [3:0] s_reg, s_next;
    reg [2:0] n_reg, n_next;
    reg [7:0] b_reg, b_next;
    reg tx_reg, tx_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE; s_reg <= 0; n_reg <= 0; b_reg <= 0; tx_reg <= 1'b1;
        end else begin
            state_reg <= state_next; s_reg <= s_next; n_reg <= n_next; b_reg <= b_next; tx_reg <= tx_next;
        end
    end

    always @(*) begin
        state_next = state_reg; s_next = s_reg; n_next = n_reg; b_next = b_reg; tx_next = tx_reg; tx_done_tick = 0;
        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin state_next = START; s_next = 0; b_next = din; end
            end
            START: begin
                tx_next = 1'b0;
                if (s_tick) begin
                    if (s_reg == 15) begin state_next = DATA; s_next = 0; n_next = 0; end
                    else s_next = s_reg + 1;
                end
            end
            DATA: begin
                tx_next = b_reg[0];
                if (s_tick) begin
                    if (s_reg == 15) begin
                        s_next = 0; b_next = b_reg >> 1;
                        if (n_reg == DBIT - 1) state_next = STOP;
                        else n_next = n_reg + 1;
                    end else s_next = s_reg + 1;
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin tx_done_tick = 1'b1; state_next = IDLE; end
                    else s_next = s_reg + 1;
                end
            end
        endcase
    end
    always @(*) tx = tx_reg;
endmodule

module fifo #(parameter DATA_SIZE = 8, ADDR_SIZE = 4)(
    input wire clk, rst_n, rd, wr,
    input wire [DATA_SIZE-1:0] w_data,
    output wire empty, full,
    output wire [DATA_SIZE-1:0] r_data
);
    reg [DATA_SIZE-1:0] array_reg [2**ADDR_SIZE-1:0];
    reg [ADDR_SIZE-1:0] w_ptr_reg, w_ptr_next, r_ptr_reg, r_ptr_next;
    reg full_reg, full_next, empty_reg, empty_next;

    always @(posedge clk) if (wr && !full_reg) array_reg[w_ptr_reg] <= w_data;
    assign r_data = array_reg[r_ptr_reg];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_ptr_reg <= 0; r_ptr_reg <= 0; full_reg <= 0; empty_reg <= 1;
        end else begin
            w_ptr_reg <= w_ptr_next; r_ptr_reg <= r_ptr_next; full_reg <= full_next; empty_reg <= empty_next;
        end
    end

    always @(*) begin
        w_ptr_next = w_ptr_reg; r_ptr_next = r_ptr_reg; full_next = full_reg; empty_next = empty_reg;
        case ({wr, rd})
            2'b01: if (!empty_reg) begin
                r_ptr_next = r_ptr_reg + 1; full_next = 0;
                if (r_ptr_next == w_ptr_reg) empty_next = 1;
            end
            2'b10: if (!full_reg) begin
                w_ptr_next = w_ptr_next + 1; empty_next = 0;
                if (w_ptr_next == r_ptr_reg) full_next = 1;
            end
            2'b11: begin w_ptr_next = w_ptr_reg + 1; r_ptr_next = r_ptr_reg + 1; end
            default: ;
        endcase
    end
    assign full = full_reg; assign empty = empty_reg;
endmodule

module uart_top #(parameter DATA_WIDTH = 8, FIFO_DEPTH = 16)(
    input wire clk, rst_n,
    input wire [15:0] dvsr,
    input wire tx_start,
    input wire [DATA_WIDTH-1:0] tx_data_in,
    output wire tx, tx_full,
    input wire rx, rx_read,
    output wire [DATA_WIDTH-1:0] rx_data_out,
    output wire rx_empty, rx_frame_err
);
    wire tick, rx_done_tick, tx_done_tick, tx_fifo_empty, rx_sync;
    wire [DATA_WIDTH-1:0] rx_data, tx_data;

    baud_rate_gen baud_gen_inst (.clk(clk), .rst_n(rst_n), .dvsr(dvsr), .tick(tick));
    rx_synchronizer sync_inst (.clk(clk), .rst_n(rst_n), .async_rx(rx), .sync_rx(rx_sync));
    uart_rx #(.DBIT(DATA_WIDTH), .SB_TICK(16)) rx_inst (.clk(clk), .rst_n(rst_n), .rx(rx_sync), .s_tick(tick), .rx_done_tick(rx_done_tick), .dout(rx_data), .frame_err(rx_frame_err));
    fifo #(.DATA_SIZE(DATA_WIDTH), .ADDR_SIZE(4)) rx_fifo_inst (.clk(clk), .rst_n(rst_n), .rd(rx_read), .wr(rx_done_tick), .w_data(rx_data), .empty(rx_empty), .full(), .r_data(rx_data_out));
    fifo #(.DATA_SIZE(DATA_WIDTH), .ADDR_SIZE(4)) tx_fifo_inst (.clk(clk), .rst_n(rst_n), .rd(tx_done_tick), .wr(tx_start), .w_data(tx_data_in), .empty(tx_fifo_empty), .full(tx_full), .r_data(tx_data));
    uart_tx #(.DBIT(DATA_WIDTH), .SB_TICK(16)) tx_inst (.clk(clk), .rst_n(rst_n), .tx_start(!tx_fifo_empty), .s_tick(tick), .din(tx_data), .tx_done_tick(tx_done_tick), .tx(tx));
endmodule
