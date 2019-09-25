
module bp_mem_storage_sync
 #(parameter   data_width_p       = "inv"
   , parameter addr_width_p       = "inv"
   , parameter mem_cap_in_bytes_p = "inv"
   , parameter mem_load_p         = 0
   , parameter mem_zero_p         = 0
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

logic [7:0] mem [0:mem_cap_in_bytes_p-1];

logic [data_width_p-1:0] data_li, data_lo;
logic [addr_width_p-1:0] addr_r;

always_comb
  for (integer i = 0; i < num_data_bytes_lp; i++)
    data_lo[i*8+:8] = mem[addr_r+byte_els_lp'(i)];

assign data_li = data_i;

import "DPI-C" context function string rebase_hexfile(input string memfile_name
                                                      , input longint dram_base);
string hex_file;
always_ff @(posedge clk_i)
  begin
    if (reset_i & mem_load_p)
      begin
        for (integer i = 0; i < mem_cap_in_bytes_p; i++)
          mem[i] = '0;
        hex_file = rebase_hexfile(mem_file_p, mem_offset_p);
        $readmemh(hex_file, mem);
      end
    else if (reset_i & mem_zero_p)
      begin
        for (integer i = 0; i < mem_cap_in_bytes_p; i++)
          mem[i] = '0;
      end
    else if (v_i & w_i)
      // byte-maskable writes
      begin
        for (integer i = 0; i < num_data_bytes_lp; i++)
          begin
            if (write_mask_i[i])
              mem[addr_i+i] <= data_li[i*8+:8];
          end
      end
    if (v_i & ~w_i)
      addr_r <= addr_i;
  end

assign data_o = data_lo;

endmodule

