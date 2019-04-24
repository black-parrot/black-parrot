/**
 *  bp_rolly_lce_me_manycore.v
 *
 */

`include "bsg_manycore_packet.vh"

module bp_rolly_lce_me_manycore
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_cce_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_half_core_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter link_data_width_p=32
    , parameter link_addr_width_p=10
    , parameter load_id_width_p=11
    , parameter y_width_p=1
    , parameter x_width_p=4
    
    , localparam y_cord_width_lp=`BSG_SAFE_CLOG2(y_width_p)
    , localparam x_cord_width_lp=`BSG_SAFE_CLOG2(x_width_p)

    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)

    , localparam dcache_pkt_width_lp=
      `bp_be_dcache_pkt_width(bp_page_offset_width_gp,dword_width_p)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
  )
  (
    input bp_clk_i
    , input manycore_clk_i
    , input reset_i

    , input [dcache_pkt_width_lp-1:0] dcache_pkt_i
    , input [ptag_width_lp-1:0] ptag_i
    , input dcache_pkt_v_i
    , output logic dcache_pkt_ready_o

    , output logic v_o
    , output logic [dword_width_p-1:0] data_o
  );

  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp,dword_width_p);

  // rolly fifo
  //
  logic rollback;
  logic [ptag_width_lp-1:0] rolly_ptag;
  bp_be_dcache_pkt_s rolly_dcache_pkt;
  logic rolly_v_lo;
  logic rolly_yumi_li;

  bsg_fifo_1r1w_rolly #(
    .width_p(dcache_pkt_width_lp+ptag_width_lp)
    ,.els_p(8)
  ) rolly (
    .clk_i(bp_clk_i)
    ,.reset_i(reset_i)

    ,.roll_v_i(rollback)
    ,.clr_v_i(1'b0)
    ,.ckpt_v_i(v_o)

    ,.data_i({ptag_i, dcache_pkt_i})
    ,.v_i(dcache_pkt_v_i)
    ,.ready_o(dcache_pkt_ready_o)

    ,.data_o({rolly_ptag, rolly_dcache_pkt})
    ,.v_o(rolly_v_lo)
    ,.yumi_i(rolly_yumi_li)
  );

  // dcache
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
  `declare_bp_lce_data_cmd_s(num_lce_p, cce_block_width_p, lce_assoc_p);

  bp_lce_cce_req_s lce_req;
  logic lce_req_v;
  logic lce_req_ready;

  bp_lce_cce_resp_s lce_resp;
  logic lce_resp_v;
  logic lce_resp_ready;

  bp_lce_cce_data_resp_s lce_data_resp;
  logic lce_data_resp_v;
  logic lce_data_resp_ready;

  bp_cce_lce_cmd_s lce_cmd;
  logic lce_cmd_v;
  logic lce_cmd_ready;

  bp_lce_data_cmd_s lce_data_cmd_lo;
  logic lce_data_cmd_v_lo;
  logic lce_data_cmd_ready_li;

  bp_lce_data_cmd_s lce_data_cmd_li;
  logic lce_data_cmd_v_li;
  logic lce_data_cmd_ready_lo;

  logic tlb_miss;
  logic [ptag_width_lp-1:0] dcache_ptag_li;
  logic cache_miss;
  logic dcache_ready_lo;

  bp_be_dcache #(
    .data_width_p(dword_width_p)
    ,.paddr_width_p(paddr_width_p)
    ,.sets_p(lce_sets_p)
    ,.ways_p(lce_assoc_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.debug_p(1)
  ) dcache (
    .clk_i(bp_clk_i)
    ,.reset_i(reset_i)
    ,.lce_id_i(lce_id_width_lp'(0))

    ,.dcache_pkt_i(rolly_dcache_pkt)
    ,.v_i(rolly_v_lo)
    ,.ready_o(dcache_ready_lo)

    ,.v_o(v_o)
    ,.data_o(data_o)

    ,.tlb_miss_i(tlb_miss)
    ,.ptag_i(dcache_ptag_li)
    ,.uncached_i(dcache_ptag_li[ptag_width_lp-1])

    ,.cache_miss_o(cache_miss)
    ,.poison_i(cache_miss)

    ,.lce_req_o(lce_req)
    ,.lce_req_v_o(lce_req_v)
    ,.lce_req_ready_i(lce_req_ready)

    ,.lce_resp_o(lce_resp)
    ,.lce_resp_v_o(lce_resp_v)
    ,.lce_resp_ready_i(lce_resp_ready)

    ,.lce_data_resp_o(lce_data_resp)
    ,.lce_data_resp_v_o(lce_data_resp_v)
    ,.lce_data_resp_ready_i(lce_data_resp_ready)

    ,.lce_cmd_i(lce_cmd)
    ,.lce_cmd_v_i(lce_cmd_v)
    ,.lce_cmd_ready_o(lce_cmd_ready)

    ,.lce_data_cmd_i(lce_data_cmd_li)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

    ,.lce_data_cmd_o(lce_data_cmd_lo)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li)
  );
  
  assign rollback = cache_miss;
  assign rolly_yumi_li = rolly_v_lo & dcache_ready_lo;

  // mock tlb
  //
  mock_tlb #(
    .tag_width_p(ptag_width_lp)
  ) tlb (
    .clk_i(bp_clk_i)

    ,.v_i(rolly_yumi_li)
    ,.tag_i(rolly_ptag)

    ,.tag_o(dcache_ptag_li)
    ,.tlb_miss_o(tlb_miss)
  );

  // memory end
  //
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

  logic [inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
  logic [`bp_cce_inst_width-1:0] cce_inst_boot_rom_data;

  bp_mem_cce_resp_s mem_resp;
  logic mem_resp_v;
  logic mem_resp_ready;

  bp_mem_cce_data_resp_s mem_data_resp;
  logic mem_data_resp_v;
  logic mem_data_resp_ready;

  bp_cce_mem_cmd_s mem_cmd;
  logic mem_cmd_v;
  logic mem_cmd_yumi;

  bp_cce_mem_data_cmd_s mem_data_cmd;
  logic mem_data_cmd_v;
  logic mem_data_cmd_yumi;

  bp_me_top #(
    .cfg_p(cfg_p)
    ,.cfg_link_addr_width_p(16)
    ,.cfg_link_data_width_p(32)
  ) me (
    .clk_i(bp_clk_i)
    ,.reset_i(reset_i)
    // TODO: add freeze
    ,.freeze_i('0)

    // TODO: hook up config port
    ,.config_addr_i('0)
    ,.config_data_i('0)
    ,.config_v_i('0)
    ,.config_w_i('0)
    ,.config_ready_o()
    ,.config_data_o()
    ,.config_v_o()
    ,.config_ready_i('0)

    ,.lce_cmd_o(lce_cmd)
    ,.lce_cmd_v_o(lce_cmd_v)
    ,.lce_cmd_ready_i(lce_cmd_ready)

    ,.lce_data_cmd_o(lce_data_cmd_li)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

    ,.lce_data_cmd_i(lce_data_cmd_lo)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

    ,.lce_req_i(lce_req)
    ,.lce_req_v_i(lce_req_v)
    ,.lce_req_ready_o(lce_req_ready)

    ,.lce_resp_i(lce_resp)
    ,.lce_resp_v_i(lce_resp_v)
    ,.lce_resp_ready_o(lce_resp_ready)

    ,.lce_data_resp_i(lce_data_resp)
    ,.lce_data_resp_v_i(lce_data_resp_v)
    ,.lce_data_resp_ready_o(lce_data_resp_ready)

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

  // cce boot rom
  //
  bp_cce_inst_rom #(
    .width_p(`bp_cce_inst_width)
    ,.addr_width_p(inst_ram_addr_width_lp)
  ) cce_rom (
    .addr_i(cce_inst_boot_rom_addr)
    ,.data_o(cce_inst_boot_rom_data)
  );

  // mesh_node
  //
  `declare_bsg_manycore_link_sif_s(link_addr_width_p, link_data_width_p,
    x_cord_width_lp, y_cord_width_lp, load_id_width_p);

  bsg_manycore_link_sif_s [x_width_p-1:0][S:W] links_sif_li;
  bsg_manycore_link_sif_s [x_width_p-1:0][S:W] links_sif_lo;
  bsg_manycore_link_sif_s [x_width_p-1:0] proc_link_sif_li;
  bsg_manycore_link_sif_s [x_width_p-1:0] proc_link_sif_lo;

  for (genvar i = 0; i < x_width_p; i++) begin
    bsg_manycore_mesh_node #(
      .x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.data_width_p(link_data_width_p)
      ,.addr_width_p(link_addr_width_p)
      ,.load_id_width_p(load_id_width_p)
    ) mesh_node (
      .clk_i(manycore_clk_i)
      ,.reset_i(reset_i)
  
      ,.links_sif_i(links_sif_li[i])
      ,.links_sif_o(links_sif_lo[i])
  
      ,.proc_link_sif_i(proc_link_sif_li[i])
      ,.proc_link_sif_o(proc_link_sif_lo[i])

      ,.my_x_i(x_cord_width_lp'(i))
      ,.my_y_i(y_cord_width_lp'(0))
    );

    if (i != 0) begin
      assign links_sif_li[i][W] = links_sif_lo[i-1][E];
    end

    if (i != x_width_p-1) begin
      assign links_sif_li[i][E] = links_sif_lo[i+1][W];
    end

    if (i == 0) begin
      bsg_manycore_link_sif_tieoff #(
        .addr_width_p(link_addr_width_p)
        ,.data_width_p(link_data_width_p)
        ,.load_id_width_p(load_id_width_p)
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
      ) node_w_tieoff (
        .clk_i(manycore_clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(links_sif_lo[i][W])
        ,.link_sif_o(links_sif_li[i][W])
      );
    end

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(link_addr_width_p)
      ,.data_width_p(link_data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) node_n_tieoff (
      .clk_i(manycore_clk_i)
      ,.reset_i(reset_i)

      ,.link_sif_i(links_sif_lo[i][N])
      ,.link_sif_o(links_sif_li[i][N])
    );

    if (i == x_width_p-1) begin
      bsg_manycore_link_sif_tieoff #(
        .addr_width_p(link_addr_width_p)
        ,.data_width_p(link_data_width_p)
        ,.load_id_width_p(load_id_width_p)
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
      ) node_e_tieoff (
        .clk_i(manycore_clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(links_sif_lo[i][E])
        ,.link_sif_o(links_sif_li[i][E])
      );
    end

    if (i != 0) begin
      bsg_manycore_link_sif_tieoff #(
        .addr_width_p(link_addr_width_p)
        ,.data_width_p(link_data_width_p)
        ,.load_id_width_p(load_id_width_p)
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
      ) node_p_tieoff (
        .clk_i(manycore_clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(proc_link_sif_lo[i])
        ,.link_sif_o(proc_link_sif_li[i])
      );
    end
  end


  // SRAM
  //
  for (genvar i = 0; i < x_width_p; i++) begin
    // each bank holds 4KB.
    bsg_manycore_ram_model #(
      .x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.data_width_p(link_data_width_p)
      ,.addr_width_p(link_addr_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.els_p(2**10)
      ,.self_reset_p(1)
    ) ram_model (
      .clk_i(manycore_clk_i)
      ,.reset_i(reset_i)

      ,.link_sif_i(links_sif_lo[i][S])
      ,.link_sif_o(links_sif_li[i][S])

      ,.my_x_i(x_cord_width_lp'(i))
      ,.my_y_i(y_cord_width_lp'(1))
    );
  end


  // bridge module
  //
  bp_me_cce_to_manycore_link #(
    .link_data_width_p(link_data_width_p)
    ,.link_addr_width_p(link_addr_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)
    ,.load_id_width_p(load_id_width_p)

    ,.paddr_width_p(paddr_width_p)
    ,.num_lce_p(num_lce_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bits_p(cce_block_width_p)

    ,.freeze_init_p(0)
  ) bridge (
    .link_clk_i(manycore_clk_i)
    ,.bp_clk_i(bp_clk_i)
    ,.async_reset_i(reset_i)

    ,.my_x_i(x_cord_width_lp'(0))
    ,.my_y_i(y_cord_width_lp'(0))
    
    ,.link_sif_i(proc_link_sif_lo[0])
    ,.link_sif_o(proc_link_sif_li[0])

    ,.mem_cmd_i(mem_cmd)
    ,.mem_cmd_v_i(mem_cmd_v)
    ,.mem_cmd_yumi_o(mem_cmd_yumi)

    ,.mem_data_cmd_i(mem_data_cmd)
    ,.mem_data_cmd_v_i(mem_data_cmd_v)
    ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi)

    ,.mem_resp_o(mem_resp)
    ,.mem_resp_v_o(mem_resp_v)
    ,.mem_resp_ready_i(mem_resp_ready)

    ,.mem_data_resp_o(mem_data_resp)
    ,.mem_data_resp_v_o(mem_data_resp_v)
    ,.mem_data_resp_ready_i(mem_data_resp_ready)

    ,.config_addr_o()
    ,.config_data_o()
    ,.config_v_o()
    ,.config_w_o()
    ,.config_ready_i(1'b0)

    ,.config_data_i('0)
    ,.config_v_i(1'b0)
    ,.config_ready_o()

    ,.reset_o()
  );



endmodule
