module fifo (
    input  logic [7:0] data_in,
    input  logic       wr_en,
    input  logic       rd_en,
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] data_out,
    output logic       full,
    output logic       empty
);
    logic [7:0] mem [0:7];
    logic [2:0] wptr, rptr;
    logic [3:0] count;

    assign full  = (count == 8);
    assign empty = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0; rptr <= 0; count <= 0; data_out <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wptr] <= data_in;
                wptr <= wptr + 1;
            end
            if (rd_en && !empty) begin
                data_out <= mem[rptr];
                rptr <= rptr + 1;
            end
            // Simultaneous read/write logic
            if ((wr_en && !full) && !(rd_en && !empty))
                count <= count + 1;
            else if (!(wr_en && !full) && (rd_en && !empty))
                count <= count - 1;
        end
    end
endmodule