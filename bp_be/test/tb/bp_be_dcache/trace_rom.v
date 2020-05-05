module trace_rom
  #(parameter width_p = -1
   ,parameter addr_width_p = -1
   ,parameter mem_file_p = "test.tr" 

   ,localparam els_lp = 2**addr_width_p
   )
   ( input        [addr_width_p-1:0]   addr_i
   , output logic [width_p-1:0]        data_o
   );

   logic [width_p-1:0] mem [0:els_lp-1];

   initial begin
     $readmemb(mem_file_p, mem);
   end

   assign data_o = mem[addr_i];

endmodule
