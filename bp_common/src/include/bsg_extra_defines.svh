
`ifndef BSG_EXTRA_DEFINES_SVH

    `define BSG_MAX3(x,y,z) (`BSG_MAX(x,`BSG_MAX(y,z)))

    `define BSG_MIN3(x,y,z) (`BSG_MIN(x,`BSG_MIN(y,z)))

    `undef BSG_WIDTH
    `define BSG_WIDTH(x) ( $clog2(x) + (`BSG_IS_POW2(x) ? 1 : 0))

`endif

