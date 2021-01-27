`ifndef BP_COMMON_LOG_DEFINES_SVH
`define BP_COMMON_LOG_DEFINES_SVH

  /*
   * This macro allows users to log to different mediums depending on a parameter
   *   print_type_mp - The different outputs as a bitmask
   *     0 - stdout ($display without newline)
   *     1 - file
   *   file_mp - The name of the log file, optional if using stdout
   *   str_mp - This is the format string for the print statement. Must be enclosed in parentheses
   *
   * Example usage -
   *  `BP_LOG(0, `BP_LOG_STDOUT, ("I'm a display log %d", 2));
   *  `BP_LOG(file, `BP_LOG_FILE, ("I'm a file log %d %d", 1, 2));
   *  `BP_LOG(file, `BP_LOG_STDOUT | `BP_LOG_FILE, ("I'm both! %d", 3));
   *  `BP_LOG(0, `BP_LOG_NONE, ("I'm neither %d", 4));
   *
   * In practice, we expect users will set the log level as a module parameter rather than in the
   *   macro.
   * An obvious enhancement is to add log levels to control verbosity. A less obvious enhancement is
   *   to support ordering of logs through a parameter. Perhaps #``delay_mp``
   */
  localparam bp_log_none_gp   = 0;
  localparam bp_log_stdout_gp = 1;
  localparam bp_log_file_gp   = 2;

  `define BP_LOG(print_type_mp=0, file_mp=0, str_mp) \
    do begin \
      if (print_type_mp[0]) $write("%s", $sformatf str_mp); \
      if (print_type_mp[1]) $fwrite(file_mp, "%s", $sformatf str_mp); \
    end while (0)

  `define bp_cast_i(struct_name_mp, port_mp) \
    struct_name_mp ``port_mp``_cast_i;    \
    assign ``port_mp``_cast_i = ``port_mp``_i

  `define bp_cast_o(struct_name_mp, port_mp) \
    struct_name_mp ``port_mp``_cast_o;    \
    assign ``port_mp``_o = ``port_mp``_cast_o;

`endif

