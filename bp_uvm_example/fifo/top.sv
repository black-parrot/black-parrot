`include "fifo_if.sv"
`include "fifo.sv"
`include "tb_classes.sv"

module top;

    logic clk;

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    fifo_if p_if(clk);
    fifo_env env;

    fifo dut (
        .clk(clk),
        .rst_n(p_if.rst_n),
        .data_in(p_if.data_in),
        .data_out(p_if.data_out),
        .wr_en(p_if.wr_en),
        .rd_en(p_if.rd_en),
        .full(p_if.full),
        .empty(p_if.empty)
    );

    initial begin
        // Reset
        p_if.rst_n = 0;
        p_if.wr_en = 0;
        p_if.rd_en = 0;

        #50;
        p_if.rst_n = 1;

        // Create env
        env = new(p_if);

        // Run components
        fork
            env.drv.run();
            env.mon.run();
        join_none

        // Run simulation
        #2000;

        env.sb.report();
        $display("Simulation Finished");
        $finish;
    end

endmodule