`include "bsg_noc_links.vh"

module bsg_mesh_router_buffered #(width_p        = -1
                                  ,x_cord_width_p = -1
                                  ,y_cord_width_p = -1
                                  ,debug_p       = 0
                                  ,dirs_lp       = 5
                                  ,stub_p        = { dirs_lp {1'b0}}  // SNEWP
                                  ,allow_S_to_EW_p = 0
                                  ,bsg_ready_and_link_sif_width_lp=`bsg_ready_and_link_sif_width(width_p)
                                  // select whether to buffer the output
                                  ,repeater_output_p = { dirs_lp {1'b0}}  // SNEWP
                                  )
   (
    input clk_i
    , input reset_i

    , input  [dirs_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_i
    , output [dirs_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
    );

   `declare_bsg_ready_and_link_sif_s(width_p,bsg_ready_and_link_sif_s);

   bsg_ready_and_link_sif_s [dirs_lp-1:0] link_i_cast, link_o_cast;

   assign link_i_cast =link_i;
   assign link_o = link_o_cast;

   logic [dirs_lp-1:0]              fifo_valid;
   logic [dirs_lp-1:0][width_p-1:0] fifo_data;
   logic [dirs_lp-1:0]              fifo_yumi;

   genvar                           i;

   //synopsys translate_off
   if (debug_p)
     for (i = 0; i < dirs_lp;i=i+1)
       begin
          always_ff @(negedge clk_i)
            $display("%m x=%d y=%d SNEWP[%d] v_i=%b ready_o=%b v_o=%b ready_i=%b %b"
                     ,my_x_i,my_y_i,i,link_i_cast[i].v,link_o_cast[i].ready_and_rev,
                     link_o_cast[i].v,link_i_cast[i].ready_and_rev,link_i[i]);
       end
   //synopsys translate_on

   for (i = 0; i < dirs_lp; i=i+1)
     begin: rof
        if (stub_p[i])
          begin: fi
             assign fifo_data   [i] = width_p ' (0);
             assign fifo_valid  [i] = 1'b0;

             // accept no data from outside of stubbed port
             assign link_o_cast[i].ready_and_rev = 1'b0;

             // synopsys translate_off
             always @(negedge clk_i)
               if (link_o_cast[i].v)
                 $display("## warning %m: stubbed port %x received word %x",i,link_i_cast[i].data);
             // synopsys translate_on
          end
        else
          begin: fi
            bsg_fifo_1r1w_small #( .width_p(width_p)
                                  ,.els_p(1)
                                 )
              onefer
              (.clk_i
               ,.reset_i
               
               ,.v_i     (link_i_cast[i].v            )
               ,.data_i  (link_i_cast[i].data         )
               ,.ready_o (link_o_cast[i].ready_and_rev)

               ,.v_o     (fifo_valid[i])
               ,.data_o  (fifo_data [i])
               ,.yumi_i  (fifo_yumi [i])
               );
          end
     end

   // router does not have symmetric interfaces;
   // so we do not use bsg_ready_and_link_sif
   // and manually convert. support for arrays
   // of interfaces in systemverilog would
   // fix this.

   logic [dirs_lp-1:0]              valid_lo;
   logic [dirs_lp-1:0][width_p-1:0] data_lo;
   logic [dirs_lp-1:0]              ready_li;

   for (i = 0; i < dirs_lp; i=i+1)
     begin: rof2
        assign link_o_cast[i].v    = valid_lo[i];

        if (repeater_output_p[i] & ~stub_p[i])
          begin : macro
	     wire [width_p-1:0] tmp;

            // synopsys translate_off
            initial
               begin
                  $display("%m with buffers on %d",i);
               end
            // synopsys translate_on
             bsg_inv #(.width_p(width_p),.vertical_p(i < 3)) data_lo_inv
               (.i (data_lo[i]         )
                ,.o(tmp)
                );

             bsg_inv #(.width_p(width_p),.vertical_p(i < 3)) data_lo_rep
               (.i (tmp)
                ,.o(link_o_cast[i].data)
                );

          end
        else
          assign link_o_cast[i].data = data_lo [i];

        assign ready_li[i] = link_i_cast[i].ready_and_rev;
     end

   bsg_mesh_router #( .width_p      (width_p      )
                      ,.x_cord_width_p(x_cord_width_p)
                      ,.y_cord_width_p(y_cord_width_p)
                      ,.debug_p      (debug_p      )
                      ,.stub_p       (stub_p       )
                      ,.allow_S_to_EW_p(allow_S_to_EW_p)
                      ) bmr
   (.clk_i
    ,.reset_i
    ,.v_i    (fifo_valid)
    ,.data_i (fifo_data )
    ,.yumi_o (fifo_yumi )

    ,.v_o   (valid_lo)
    ,.data_o(data_lo)

    // this will be hardwired to 1 by inside of this module
    // if port is stubbed

    ,.ready_i(ready_li)

    ,.my_x_i
    ,.my_y_i
    );


endmodule

