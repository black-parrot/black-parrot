
package bp_dramsim3_lpddr_2Gb_x16_pkg;
  parameter int tck_ps=4800;
  parameter int channel_addr_width_p=30;
  parameter int data_width_p=512;
  parameter int num_channels_p=1;
  parameter int num_columns_p=256;
  parameter int num_rows_p=16384;
  parameter int num_ba_p=4;
  parameter int num_bg_p=1;
  parameter int num_ranks_p=1; //?
  parameter longint size_in_bits_p=2**33; // 1GB (8Gb)
  parameter string config_p="lpddr_2Gb_x16.ini";
  parameter address_mapping_p=bsg_dramsim3_pkg::e_ro_ch_ra_ba_bg_co;
endpackage
