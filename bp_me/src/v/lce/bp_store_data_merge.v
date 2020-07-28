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

   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, fill_width_p, cache)
  )
  (
    input [fill_width_p-1:0] data0_i
    , input [cache_req_width_lp-1:0] cache_req_i

    , input write_v_i
    , output [fill_width_p-1:0] data_o
  );

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, fill_width_p, cache);

  `bp_cast_i(bp_cache_req_s, cache_req);

  logic [`BSG_SAFE_CLOG2(fill_width_p)-1:0] addr_fill_slice;
  logic [5:0] byte_select;
  logic [fill_width_p-1:0] write_mask;

  if (fill_width_p == 64)
    begin : fill_dword
      assign addr_fill_slice = '0;
    end
  else if (fill_width_p == block_width_p)
    begin : fill_block
      assign addr_fill_slice = (cache_req_cast_i.addr[block_offset_width_lp-1:3] << 6);
    end
  else 
    begin : fill_chunks
      assign addr_fill_slice = (cache_req_cast_i.addr[block_offset_width_lp-fill_cnt_width_lp-1:3] << 6);
    end

  assign byte_select = (cache_req_cast_i.addr[2:0] << 3);

  bsg_mux_bitwise
   #(.width_p(fill_width_p))
    write_merge_mux
     (.data0_i(data0_i)
      ,.data1_i({num_dwords_per_fill_lp{cache_req_cast_i.data}})
      ,.sel_i(write_mask)
      ,.data_o(data_o)
      );

  always_comb
    begin
      if (write_v_i) begin
        case(cache_req_cast_i.size)
          e_size_1B:
            begin
              write_mask = fill_width_p'(({8{1'b1}} << addr_fill_slice) << byte_select);
            end
          e_size_2B:
            begin
              write_mask = fill_width_p'(({16{1'b1}} << addr_fill_slice) << byte_select);
            end
          e_size_4B:
            begin
              write_mask = fill_width_p'(({32{1'b1}} << addr_fill_slice) << byte_select);
            end
          e_size_8B:
            begin
              write_mask = fill_width_p'(({64{1'b1}} << addr_fill_slice) << byte_select);
            end
          default: 
            begin
              write_mask = fill_width_p'(({64{1'b1}} << addr_fill_slice) << byte_select);
            end
        endcase
      end else
        write_mask = '0;
    end

endmodule    
