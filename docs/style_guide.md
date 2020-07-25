# Code Aesthetics
## Summary
This document is in addition to the [BSG SystemVerilog Coding Guidelines](https://docs.google.com/document/d/1xA5XUzBtz_D6aSyIBQUwFk_kSUdckrfxa2uzGjMgmCU). All rules in that file should be obeyed. This document augments that documents with a few aesthetic guidelines.
This document is intended to provide more rigid structure for coding style and file structure.

## References
[BSG SystemVerilog Coding Guidelines](https://docs.google.com/document/d/1xA5XUzBtz_D6aSyIBQUwFk_kSUdckrfxa2uzGjMgmCU)

[Freescale Verilog Guidelines](https://people.ece.cornell.edu/land/courses/ece5760/Verilog/FreescaleVerilog.pdf)

[Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)

[lowRISCV Verilog Coding Style Guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md)

## Verilog Style
- No tabs in files, anywhere.  People get different results based on their editor.
    - Exception: Makefiles. Tabs should be used to indent recipes, but not for general alignment
- Align all things that have parallel structure (begin/end, case/endcase, commas, periods, etc.). This makes it easier to check the code and find the matching component.

        if (x_p)  // notice how matching inputs are aligned
          begin: foo
            adder     (this_input, that_input, another_input);
          end
        else
          begin: bar
            wow_adder (this_input,          3, another_input);
          end
    
    
        if (foo)    // notice alignment of if/else, begin/end
            x = 3;  // and optional alignment of x = statement.
        else
          begin
            x = 1;
            y = 0;
          end

- Use localparam keyword for derived parameters and input parameters that should not be set by the party instantiating the module.
- Localparams in port lists are allowed, but only for sizing ports. Other generated localparams should go near their consumers.
- Ports and parameters should not have the module name as a prefix, since that is redundant. In some cases, the wires in the parent module may use the module name of the child to disambiguate. 

        module foo 
          #(parameter bar_p = "inv")
           (input [bar_p-1:0] baz_i  // not foo_baz_i
            );
    
        foo
         #(.bar_p(foo_bar_p))
         inst
          (.baz_i(foo_baz_li));
- Signals corresponding to a pipeline stage in a module which has multiple stages should have a pipeline stage suffix
    - foobar_ex1_lo
    - barbaz_tv_n
- ‘0’, ‘1’, ‘2’, and ‘8’ (when used as byte width) are the only allowable magic numbers. Else, consider strongly the use of a localparam.
- Prefer packages over \`includes. 
    - \`defines are scoped globally, so defining them within packages makes no functional difference, as long as proper include guards are used.
    - BlackParrot flist style is to compile all packages first, so most tools will be forced to include definitions in the correct order.
- Import packages within modules (not other headers) to avoid global ($root) package imports
- Modules are named *.v, headers and packages are named *.vh

        foo_pkg.vh:
    
        package foo_pkg;
          localparam baz_gp = 1’b0;
    
          `include “foo_defines.vh”
          `include “bar_defines.vh”
        endpackage;
        
        foo.v:
    
        module foo
         import foo_pkg::*;
         #(parameter a = "inv")

## Syntactic style
- snake_case for all identifiers.
    - No capital letters in the source code except in comments or in strings.
- 2 spaces per indent.
- Code inside of a module should be idented once.
- Newline at end of file (helps some old unix tools).

-Space between type and width e.g. logic [1:0], not logic[1:0].

-Space between keywords and operators.

    begin : // this
    if (x)  // this
    begin:  // not this
    if(x)  // not this

- Per BSG SystemVerilog Style Guide, all generate blocks should be labeled.
- Lines should not exceed 100 (soft limit) or 120 (hard limit) columns
    - Exception: macro definition parameter lists and usage must be one line to satisfy some tools. Macro bodies should be broken up with backslashification.
    - When breaking lines start the newline with the operator or the first operand.

            foo = super_long_name_that_wraps
                  + other_name;
            foo = 
              super_long_name_that_wraps + other_name;

- Lists should be formatted in one of the following ways: 

        (all, one, line)
    
        (all
         ,one
         ,line
         )

        (spaces, after, commas, horizontally)
        (but
         ,not
         ,vertically
         )

        // Except for between commas and keywords
        , parameter p
        ...
        , input  i
        , output o
        )

- Declarations and instantations should be formatted in one of the following ways:
        // Module declaration
        module foo 
         #(parameter width_p    = “inv” // note alignment
           , parameter height_p = “inv” // space between , and parameter
           )
          (input [width_p-1:0]    bar_i // port names aligned
           , input [height_p-1:0] baz_i // space between , and input
           );

        // Module instantiation
        foo 
         #(.width_p(3)   // # indented by 1 space
           ,.height_p(5) // no space between , and .
           )
         inst                   // inst name aligned with #    
          (.bar_i(foo_bar_li)   // parentheses of parameters and ports aligned
           ,.baz_i(foo_baz_li)
           );

        // Can combine parameter or port lists to one line
        foo 
         #(.width_p(3) ,.height_p(5))
         inst                     
          (.bar_i(foo_bar_li), .baz_i(foo_baz_li));

        // Struct declaration
        typedef struct
        {
          logic [1:0] bar; // fields aligned
          logic       baz;
          foobar_s    boo;
        }  foo_s;      // Two spaces to break up struct name from field declarations

        // Enum declaration
        typedef enum
        {
          e_zop  = 2’b00  // All values assigned, rather than default
          ,e_bar = 2’b01  // Values aligned
          ,e_baz = 2’b10
        } foo_e;           

- Do not begin comments with // Verilator.  Verilator transforms all comments to /**/ style, which can cause Verilator to interpret an innocuous comment as an invalid pragma. For example, the following example will fail to compile in Verilator!

        module foo
        input logic a;
        output logic b;

        // Verilator cannot handle this construct
        `ifndef VERILATOR
          syntax error
        `endif

        endmodule
