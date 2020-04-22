#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla_operation_trace.csv.log
#          vanilla_stats.csv (for timing)
#   output: blood graph file (blood_abstrat/detailed.png)
#           blood graph key  (key_abstract/detailed.png)
#
#   @author Tommy and Borna
#
#   How to use:
#   python blood_graph.py --trace {vanilla_operation_trace.csv}
#                         --stats {vanilla_stats.csv}
#                         --cycle {start_cycle@end_cycle}
#                         --abstract {optional}
#                         --generate-key {optional}
#
#
#
#   {stats}        used for extracting the timing window for blood graph
#   {abstract}     used for abstract simplifed bloodgraph
#   {generate-key} also generates a color key for the blood graph
#
#
#   Note: You can use the "Digital Color Meter" in MacOS in order to compare
#   the values from the color key to the values in the bloodgraph, if you are
#   having trouble distinguishing a color.


import sys
import csv
import argparse
import warnings
import os.path
from PIL import Image, ImageDraw, ImageFont
from itertools import chain


import random

random.seed(0xdeadbeef)
def rand_color():
    return (random.randint(0,255), random.randint(0,255), random.randint(0,255))

class BloodGraph:
    # for generating the key
    _KEY_WIDTH  = 512
    _KEY_HEIGHT = 512


    # List of types of stalls incurred by the core 
    _STALLS_LIST   = ["freeze",
                      "fe_queue_stall",
                      "fe_wait_stall",
                      "itlb_miss",
                      "icache_miss",
                      "icache_fence",
                      "branch_override",
                      "fe_cmd",
                      "cmd_fence",
                      "dir_mispredict",
                      "target_mispredict",
                      "control_haz",
                      "data_haz",
                      "load_dep",
                      "mul_dep",
                      "struct_haz",
                      "dtlb_miss",
                      "dcache_miss",
                      "long_haz",
                      "eret",
                      "exception",
                      "interrupt",

                      "none_mispredict",
                      "ovr_mispredict",
                      "btb_mispredict",
                      "ret_mispredict",
                      "ret_override",
                      ]

                       
    # List of types of integer instructions executed by the core 
    _INSTRS_LIST    = ["instr",
                       "local_ld",
                       "local_st",
                       "remote_ld_dram",
                       "remote_ld_global",
                       "remote_ld_group",
                       "remote_st_dram",
                       "remote_st_global",
                       "remote_st_group",
                       "local_flw",
                       "local_fsw",
                       "remote_flw",
                       "remote_fsw",
                       # icache_miss is no longer treated as an instruction
                       # but treated the same as stall_ifetch_wait
                       #"icache_miss",
                       "lr",
                       "lr_aq",
                       "swap_aq",
                       "swap_rl",
                       "beq",
                       "bne",
                       "blt",
                       "bge",
                       "bltu",
                       "bgeu",
                       "jalr",
                       "jal",
                       "beq_miss",
                       "bne_miss",
                       "blt_miss",
                       "bge_miss",
                       "bltu_miss",
                       "bgeu_miss",
                       "jalr_miss",
                       "sll",
                       "slli",
                       "srl",
                       "srli",
                       "sra",
                       "srai",
                       "add",
                       "addi",
                       "sub",
                       "lui",
                       "auipc",
                       "xor",
                       "xori",
                       "or",
                       "ori",
                       "and",
                       "andi",
                       "slt",
                       "slti",
                       "sltu",
                       "sltiu",
                       "mul",
                       "mulh",
                       "mulhsu",
                       "mulhu",
                       "div",
                       "divu",
                       "rem",
                       "remu",
                       "fence",
                       "amoswap",
                       "amoor",
                       "unknown" ]


    # List of types of floating point instructions executed by the core
    _FP_INSTRS_LIST = ["fadd",
                       "fsub",
                       "fmul",
                       "fsgnj",
                       "fsgnjn",
                       "fsgnjx",
                       "fmin",
                       "fmax",
                       "fcvt_s_w",
                       "fcvt_s_wu",
                       "fmv_w_x",
                       "feq",
                       "flt",
                       "fle",
                       "fcvt_w_s",
                       "fcvt_wu_s",
                       "fclass",
                       "fmv_x_w" ]



    # Coloring scheme for different types of operations
    # For detailed mode 
    # i_cache miss is treated the same is stall_ifetch_wait
    _DETAILED_STALL_BUBBLE_COLOR = {
                                   "freeze"                       : rand_color(), 
                                   "fe_queue_stall"               : rand_color(),

                                   "fe_wait_stall"                : rand_color(),
                                   "itlb_miss"                    : rand_color(),
                                   "icache_miss"                  : rand_color(),
                                   "icache_fence"                 : rand_color(),

                                   "branch_override"              : rand_color(),

                                   "fe_cmd"                       : rand_color(),
                                   "cmd_fence"                    : rand_color(),

                                   "dir_mispredict"               : rand_color(),
                                   "target_mispredict"            : rand_color(),
                                   "control_haz"                  : rand_color(),

                                   "data_haz"                     : rand_color(),
                                   "load_dep"                     : rand_color(),
                                   "mul_dep"                      : rand_color(),
                                   "struct_haz"                   : rand_color(),
                                   "dtlb_miss"                    : rand_color(),
                                   "dcache_miss"                  : rand_color(),
                                   "long_haz"                     : rand_color(),
                                   "eret"                         : rand_color(),

                                   "exception"                    : rand_color(),
                                   "interrupt"                    : rand_color(),

                                   "none_mispredict"              : rand_color(),
                                   "ovr_mispredict"               : rand_color(),
                                   "btb_mispredict"               : rand_color(),
                                   "ret_mispredict"               : rand_color(),
                                   "ret_override"                 : rand_color(), 
                                   }
    _DETAILED_UNIFIED_INSTR_COLOR =                                 (0xff, 0xff, 0xff)  ## white
    _DETAILED_UNIFIED_FP_INSTR_COLOR =                              (0xff, 0xaa, 0xff)  ## light pink


    # Coloring scheme for different types of operations
    # For abstract mode 
    # i_cache miss is treated the same is stall_ifetch_wait
    _ABSTRACT_STALL_BUBBLE_COLOR = { 
                                   "stall_depend_remote_load_dram"          : (0xff, 0x00, 0x00), ## red
                                   "stall_depend_local_remote_load_dram"    : (0xff, 0x00, 0x00), ## red

                                   "stall_depend_remote_load_global"        : (0x00, 0xff, 0x00), ## green
                                   "stall_depend_remote_load_group"         : (0x00, 0xff, 0x00), ## green
                                   "stall_depend_local_remote_load_global"  : (0x00, 0xff, 0x00), ## green
                                   "stall_depend_local_remote_load_group"   : (0x00, 0xff, 0x00), ## green

                                   "stall_lr_aq"                            : (0x40, 0x40, 0x40), ## dark gray

                                   "stall_depend"                           : (0x00, 0x00, 0x00), ## black
                                   "stall_depend_local_load"                : (0x00, 0x00, 0x00), ## black
                                   "stall_fp_local_load"                    : (0x00, 0x00, 0x00), ## black
                                   "stall_fp_remote_load"                   : (0x00, 0x00, 0x00), ## black
                                   "stall_force_wb"                         : (0x00, 0x00, 0x00), ## black
                                   "stall_icache_store"                     : (0x00, 0x00, 0x00), ## black
                                   "stall_remote_req"                       : (0x00, 0x00, 0x00), ## black
                                   "stall_local_flw"                        : (0x00, 0x00, 0x00), ## black
                                   "stall_amo_aq"                           : (0x00, 0x00, 0x00), ## black
                                   "stall_amo_rl"                           : (0x00, 0x00, 0x00), ## black

                                   "icache_miss"                            : (0x00, 0x00, 0xff), ## blue
                                   "stall_ifetch_wait"                      : (0x00, 0x00, 0xff), ## blue
                                   "bubble_icache"                          : (0x00, 0x00, 0xff), ## blue

                                   "bubble_branch_mispredict"               : (0x00, 0x00, 0x00), ## black
                                   "bubble_jalr_mispredict"                 : (0x00, 0x00, 0x00), ## black
                                   "bubble_fp_op"                           : (0x00, 0x00, 0x00), ## black
                                   "bubble"                                 : (0x00, 0x00, 0x00), ## black

                                   "stall_md"                               : (0xff, 0xff, 0xff), ## white
                                   }
    _ABSTRACT_UNIFIED_INSTR_COLOR =                                           (0xff, 0xff, 0xff)  ## white
    _ABSTRACT_UNIFIED_FP_INSTR_COLOR =                                        (0xff, 0xff, 0xff)  ## white




    # default constructor
    def __init__(self, trace_file, stats_file, cycle, abstract):

        self.abstract = abstract

        # Determine coloring rules based on mode {abstract / detailed}
        if (self.abstract):
            self.stall_bubble_color     = self._ABSTRACT_STALL_BUBBLE_COLOR
            self.unified_instr_color    = self._ABSTRACT_UNIFIED_INSTR_COLOR
            self.unified_fp_instr_color = self._ABSTRACT_UNIFIED_INSTR_COLOR
        else:
            self.stall_bubble_color     = self._DETAILED_STALL_BUBBLE_COLOR
            self.unified_instr_color    = self._DETAILED_UNIFIED_INSTR_COLOR
            self.unified_fp_instr_color = self._DETAILED_UNIFIED_INSTR_COLOR


        # Parse vanilla operation trace file to generate traces
        self.traces = self.__parse_traces(trace_file)

        # Parse vanilla stats file to generate timing stats 
        self.stats = self.__parse_stats(stats_file)
       
        # get tile group diemsnions
        self.__get_tile_group_dim(self.traces)

        # get the timing window (start and end cycle) for blood graph
        self.start_cycle, self.end_cycle = self.__get_timing_window(self.traces, self.stats, cycle)


    # parses vanilla_operation_trace.csv to generate operation traces
    def __parse_traces(self, trace_file):
        traces = []
        with open(trace_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                trace["x"] = int(row["x"])  
                trace["y"] = int(row["y"])  
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                traces.append(trace)
        return traces


    # Parses vanilla_stats.csv to generate timing stats 
    # to gather start and end cycle of entire graph
    def __parse_stats(self, stats_file):
        stats = []
        if(stats_file):
            if (os.path.isfile(stats_file)):
                with open(stats_file) as f:
                    csv_reader = csv.DictReader(f, delimiter=",")
                    for row in csv_reader:
                        stat = {}
                        stat["global_ctr"] = int(row["global_ctr"])
                        stat["time"] = int(row["time"])
                        stats.append(stat)
            else:
                warnings.warn("Stats file not found, overriding blood graph's start/end cycle with traces.")
        return stats


    # look through the input file to get the tile group dimension (x,y)
    def __get_tile_group_dim(self, traces):
        xs = [t["x"] for t in traces]
        ys = [t["y"] for t in traces]
        self.xmin = min(xs)
        self.xmax = max(xs)
        self.ymin = min(ys)
        self.ymax = max(ys)
    
        self.xdim = self.xmax-self.xmin+1
        self.ydim = self.ymax-self.ymin+1
        return


    # Determine the timing window (start and end) cycle of graph 
    # The timing window will be calculated using:
    # Custom input: if custom start cycle is given by using the --cycle argument
    # Vanilla stats file: otherwise if vanilla stats file is given as input
    # Traces: otherwise the entire course of simulation 
    def __get_timing_window(self, traces, stats, cycle):
        custom_start, custom_end = cycle.split('@')

        if (custom_start):
            start = int(custom_start)
        elif (stats):
            start = stats[0]["global_ctr"]
        else:
            start = traces[0]["cycle"]


        if (custom_end):
            end = int(custom_end)
        elif (stats):
            end = stats[-1]["global_ctr"]
        else:
            end = traces[-1]["cycle"]

        return start, end




    # main public method
    def generate(self):
  

        # init image
        self.__init_image()

        # create image
        for trace in self.traces:
            self.__mark_trace(trace)

        #self.img.show()
        mode = "abstract" if self.abstract else "detailed"
        self.img.save(("blood_" + mode + ".png"))
        return




    # public method to generate key for bloodgraph
    # called if --generate-key argument is true
    def generate_key(self, key_image_fname = "key"):
        img  = Image.new("RGB", (self._KEY_WIDTH, self._KEY_HEIGHT), "black")
        draw = ImageDraw.Draw(img)
        font = ImageFont.load_default()
        # the current row position of our key
        yt = 0
        # for each color in stalls...
        for (operation,color) in chain([(stall_bubble, self.stall_bubble_color[stall_bubble]) for stall_bubble in self._STALLS_LIST],
                                 [("unified_instr"    ,self.unified_instr_color),
                                  ("unified_fp_instr" ,self.unified_fp_instr_color)]):

            # get the font size
            (font_height,font_width) = font.getsize(operation)
            # draw a rectangle with color fill
            yb = yt + font_width
            # [0, yt, 64, yb] is [top left x, top left y, bottom right x, bottom left y]
            draw.rectangle([0, yt, 64, yb], color)
            # write the label for this color in white
            # (68, yt) = (top left x, top left y)
            # (255, 255, 255) = white
            draw.text((68, yt), operation, (255,255,255))
            # create the new row's y-coord
            yt += font_width

        # save the key
        mode = "abstract" if self.abstract else "detailed"
        img.save("{}.png".format(key_image_fname + "_" + mode))
        return




    # initialize image
    def __init_image(self):
        self.img_width = 512   # default
        self.img_height = (((self.end_cycle-self.start_cycle)+self.img_width)//self.img_width)*(2+(self.xdim*self.ydim))
        self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
        self.pixel = self.img.load()
        return  
  
    # mark the trace on output image
    def __mark_trace(self, trace):

        # ignore trace outside the cycle range
        if trace["cycle"] < self.start_cycle or trace["cycle"] >= self.end_cycle:
            return

        # determine pixel location
        cycle = (trace["cycle"] - self.start_cycle)
        col = cycle % self.img_width
        floor = cycle // self.img_width
        tg_x = trace["x"] - self.xmin 
        tg_y = trace["y"] - self.ymin
        row = floor*((self.xdim*self.ydim)) + (tg_x+(tg_y*self.xdim))


        # determine color
        if trace["operation"] in self.stall_bubble_color.keys():
            self.pixel[col,row] = self.stall_bubble_color[trace["operation"]]
        elif trace["operation"] in self._INSTRS_LIST:
            self.pixel[col,row] = self.unified_instr_color
        elif trace["operation"] in self._FP_INSTRS_LIST:
            self.pixel[col,row] = self.unified_fp_instr_color
        else:
            raise Exception('Invalid operation in vanilla operation trace log {}'.format(trace["operation"]))
        return




# Parse input arguments and options 
def parse_args():  
    parser = argparse.ArgumentParser(description="Argument parser for blood_graph.py")
    parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--stats", default=None, type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--cycle", default="@", type=str,
                        help="Cycle window of bloodgraph as start_cycle@end_cycle.")
    parser.add_argument("--abstract", default=False, action='store_true',
                        help="Type of bloodgraph - abstract / detailed")
    parser.add_argument("--generate-key", default=False, action='store_true',
                        help="Generate a key image")
    parser.add_argument("--no-blood-graph", default=False, action='store_true',
                        help="Skip blood graph generation")

    args = parser.parse_args()
    return args



# main()
if __name__ == "__main__":
    args = parse_args()
  
    bg = BloodGraph(args.trace, args.stats, args.cycle, args.abstract)
    if not args.no_blood_graph:
        bg.generate()
    if args.generate_key:
        bg.generate_key()

