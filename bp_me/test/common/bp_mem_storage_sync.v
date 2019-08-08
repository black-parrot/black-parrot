
module bp_mem_storage_sync
 #(parameter   data_width_p       = "inv"
   , parameter addr_width_p       = "inv"
   , parameter mem_cap_in_bytes_p = "inv"
   , parameter hex_file_p         = "inv"

   , parameter hex_load_p = 0

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

always_comb
  for (integer i = 0; i < num_data_bytes_lp; i++)
    data_li[i*8+:8] = write_mask_i[i] ? data_i[i*8+:8] : data_lo[i*8+:8];

// TODO: We assume DRAM base is 32'h8000_0000 right now, but this could be extracted to a parameter
string change_base_cmd = $sformatf("sed -i 's/@8/@0/g' %s", hex_file_p);

always_ff @(posedge clk_i)
  begin
    if (reset_i & hex_load_p)
      begin
        for (integer i = 0; i < mem_cap_in_bytes_p; i++)
          mem[i] = '0;
        $system(change_base_cmd);
        $readmemh(hex_file_p, mem);
      end
    else if (v_i & w_i)
      for (integer i = 0; i < num_data_bytes_lp; i++)
        mem[addr_i+i] <= data_li[i*8+:8];

    if (v_i & ~w_i)
      addr_r <= addr_i;
  end

assign data_o = data_lo;

endmodule

