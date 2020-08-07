/**
 *  Name:
 *    bp_store_data_merge.v
 *
 *
 *  Description:
 *    Common module performing the merging of store data into the incoming
 *    memory packet
 *
 */

module bp_store_data_merge
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter assoc_p       = "inv"
   , parameter sets_p        = "inv"
   , parameter block_width_p = "inv"
   , parameter fill_width_p  = block_width_p

   , localparam bank_width_lp          = block_width_p / assoc_p
   , localparam num_dwords_per_fill_lp = fill_width_p/ dword_width_p
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam bank_offset_width_lp   = `BSG_SAFE_CLOG2(assoc_p)
   , localparam block_offset_width_lp  = (bank_offset_width_lp + byte_offset_width_lp)
   , localparam block_size_in_fill_lp  = block_width_p / fill_width_p
   , localparam fill_cnt_width_lp      = `BSG_SAFE_CLOG2(block_size_in_fill_lp)
   , localparam num_byte_segments_lp   = fill_width_p / 8
  )
  (
    input [fill_width_p-1:0] data0_i
    , input [dword_width_p-1:0] data1_i
    , input [paddr_width_p-1:0] addr_i
    , input [$bits(bp_cache_req_size_e)-1:0] size_i

    , input write_v_i
    , output [fill_width_p-1:0] data_o
  );

  logic [`BSG_SAFE_CLOG2(num_byte_segments_lp)-1:0] addr_fill_slice;
  logic [2:0] byte_select;
  logic [num_byte_segments_lp-1:0] write_mask;

  if (fill_width_p == 64)
    begin : fill_dword
      assign addr_fill_slice = '0;
    end
  else if (fill_width_p == block_width_p)
    begin : fill_block
      // Multiply by 8 to get to the correct dword offset
      assign addr_fill_slice = (addr_i[block_offset_width_lp-1:3] << 3);
    end
  else 
    begin : fill_chunks
      // Multiply by 8 to get to the correct dword offset
      assign addr_fill_slice = (addr_i[block_offset_width_lp-fill_cnt_width_lp-1:3] << 3);
    end

  assign byte_select = addr_i[2:0];

  bsg_mux_segmented
   #(.segments_p(num_byte_segments_lp)
     ,.segment_width_p(8)
     )
    write_merge_mux
     (.data0_i(data0_i)
      ,.data1_i({num_dwords_per_fill_lp{data1_i}})
      ,.sel_i(write_mask)
      ,.data_o(data_o)
      );

  always_comb
    begin
      if (write_v_i) begin
        case(size_i)
          e_size_1B:
            begin
              write_mask = fill_width_p'((1'b1 << addr_fill_slice) << byte_select);
            end
          e_size_2B:
            begin
              write_mask = fill_width_p'(({2{1'b1}} << addr_fill_slice) << byte_select);
            end
          e_size_4B:
            begin
              write_mask = fill_width_p'(({4{1'b1}} << addr_fill_slice) << byte_select);
            end
          e_size_8B:
            begin
              write_mask = fill_width_p'(({8{1'b1}} << addr_fill_slice) << byte_select);
            end
          default: 
            begin
              write_mask = fill_width_p'(({8{1'b1}} << addr_fill_slice) << byte_select);
            end
        endcase
      end else
        write_mask = '0;
    end

endmodule
