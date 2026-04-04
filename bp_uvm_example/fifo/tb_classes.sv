class fifo_scoreboard;
    logic [7:0] model_q[$];
    int pass_count = 0;
    int error_count = 0;

    function void write_expected(logic [7:0] d);
        model_q.push_back(d);
    endfunction

    function void check_actual(logic [7:0] d_out);
        if (model_q.size() > 0) begin
            logic [7:0] expected = model_q.pop_front();

            if (d_out === expected) begin
                $display("[%0t] PASS: %h", $time, d_out);
                pass_count++;
            end else begin
                $display("[%0t] FAIL: expected %h got %h", $time, expected, d_out);
                error_count++;
            end
        end
    endfunction

    function void report();
        $display("PASS=%0d FAIL=%0d", pass_count, error_count);
    endfunction
endclass



class fifo_driver;
    virtual fifo_if vif;
    fifo_scoreboard sb;

    function new(virtual fifo_if v, fifo_scoreboard s);
        vif = v;
        sb  = s;
    endfunction

    task run();
        bit do_write;
        bit do_read;
        logic [7:0] data;

        forever begin
            @(vif.drv_cb);

            do_write = ($urandom_range(0,9) < 6);
            do_read  = ($urandom_range(0,9) < 4);
            data     = 8'($urandom_range(0,255));

            vif.drv_cb.wr_en   <= do_write;
            vif.drv_cb.rd_en   <= do_read;
            vif.drv_cb.data_in <= data;

            if (do_write && !vif.full) begin
                sb.write_expected(data);
                $display("[%0t] WRITE: %h", $time, data);
            end
        end
    endtask
endclass



class fifo_monitor;
    virtual fifo_if vif;
    fifo_scoreboard sb;

    bit pending_read;  // tracks delayed read

    function new(virtual fifo_if v, fifo_scoreboard s);
        vif = v;
        sb  = s;
        pending_read = 0;
    endfunction

    task run();
        forever begin
            @(vif.mon_cb);

            // Step 1: check previous cycle read
            if (pending_read) begin
                sb.check_actual(vif.mon_cb.data_out);
            end

            // Step 2: capture new read request
            pending_read = (vif.mon_cb.rd_en && !vif.mon_cb.empty);
        end
    endtask
endclass


class fifo_env;
    fifo_driver drv;
    fifo_monitor mon;
    fifo_scoreboard sb;

    function new(virtual fifo_if v);
        sb  = new();
        drv = new(v, sb);
        mon = new(v, sb);
    endfunction
endclass