/**
 *  bp_rolly_lce_me.v
 */ 

`include "bp_be_dcache_pkt.vh"

module bp_rolly_lce_me
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_cce_pkg::*;
  #(parameter data_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter paddr_width_p="inv"
    , parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter mem_els_p="inv"
    , parameter boot_rom_els_p="inv"
    , parameter num_cce_inst_ram_els_p="inv"
    
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam block_size_in_words_lp=ways_p
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)

    , localparam lce_data_width_lp=(ways_p*data_width_p)
    , localparam block_size_in_bytes_lp=(lce_data_width_lp / 8)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
      
    , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(bp_page_offset_width_gp,data_width_p)

    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_inst_ram_els_p)
  )
  (
    input clk_i
    , input reset_i
  
    , input [num_lce_p-1:0][dcache_pkt_width_lp-1:0] dcache_pkt_i
    , input [num_lce_p-1:0][ptag_width_lp-1:0] ptag_i
    , input [num_lce_p-1:0] dcache_pkt_v_i
    , output logic [num_lce_p-1:0] dcache_pkt_ready_o

    , output logic [num_lce_p-1:0] v_o
    , output logic [num_lce_p-1:0][data_width_p-1:0] data_o    
  );

  // casting structs
  //
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp,data_width_p);

  // rolly fifo
  //
  logic [num_lce_p-1:0] rollback_li;
  logic [num_lce_p-1:0][ptag_width_lp-1:0] rolly_ptag_lo;
  bp_be_dcache_pkt_s [num_lce_p-1:0] rolly_dcache_pkt_lo;
  logic [num_lce_p-1:0] rolly_v_lo;
  logic [num_lce_p-1:0] rolly_yumi_li;

  for (genvar i = 0; i < num_lce_p; i++) begin
    bsg_fifo_1r1w_rolly #(
      .width_p(dcache_pkt_width_lp+ptag_width_lp)
      ,.els_p(8)
    ) rolly (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.roll_v_i(rollback_li[i])
      ,.clr_v_i(1'b0)
    
      ,.ckpt_v_i(v_o[i])

      ,.data_i({ptag_i[i], dcache_pkt_i[i]})
      ,.v_i(dcache_pkt_v_i[i] & dcache_pkt_ready_o[i])
      ,.ready_o(dcache_pkt_ready_o[i])
  
      ,.data_o({rolly_ptag_lo[i], rolly_dcache_pkt_lo[i]})
      ,.v_o(rolly_v_lo[i])
      ,.yumi_i(rolly_yumi_li[i])
    );
  end

  // dcache
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_data_cmd_s(num_lce_p, lce_data_width_lp, ways_p);

  bp_lce_cce_req_s [num_lce_p-1:0] lce_req_lo;
  logic [num_lce_p-1:0] lce_req_v_lo;
  logic [num_lce_p-1:0] lce_req_ready_li;

  bp_lce_cce_resp_s [num_lce_p-1:0] lce_resp_lo;
  logic [num_lce_p-1:0] lce_resp_v_lo;
  logic [num_lce_p-1:0] lce_resp_ready_li;

  bp_lce_cce_data_resp_s [num_lce_p-1:0] lce_data_resp_lo;
  logic [num_lce_p-1:0] lce_data_resp_v_lo;
  logic [num_lce_p-1:0] lce_data_resp_ready_li;

  bp_cce_lce_cmd_s [num_lce_p-1:0] lce_cmd_li;
  logic [num_lce_p-1:0] lce_cmd_v_li;
  logic [num_lce_p-1:0] lce_cmd_ready_lo;

  bp_lce_data_cmd_s [num_lce_p-1:0] lce_data_cmd_li;
  logic [num_lce_p-1:0] lce_data_cmd_v_li;
  logic [num_lce_p-1:0] lce_data_cmd_ready_lo;

  bp_lce_data_cmd_s [num_lce_p-1:0] lce_data_cmd_lo;
  logic [num_lce_p-1:0] lce_data_cmd_v_lo;
  logic [num_lce_p-1:0] lce_data_cmd_ready_li;

  logic [num_lce_p-1:0] dcache_tlb_miss_li;
  logic [num_lce_p-1:0][ptag_width_lp-1:0] dcache_ptag_li;
  logic [num_lce_p-1:0] cache_miss_lo;
  logic [num_lce_p-1:0] dcache_ready_lo;

  for (genvar i = 0; i < num_lce_p; i++) begin
    bp_be_dcache #(
      .data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.debug_p(1)
    ) dcache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.lce_id_i((lce_id_width_lp)'(i))
 
      ,.dcache_pkt_i(rolly_dcache_pkt_lo[i])
      ,.v_i(rolly_v_lo[i])
      ,.ready_o(dcache_ready_lo[i])

      ,.v_o(v_o[i])
      ,.data_o(data_o[i])

      ,.tlb_miss_i(dcache_tlb_miss_li[i])
      ,.ptag_i(dcache_ptag_li[i])

      ,.cache_miss_o(cache_miss_lo[i])
      ,.poison_i(cache_miss_lo[i])

      ,.lce_req_o(lce_req_lo[i])
      ,.lce_req_v_o(lce_req_v_lo[i])
      ,.lce_req_ready_i(lce_req_ready_li[i])

      ,.lce_resp_o(lce_resp_lo[i])
      ,.lce_resp_v_o(lce_resp_v_lo[i])
      ,.lce_resp_ready_i(lce_resp_ready_li[i])

      ,.lce_data_resp_o(lce_data_resp_lo[i])
      ,.lce_data_resp_v_o(lce_data_resp_v_lo[i])
      ,.lce_data_resp_ready_i(lce_data_resp_ready_li[i])

      ,.lce_cmd_i(lce_cmd_li[i])
      ,.lce_cmd_v_i(lce_cmd_v_li[i])
      ,.lce_cmd_ready_o(lce_cmd_ready_lo[i])

      ,.lce_data_cmd_i(lce_data_cmd_li[i])
      ,.lce_data_cmd_v_i(lce_data_cmd_v_li[i])
      ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[i])

      ,.lce_data_cmd_o(lce_data_cmd_lo[i])
      ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[i])
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[i])
    );
  end

  for (genvar i = 0; i < num_lce_p; i++) begin
    assign rollback_li[i] = cache_miss_lo[i];
    assign rolly_yumi_li[i] = rolly_v_lo[i] & dcache_ready_lo[i];
  end

  // mock tlb
  //
  for (genvar i = 0; i < num_lce_p; i++) begin
    mock_tlb #(
      .tag_width_p(ptag_width_lp)
    ) tlb (
      .clk_i(clk_i)

      ,.v_i(rolly_yumi_li[i])
      ,.tag_i(rolly_ptag_lo[i])

      ,.tag_o(dcache_ptag_li[i])
      ,.tlb_miss_o(dcache_tlb_miss_li[i])
    );
  end


  // CCE Boot ROM

  // Memory End
  //
  `declare_bp_me_if(paddr_width_p,lce_data_width_lp,num_lce_p,ways_p); 

  logic [num_cce_p-1:0][inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
  logic [num_cce_p-1:0][`bp_cce_inst_width-1:0] cce_inst_boot_rom_data;
  
  bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp;
  logic [num_cce_p-1:0] mem_resp_v;
  logic [num_cce_p-1:0] mem_resp_ready;

  bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp;
  logic [num_cce_p-1:0] mem_data_resp_v;
  logic [num_cce_p-1:0] mem_data_resp_ready;

  bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd;
  logic [num_cce_p-1:0] mem_cmd_v;
  logic [num_cce_p-1:0] mem_cmd_yumi;

  bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd;
  logic [num_cce_p-1:0] mem_data_cmd_v;
  logic [num_cce_p-1:0] mem_data_cmd_yumi;

  bp_me_top #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.paddr_width_p(paddr_width_p)
    ,.lce_assoc_p(ways_p)
    ,.lce_sets_p(sets_p)
    ,.block_size_in_bytes_p(block_size_in_bytes_lp)
    ,.num_inst_ram_els_p(num_cce_inst_ram_els_p)
  ) me (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_cmd_o(lce_cmd_li)
    ,.lce_cmd_v_o(lce_cmd_v_li)
    ,.lce_cmd_ready_i(lce_cmd_ready_lo)

    ,.lce_data_cmd_o(lce_data_cmd_li)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

    ,.lce_data_cmd_i(lce_data_cmd_lo)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

    ,.lce_req_i(lce_req_lo)
    ,.lce_req_v_i(lce_req_v_lo)
    ,.lce_req_ready_o(lce_req_ready_li)

    ,.lce_resp_i(lce_resp_lo)
    ,.lce_resp_v_i(lce_resp_v_lo)
    ,.lce_resp_ready_o(lce_resp_ready_li)

    ,.lce_data_resp_i(lce_data_resp_lo)
    ,.lce_data_resp_v_i(lce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(lce_data_resp_ready_li)

    ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
    ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)

    ,.mem_resp_i(mem_resp)
    ,.mem_resp_v_i(mem_resp_v)
    ,.mem_resp_ready_o(mem_resp_ready)

    ,.mem_data_resp_i(mem_data_resp)
    ,.mem_data_resp_v_i(mem_data_resp_v)
    ,.mem_data_resp_ready_o(mem_data_resp_ready)

    ,.mem_cmd_o(mem_cmd)
    ,.mem_cmd_v_o(mem_cmd_v)
    ,.mem_cmd_yumi_i(mem_cmd_yumi)

    ,.mem_data_cmd_o(mem_data_cmd)
    ,.mem_data_cmd_v_o(mem_data_cmd_v)
    ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)
  );

  for (genvar i = 0; i < num_cce_p; i++) begin
    bp_mem
      #(.num_lce_p(num_lce_p)
        ,.num_cce_p(num_cce_p)
        ,.paddr_width_p(paddr_width_p)
        ,.lce_assoc_p(ways_p)
        ,.block_size_in_bytes_p(lce_data_width_lp/8)
        ,.lce_sets_p(sets_p)
        ,.mem_els_p(mem_els_p)
        ,.boot_rom_width_p(lce_data_width_lp)
        ,.boot_rom_els_p(boot_rom_els_p)
        )
      bp_mem
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.mem_cmd_i(mem_cmd[i])
        ,.mem_cmd_v_i(mem_cmd_v[i])
        ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

        ,.mem_data_cmd_i(mem_data_cmd[i])
        ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
        ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

        ,.mem_resp_o(mem_resp[i])
        ,.mem_resp_v_o(mem_resp_v[i])
        ,.mem_resp_ready_i(mem_resp_ready[i])

        ,.mem_data_resp_o(mem_data_resp[i])
        ,.mem_data_resp_v_o(mem_data_resp_v[i])
        ,.mem_data_resp_ready_i(mem_data_resp_ready[i])

        ,.boot_rom_addr_o()
        ,.boot_rom_data_i('0)
        );

      bp_cce_inst_rom
        #(.width_p(`bp_cce_inst_width)
          ,.addr_width_p(inst_ram_addr_width_lp)
        ) cce_inst_rom (
          .addr_i(cce_inst_boot_rom_addr[i])
          ,.data_o(cce_inst_boot_rom_data[i])
        );

  end

endmodule
