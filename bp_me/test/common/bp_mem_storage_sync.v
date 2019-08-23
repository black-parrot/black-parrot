
module bp_mem_storage_sync
 #(parameter   data_width_p       = "inv"
   , parameter addr_width_p       = "inv"
   , parameter mem_cap_in_bytes_p = "inv"
   , parameter mem_load_p         = 0
   , parameter mem_file_p         = "inv"
   , parameter mem_offset_p       = "inv"

   , localparam num_data_bytes_lp   = data_width_p / 8 
   , localparam mem_cap_in_words_lp = mem_cap_in_bytes_p / num_data_bytes_lp
   , localparam byte_els_lp         = `BSG_SAFE_CLOG2(mem_cap_in_bytes_p)
   )
  (input                            clk_i
   , input                          reset_i

   , input                          v_i
   , input                          w_i

   , input [addr_width_p-1:0]       addr_i
   , input [data_width_p-1:0]       data_i
   , input [num_data_bytes_lp-1:0]  write_mask_i

   , output [data_width_p-1:0]      data_o
   );

wire unused = &{reset_i};

enum bit [1:0] {e_reset, e_init, e_run} state_n, state_r;

logic [7:0] mem [0:mem_cap_in_bytes_p-1];

logic [data_width_p-1:0] data_li, data_lo;
logic [addr_width_p-1:0] addr_r;

always_comb
  for (integer i = 0; i < num_data_bytes_lp; i++)
    data_lo[i*8+:8] = mem[addr_r+byte_els_lp'(i)];

always_comb
  for (integer i = 0; i < num_data_bytes_lp; i++)
    data_li[i*8+:8] = write_mask_i[i] ? data_i[i*8+:8] : data_lo[i*8+:8];

import "DPI-C" context function string rebase_hexfile(input string memfile_name, input longint dram_base);

always_ff @(posedge clk_i)
  begin
    if ((state_r == e_reset))
      begin
        mem <= '{default: '0};
      end
    if ((state_r == e_init) && (mem_load_p == 1))
      begin
        $readmemh(rebase_hexfile(mem_file_p, mem_offset_p), mem);
      end
    else if (v_i & w_i)
      for (integer i = 0; i < num_data_bytes_lp; i++)
        mem[addr_i+i] <= data_li[i*8+:8];

    if (v_i & ~w_i)
      addr_r <= addr_i;
  end

assign data_o = data_lo;

always_comb
  begin
    case (state_r)
      e_reset: state_n = e_init;
      e_init : state_n = e_run;
      e_run  : state_n = e_run;
      default: state_n = e_reset;
    endcase
  end

always_ff @(posedge clk_i)
  begin
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;
  end

endmodule

