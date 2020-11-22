`ifndef BSG_TRACE_NODE_MASTER_V
`define BSG_TRACE_NODE_MASTER_V

`define bsg_trace_rom_macro(id)       \
  if (id_p == ``id``) begin           \
    bsg_trace_rom_``id`` #(             \
      .width_p(ring_width_p+4)            \
      ,.addr_width_p(rom_addr_width_p)    \
    ) trace_rom_``id`` (                \
      .addr_i(rom_addr)                   \
      ,.data_o(rom_data)                  \
    );                                     \
  end
`endif

module bsg_trace_node_master
  #(parameter id_p="inv"
    ,parameter ring_width_p="inv"
    ,parameter rom_addr_width_p="inv"
  )
  (
    input clk_i
    ,input reset_i
    ,input en_i

    ,input v_i
    ,input [ring_width_p-1:0] data_i
    ,output logic ready_o

    ,output logic v_o
    ,input yumi_i
    ,output logic [ring_width_p-1:0] data_o

    ,output logic done_o
  );

  // trace rom
  //
  logic [ring_width_p+4-1:0] rom_data;
  logic [rom_addr_width_p-1:0] rom_addr;

  // trace replay
  //

  bsg_fsb_node_trace_replay #(
    .ring_width_p(ring_width_p)
    ,.rom_addr_width_p(rom_addr_width_p)
  ) trace_replay (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.en_i(en_i)

    ,.v_i(v_i)
    ,.data_i(data_i)
    ,.ready_o(ready_o)

    ,.v_o(v_o)
    ,.data_o(data_o)
    ,.yumi_i(yumi_i)

    ,.rom_addr_o(rom_addr)
    ,.rom_data_i(rom_data)

    ,.done_o(done_o)
    ,.error_o()
  );

  `bsg_trace_rom_macro(0)
  else `bsg_trace_rom_macro(1)
  else `bsg_trace_rom_macro(2)
  else `bsg_trace_rom_macro(3)
  else `bsg_trace_rom_macro(4)
  else `bsg_trace_rom_macro(5)
  else `bsg_trace_rom_macro(6)
  else `bsg_trace_rom_macro(7)
  else `bsg_trace_rom_macro(8)
  else `bsg_trace_rom_macro(9)
  else `bsg_trace_rom_macro(10)
  else `bsg_trace_rom_macro(11)
  else `bsg_trace_rom_macro(12)
  else `bsg_trace_rom_macro(13)
  else `bsg_trace_rom_macro(14)
  else `bsg_trace_rom_macro(15)
endmodule
