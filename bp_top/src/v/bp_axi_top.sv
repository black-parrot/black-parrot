
// This module wraps a BP core with AXI interfaces. For an example usage
//   see https://github.com/black-parrot-hdk/zynq-parrot

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_axi_top
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 // see bp_common/src/include/bp_common_aviary_pkgdef.svh for a list of configurations that you can try!
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // AXI4-LITE PARAMS
   , parameter axil_addr_width_p = 32
   , parameter axil_data_width_p = 32

   , parameter axi_addr_width_p = 32
   , parameter axi_data_width_p = 64
   , parameter axi_id_width_p   = 6
   , parameter axi_len_width_p  = 4
   , parameter axi_size_width_p = 3

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, uce)
   )
  (input                                       clk_i
   , input                                     reset_i

   //======================== Outgoing I/O ========================
   , output logic [axil_addr_width_p-1:0]      m_axil_awaddr_o
   , output axi_prot_type_e                    m_axil_awprot_o
   , output logic                              m_axil_awvalid_o
   , input                                     m_axil_awready_i

   , output logic [axil_data_width_p-1:0]      m_axil_wdata_o
   , output logic [(axil_data_width_p>>3)-1:0] m_axil_wstrb_o
   , output logic                              m_axil_wvalid_o
   , input                                     m_axil_wready_i

   , input axi_resp_type_e                     m_axil_bresp_i
   , input                                     m_axil_bvalid_i
   , output logic                              m_axil_bready_o

   , output logic [axil_addr_width_p-1:0]      m_axil_araddr_o
   , output axi_prot_type_e                    m_axil_arprot_o
   , output logic                              m_axil_arvalid_o
   , input                                     m_axil_arready_i

   , input [axil_data_width_p-1:0]             m_axil_rdata_i
   , input axi_resp_type_e                     m_axil_rresp_i
   , input                                     m_axil_rvalid_i
   , output logic                              m_axil_rready_o

   //======================== Incoming I/O ========================
   , input [axil_addr_width_p-1:0]             s_axil_awaddr_i
   , input axi_prot_type_e                     s_axil_awprot_i
   , input                                     s_axil_awvalid_i
   , output logic                              s_axil_awready_o

   , input [axil_data_width_p-1:0]             s_axil_wdata_i
   , input [(axil_data_width_p>>3)-1:0]        s_axil_wstrb_i
   , input                                     s_axil_wvalid_i
   , output logic                              s_axil_wready_o

   , output axi_resp_type_e                    s_axil_bresp_o
   , output logic                              s_axil_bvalid_o
   , input                                     s_axil_bready_i

   , input [axil_addr_width_p-1:0]             s_axil_araddr_i
   , input axi_prot_type_e                     s_axil_arprot_i
   , input                                     s_axil_arvalid_i
   , output logic                              s_axil_arready_o

   , output logic [axil_data_width_p-1:0]      s_axil_rdata_o
   , output axi_resp_type_e                    s_axil_rresp_o
   , output logic                              s_axil_rvalid_o
   , input                                     s_axil_rready_i

   //======================== Outgoing Memory ========================
   , output logic [axi_addr_width_p-1:0]       m_axi_awaddr_o
   , output logic                              m_axi_awvalid_o
   , input                                     m_axi_awready_i
   , output logic [axi_id_width_p-1:0]         m_axi_awid_o
   , output logic [1:0]                        m_axi_awlock_o
   , output logic [3:0]                        m_axi_awcache_o
   , output logic [2:0]                        m_axi_awprot_o
   , output logic [axi_len_width_p-1:0]        m_axi_awlen_o
   , output logic [axi_size_width_p-1:0]       m_axi_awsize_o
   , output logic [1:0]                        m_axi_awburst_o
   , output logic [3:0]                        m_axi_awqos_o

   , output logic [axi_data_width_p-1:0]       m_axi_wdata_o
   , output logic                              m_axi_wvalid_o
   , input                                     m_axi_wready_i
   , output logic [axi_id_width_p-1:0]         m_axi_wid_o
   , output logic                              m_axi_wlast_o
   , output logic [(axi_data_width_p>>3)-1:0]  m_axi_wstrb_o

   , input                                     m_axi_bvalid_i
   , output logic                              m_axi_bready_o
   , input [axi_id_width_p-1:0]                m_axi_bid_i
   , input [1:0]                               m_axi_bresp_i

   , output logic [axi_addr_width_p-1:0]       m_axi_araddr_o
   , output logic                              m_axi_arvalid_o
   , input                                     m_axi_arready_i
   , output logic [axi_id_width_p-1:0]         m_axi_arid_o
   , output logic [1:0]                        m_axi_arlock_o
   , output logic [3:0]                        m_axi_arcache_o
   , output logic [2:0]                        m_axi_arprot_o
   , output logic [axi_len_width_p-1:0]        m_axi_arlen_o
   , output logic [axi_size_width_p-1:0]       m_axi_arsize_o
   , output logic [1:0]                        m_axi_arburst_o
   , output logic [3:0]                        m_axi_arqos_o

   , input [axi_data_width_p-1:0]              m_axi_rdata_i
   , input                                     m_axi_rvalid_i
   , output logic                              m_axi_rready_o
   , input [axi_id_width_p-1:0]                m_axi_rid_i
   , input                                     m_axi_rlast_i
   , input [1:0]                               m_axi_rresp_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, uce);
  bp_bedrock_uce_mem_header_s io_cmd_header_li, io_resp_header_lo;
  logic [uce_fill_width_p-1:0] io_cmd_data_li, io_resp_data_lo;
  logic io_cmd_v_li, io_cmd_ready_and_lo, io_resp_v_lo, io_resp_yumi_li;
  bp_bedrock_uce_mem_header_s io_cmd_header_lo, io_resp_header_li;
  logic [uce_fill_width_p-1:0] io_cmd_data_lo, io_resp_data_li;
  logic io_cmd_v_lo, io_cmd_ready_and_li, io_resp_v_li, io_resp_ready_and_lo;

  `declare_bsg_cache_dma_pkt_s(daddr_width_p);
  bsg_cache_dma_pkt_s [l2_banks_p-1:0] dma_pkt_lo;
  logic [l2_banks_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_banks_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_banks_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  if (multicore_p == 0)
    begin : w
      // note: bp_unicore has L2 cache; (bp_unicore_lite does not, but does not have dma_* interface
      // and would need mem_cmd/mem_resp-to-axi converter to be written.)
      bp_unicore
       #(.bp_params_p(bp_params_p))
       unicore
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        // Irrelevant for current AXI wrapper
        ,.my_did_i('0)
        ,.host_did_i('0)
        ,.my_cord_i('0)

        // Outgoing I/O
        ,.io_cmd_header_o(io_cmd_header_lo)
        ,.io_cmd_data_o(io_cmd_data_lo)
        ,.io_cmd_v_o(io_cmd_v_lo)
        ,.io_cmd_ready_and_i(io_cmd_ready_and_li)
        ,.io_cmd_last_o()

        ,.io_resp_header_i(io_resp_header_li)
        ,.io_resp_data_i(io_resp_data_li)
        ,.io_resp_v_i(io_resp_v_li)
        ,.io_resp_ready_and_o(io_resp_ready_and_lo)
        ,.io_resp_last_i(io_resp_v_li) // stub

        // Incoming I/O
        ,.io_cmd_header_i(io_cmd_header_li)
        ,.io_cmd_data_i(io_cmd_data_li)
        ,.io_cmd_v_i(io_cmd_v_li)
        ,.io_cmd_ready_and_o(io_cmd_ready_and_lo)
        ,.io_cmd_last_i(io_cmd_v_li) // stub

        ,.io_resp_header_o(io_resp_header_lo)
        ,.io_resp_data_o(io_resp_data_lo)
        ,.io_resp_v_o(io_resp_v_lo)
        ,.io_resp_ready_and_i(io_resp_yumi_li)
        ,.io_resp_last_o()

        ,.dma_pkt_o(dma_pkt_lo)
        ,.dma_pkt_v_o(dma_pkt_v_lo)
        ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

        ,.dma_data_i(dma_data_li)
        ,.dma_data_v_i(dma_data_v_li)
        ,.dma_data_ready_and_o(dma_data_ready_and_lo)

        ,.dma_data_o(dma_data_lo)
        ,.dma_data_v_o(dma_data_v_lo)
        ,.dma_data_ready_and_i(dma_data_yumi_li)
        );
    end
  else
    begin : w
      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);
      bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
      bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;
      bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;
      bp_mem_noc_ral_link_s [mc_x_dim_p-1:0] dram_cmd_link_lo, dram_resp_link_li;

      assign stub_cmd_link_li  = '0;
      assign stub_resp_link_li = '0;

      wire [did_width_p-1:0] did_li = 1;
      wire [did_width_p-1:0] host_did_li = '1;

      bp_multicore
       #(.bp_params_p(bp_params_p))
       multicore
        (.core_clk_i(clk_i)
         ,.core_reset_i(reset_i)

         ,.coh_clk_i(clk_i)
         ,.coh_reset_i(reset_i)

         ,.io_clk_i(clk_i)
         ,.io_reset_i(reset_i)

         ,.mem_clk_i(clk_i)
         ,.mem_reset_i(reset_i)

         ,.my_did_i(did_li)
         ,.host_did_i(host_did_li)

         ,.io_cmd_link_i({proc_cmd_link_li, stub_cmd_link_li})
         ,.io_cmd_link_o({proc_cmd_link_lo, stub_cmd_link_lo})

         ,.io_resp_link_i({proc_resp_link_li, stub_resp_link_li})
         ,.io_resp_link_o({proc_resp_link_lo, stub_resp_link_lo})

         ,.dram_cmd_link_o(dram_cmd_link_lo)
         ,.dram_resp_link_i(dram_resp_link_li)
         );

      wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;

      bp_io_noc_ral_link_s send_cmd_link_lo, send_resp_link_li;
      bp_io_noc_ral_link_s recv_cmd_link_li, recv_resp_link_lo;
      assign recv_cmd_link_li   = '{data          : proc_cmd_link_lo.data
                                    ,v            : proc_cmd_link_lo.v
                                    ,ready_and_rev: proc_resp_link_lo.ready_and_rev
                                    };
      assign proc_cmd_link_li   = '{data          : send_cmd_link_lo.data
                                    ,v            : send_cmd_link_lo.v
                                    ,ready_and_rev: recv_resp_link_lo.ready_and_rev
                                    };

      assign send_resp_link_li  = '{data          : proc_resp_link_lo.data
                                    ,v            : proc_resp_link_lo.v
                                    ,ready_and_rev: proc_cmd_link_lo.ready_and_rev
                                    };
      assign proc_resp_link_li  = '{data          : recv_resp_link_lo.data
                                    ,v            : recv_resp_link_lo.v
                                    ,ready_and_rev: send_cmd_link_lo.ready_and_rev
                                    };

      bp_me_cce_to_mem_link_send
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       send_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dst_cord_i(dst_cord_lo)
         ,.dst_cid_i('0)

         ,.mem_cmd_header_i(io_cmd_header_li)
         ,.mem_cmd_data_i(io_cmd_data_li)
         ,.mem_cmd_v_i(io_cmd_v_li)
         ,.mem_cmd_ready_and_o(io_cmd_ready_and_lo)
         ,.mem_cmd_last_i(io_cmd_v_li) // stub

         ,.mem_resp_header_o(io_resp_header_lo)
         ,.mem_resp_data_o(io_resp_data_lo)
         ,.mem_resp_v_o(io_resp_v_lo)
         ,.mem_resp_yumi_i(io_resp_yumi_li)
         ,.mem_resp_last_o()


         ,.cmd_link_o(send_cmd_link_lo)
         ,.resp_link_i(send_resp_link_li)
         );

      bp_me_cce_to_mem_link_recv
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       recv_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dst_cord_i(io_resp_header_li.payload.did)
         ,.dst_cid_i('0)

         ,.mem_cmd_header_o(io_cmd_header_lo)
         ,.mem_cmd_data_o(io_cmd_data_lo)
         ,.mem_cmd_v_o(io_cmd_v_lo)
         ,.mem_cmd_yumi_i(io_cmd_ready_and_li & io_cmd_v_lo)
         ,.mem_cmd_last_o()

         ,.mem_resp_header_i(io_resp_header_li)
         ,.mem_resp_data_i(io_resp_data_li)
         ,.mem_resp_v_i(io_resp_v_li)
         ,.mem_resp_ready_and_o(io_resp_ready_and_lo)
         ,.mem_resp_last_i(io_resp_v_i) // stub

         ,.cmd_link_i(recv_cmd_link_li)
         ,.resp_link_o(recv_resp_link_lo)
         );

      wire dma_id_li = '0;
      bsg_wormhole_to_cache_dma_fanout
       #(.wh_flit_width_p(mem_noc_flit_width_p)
         ,.wh_cid_width_p(mem_noc_cid_width_p)
         ,.wh_len_width_p(mem_noc_len_width_p)
         ,.wh_cord_width_p(mem_noc_cord_width_p)

         ,.num_dma_p(1)
         ,.dma_addr_width_p(daddr_width_p)
         ,.dma_burst_len_p(l2_block_size_in_fill_p)
         )
       wh_to_cache_dma
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.wh_link_sif_i(dram_cmd_link_lo)
         ,.wh_dma_id_i(dma_id_li)
         ,.wh_link_sif_o(dram_resp_link_li)

         ,.dma_pkt_o(dma_pkt_lo)
         ,.dma_pkt_v_o(dma_pkt_v_lo)
         ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

         ,.dma_data_o(dma_data_lo)
         ,.dma_data_v_o(dma_data_v_lo)
         ,.dma_data_yumi_i(dma_data_yumi_li)

         ,.dma_data_i(dma_data_li)
         ,.dma_data_v_i(dma_data_v_li)
         ,.dma_data_ready_and_o(dma_data_ready_and_lo)
         );
    end

  bp_me_axil_client
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   axil2io
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.io_cmd_header_o(io_cmd_header_li)
     ,.io_cmd_data_o(io_cmd_data_li)
     ,.io_cmd_v_o(io_cmd_v_li)
     ,.io_cmd_ready_and_i(io_cmd_ready_and_lo)

     ,.io_resp_header_i(io_resp_header_lo)
     ,.io_resp_data_i(io_resp_data_lo)
     ,.io_resp_v_i(io_resp_v_lo)
     ,.io_resp_yumi_o(io_resp_yumi_li)

     ,.lce_id_i(lce_id_width_p'('b10))
     ,.did_i(did_width_p'('1))
     ,.*
     );

  bp_me_axil_master
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   io2axil
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.io_cmd_header_i(io_cmd_header_lo)
     ,.io_cmd_data_i(io_cmd_data_lo)
     ,.io_cmd_v_i(io_cmd_v_lo)
     ,.io_cmd_ready_and_o(io_cmd_ready_and_li)

     ,.io_resp_header_o(io_resp_header_li)
     ,.io_resp_data_o(io_resp_data_li)
     ,.io_resp_v_o(io_resp_v_li)
     ,.io_resp_ready_and_i(io_resp_ready_and_lo)

     ,.*
     );

   bsg_cache_to_axi
    #(.addr_width_p(daddr_width_p)
      ,.data_width_p(l2_fill_width_p)
      ,.block_size_in_words_p(l2_block_size_in_fill_p)
      ,.num_cache_p(l2_banks_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_burst_len_p(l2_block_width_p/axi_data_width_p)
      )
    cache2axi
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.dma_pkt_i(dma_pkt_lo)
      ,.dma_pkt_v_i(dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

      ,.dma_data_o(dma_data_li)
      ,.dma_data_v_o(dma_data_v_li)
      ,.dma_data_ready_i(dma_data_ready_and_lo)

      ,.dma_data_i(dma_data_lo)
      ,.dma_data_v_i(dma_data_v_lo)
      ,.dma_data_yumi_o(dma_data_yumi_li)

      ,.axi_awid_o(m_axi_awid_o)
      ,.axi_awaddr_addr_o(m_axi_awaddr_o)
      ,.axi_awlen_o(m_axi_awlen_o)
      ,.axi_awsize_o(m_axi_awsize_o)
      ,.axi_awburst_o(m_axi_awburst_o)
      ,.axi_awcache_o(m_axi_awcache_o)
      ,.axi_awprot_o(m_axi_awprot_o)
      ,.axi_awlock_o(m_axi_awlock_o)
      ,.axi_awvalid_o(m_axi_awvalid_o)
      ,.axi_awready_i(m_axi_awready_i)

      ,.axi_wdata_o(m_axi_wdata_o)
      ,.axi_wstrb_o(m_axi_wstrb_o)
      ,.axi_wlast_o(m_axi_wlast_o)
      ,.axi_wvalid_o(m_axi_wvalid_o)
      ,.axi_wready_i(m_axi_wready_i)

      ,.axi_bid_i(m_axi_bid_i)
      ,.axi_bresp_i(m_axi_bresp_i)
      ,.axi_bvalid_i(m_axi_bvalid_i)
      ,.axi_bready_o(m_axi_bready_o)

      ,.axi_arid_o(m_axi_arid_o)
      ,.axi_araddr_addr_o(m_axi_araddr_o)
      ,.axi_arlen_o(m_axi_arlen_o)
      ,.axi_arsize_o(m_axi_arsize_o)
      ,.axi_arburst_o(m_axi_arburst_o)
      ,.axi_arcache_o(m_axi_arcache_o)
      ,.axi_arprot_o(m_axi_arprot_o)
      ,.axi_arlock_o(m_axi_arlock_o)
      ,.axi_arvalid_o(m_axi_arvalid_o)
      ,.axi_arready_i(m_axi_arready_i)

      ,.axi_rid_i(m_axi_rid_i)
      ,.axi_rdata_i(m_axi_rdata_i)
      ,.axi_rresp_i(m_axi_rresp_i)
      ,.axi_rlast_i(m_axi_rlast_i)
      ,.axi_rvalid_i(m_axi_rvalid_i)
      ,.axi_rready_o(m_axi_rready_o)

      // Unused
      ,.axi_awaddr_cache_id_o()
      ,.axi_araddr_cache_id_o()
      );

  if (num_core_p > 1)
    $error("Multiple cores not supported in zynqparrot");

endmodule

