interface fifo_if(input logic clk);
    logic rst_n;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic wr_en;
    logic rd_en;
    logic full;
    logic empty;

    clocking drv_cb @(posedge clk);
        output rst_n, data_in, wr_en, rd_en;
        input  full, empty;
    endclocking

    clocking mon_cb @(posedge clk);
        input data_in, data_out, wr_en, rd_en, full, empty;
    endclocking
endinterface