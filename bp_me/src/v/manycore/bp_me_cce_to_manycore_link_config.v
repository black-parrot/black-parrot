/**
 *  Name:
 *    bp_me_cce_to_manycore_link_config.v
 *
 *  Description:
 *    Configuration module in manycore bridge.
 *    endpoint_standard is master. response must be returned whether it's write or
 *    read.
 *
 *  BlackParrot EPA Mapping:
 *
 *    1.  if MSB of addr = 1, then it maps to ctrl address space.
 *        the remaining addr is 0, it maps reset register.
 *        the remaining addr is 1, it maps freeze register.
 *
 *    2.  if MSB of addr = 0, then it maps to everything else.
 *        e.g.) PC register, CCE microcode, etc.
 */

module bp_me_cce_to_manycore_link_config
  #(parameter link_data_width_p="inv"
    , parameter link_addr_width_p="inv"
    , parameter freeze_init_p="inv"
    , localparam link_mask_width_lp=(link_data_width_p>>3)
  )
  (
    input clk_i
    , input reset_i

    // bp side
    , output logic reset_o
    , output logic freeze_o

    , output logic [link_addr_width_p-2:0] config_addr_o
    , output logic [link_data_width_p-1:0] config_data_o
    , output logic config_v_o
    , output logic config_w_o
    , input config_ready_i

    , input [link_data_width_p-1:0] config_data_i
    , input config_v_i
    , output logic config_ready_o

    // manycore side
    , input v_i
    , input [link_data_width_p-1:0] data_i
    , input [link_mask_width_lp-1:0] mask_i
    , input [link_addr_width_p-1:0] addr_i
    , input we_i
    , output logic yumi_o
    
    , output logic [link_data_width_p-1:0] data_o
    , output logic v_o
  );


  logic reset_r, reset_n;
  logic freeze_r, freeze_n;

  typedef enum logic [2:0] {
    WAIT
    ,WRITE_DATA
    ,READ_DATA
    ,WAIT_READ_DATA
    ,SEND_RESP
  } config_state_e;

  config_state_e config_state_r, config_state_n;
  logic [link_addr_width_p-1:0] addr_r, addr_n;
  logic [link_data_width_p-1:0] data_r, data_n;
  logic [link_mask_width_lp-1:0] mask_r, mask_n;
  logic [link_data_width_p-1:0] resp_data_r, resp_data_n;

  logic is_ctrl_addr; // MSB == 1
  logic is_freeze_addr;
  logic is_reset_addr;

  assign is_ctrl_addr = addr_r[link_addr_width_p-1];
  assign is_freeze_addr = (addr_r[0+:link_addr_width_p-1] == (link_addr_width_p-1)'(1)); 
  assign is_reset_addr = (addr_r[0+:link_addr_width_p-1] == (link_addr_width_p-1)'(0));

  assign config_data_o = data_r;
  assign config_addr_o = addr_r[0+:link_addr_width_p-1];

  always_comb begin
    config_state_n = config_state_r;
    freeze_n = freeze_r;
    reset_n = reset_r;
    addr_n = addr_r;
    data_n = data_r;
    mask_n = mask_r;
    resp_data_n = resp_data_r;
    yumi_o = 1'b0;
    v_o = 1'b0;

    config_v_o = 1'b0;
    config_w_o = 1'b0;
    config_ready_o = 1'b0;

    case (config_state_r)

      WAIT: begin
        if (v_i) begin
          addr_n = addr_i;
          data_n = we_i
            ? data_i
            : data_r;
          mask_n = mask_i;
          yumi_o = 1'b1;
          config_state_n = we_i
            ? WRITE_DATA
            : READ_DATA;
        end
      end

      WRITE_DATA: begin
        resp_data_n = '0;

        if (is_ctrl_addr) begin
          config_state_n = SEND_RESP;

          if (is_freeze_addr) begin
            freeze_n = data_r[0];
          end
          else if (is_reset_addr) begin
            reset_n = data_r[0];
          end
        end
        else begin
          config_v_o = 1'b1;
          config_w_o = 1'b1;

          config_state_n = config_ready_i
            ? SEND_RESP
            : WRITE_DATA;
        end
      end

      READ_DATA: begin
        if (is_ctrl_addr) begin
          config_state_n = SEND_RESP;

          if (is_freeze_addr) begin
            resp_data_n = {{(link_data_width_p-1){1'b0}}, freeze_r};
          end
          else if (is_reset_addr) begin
            resp_data_n = {{(link_data_width_p-1){1'b0}}, reset_r};
          end
          else begin
            resp_data_n = '0;
          end
        end
        else begin
          config_v_o = 1'b1;
          config_w_o = 1'b0; 

          config_state_n = config_ready_i
            ? WAIT_READ_DATA
            : READ_DATA;
        end
      end

      WAIT_READ_DATA: begin
        config_ready_o = 1'b1;
        resp_data_n  = config_v_i
          ? config_data_i
          : resp_data_r;
        config_state_n = config_v_i
          ? SEND_RESP
          : WAIT_READ_DATA;
      end
      
      SEND_RESP: begin
        v_o = 1'b1;
        config_state_n = WAIT;
      end 

      // we should never get into this state, but if we do return to reset
      // state;
      default: begin
        config_state_n = WAIT;
      end
    endcase
  end

  assign reset_o = reset_r;
  assign freeze_o = freeze_r;
  assign data_o = resp_data_r;
  
  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      reset_r <= 1'b0;
      freeze_r <= freeze_init_p;
      config_state_r <= WAIT;
    end
    else begin
      reset_r <= reset_n;
      freeze_r <= freeze_n;
      config_state_r <= config_state_n;
      addr_r <= addr_n;
      data_r <= data_n;
      mask_r <= mask_n;
      resp_data_r <= resp_data_n;
    end
  end

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (config_state_r == WRITE_DATA) begin
      if (is_ctrl_addr) begin
        if (is_freeze_addr) begin
          $display("[BP BRIDGE CONFIG] FREEZE = %d", data_r[0]);
        end
        if (is_reset_addr) begin
          $display("[BP BRIDGE CONFIG] RESET = %d", data_r[0]);
        end
      end
    end
  end
  // synopsys translate_on

endmodule
