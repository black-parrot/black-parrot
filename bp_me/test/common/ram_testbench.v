module testbench
  #()
  (input clk_i
   ,input reset_i
  );

  logic v_i, w_i;
  logic [2:0] addr_i;
  logic [7:0] data_i, data_o;

  bsg_mem_1rw_sync
    #(.width_p(8)
      ,.els_p(8)
      )
    ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(v_i)
      ,.data_i(data_i)
      ,.addr_i(addr_i)
      ,.w_i(w_i)
      ,.data_o(data_o)
      );

  typedef enum logic [1:0] {
    RESET
    ,WRITE
    ,READ
    ,HOLD
  } state;

  state pc_state;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc_state <= RESET;
      v_i <= '0;
      data_i <= '0;
      addr_i <= '0;
      w_i <= '0;

    end else begin
      pc_state <= pc_state;
      v_i <= '0;
      data_i <= '0;
      addr_i <= '0;
      w_i <= '0;

      case (pc_state)
        RESET: begin
          pc_state <= WRITE;
          v_i <= 1'b1;
          data_i <= '0;
          addr_i <= '0;
          w_i <= 1'b1;
        end
        WRITE: begin
          pc_state <= READ;
          v_i <= 1'b1;
          data_i <= '0;
          addr_i <= '0;
          w_i <= 1'b0;
        end
        READ: begin
          pc_state <= HOLD;
        end
        HOLD: begin
          pc_state <= HOLD;
        end
        default: begin
          pc_state <= RESET;
        end
      endcase
    end
  end

endmodule
