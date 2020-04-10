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
#   @author tommy and borna
#
#   How to use:
#   python blood_graph.py --input {vanilla_operation_trace.csv}
#                         --timing-stat {vanilla_stats.csv}
#                         --abstract {optional}
#                         --generate-key {optional}
#                         --cycle {start_cycle@end_cycle} (deprecated)
#
#   ex) python blood_graph.py --input vanilla_operation_trace.csv
#                             --timing-stat vanilla_stats.csv
#                             --abstract --generate-key
#
#   {timing-stat}  used for extracting the timing window for blood graph
#   {abstract}     used for abstract simplifed bloodgraph
#   {generate-key} also generates a color key for the blood graph


import sys
import csv
import argparse
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
    _DEFAULT_START_CYCLE = 50000 
    _DEFAULT_END_CYCLE   = 250000

    # default constructor
    def __init__(self, timing_stats_file, abstract):

        self.timing_stats_file = timing_stats_file
        self.abstract = abstract

        # List of types of stalls incurred by the core 
        self.stalls_list   = ["freeze",
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
                              ]

                              
 


        # List of types of integer instructions executed by the core 
        self.instr_list    = ["instr",
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
        self.fp_instr_list = ["fadd",
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
        self.detailed_stall_bubble_color = {
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
                                           }
        self.detailed_unified_instr_color    =                                          (0xff, 0xff, 0xff)  ## white
        self.detailed_unified_fp_instr_color =                                          (0xff, 0xaa, 0xff)  ## light pink


        # Coloring scheme for different types of operations
        # For abstract mode 
        # i_cache miss is treated the same is stall_ifetch_wait
        self.abstract_stall_bubble_color = { 
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
        self.abstract_unified_instr_color    =                                          (0xff, 0xff, 0xff)  ## white
        self.abstract_unified_fp_instr_color =                                          (0xff, 0xff, 0xff)  ## white



        # Determine coloring rules based on mode {abstract / detailed}
        if (self.abstract):
            self.stall_bubble_color     = self.abstract_stall_bubble_color
            self.unified_instr_color    = self.abstract_unified_instr_color
            self.unified_fp_instr_color = self.abstract_unified_instr_color
        else:
            self.stall_bubble_color     = self.detailed_stall_bubble_color
            self.unified_instr_color    = self.detailed_unified_instr_color
            self.unified_fp_instr_color = self.detailed_unified_instr_color


        # Parse timing stat file vanilla_stats.csv
        # to gather start and end cycle of entire graph
        self.timing_stats = []
        try:
            with open(self.timing_stats_file) as f:
                csv_reader = csv.DictReader(f, delimiter=",")
                for row in csv_reader:
                    timing_stat = {}
                    timing_stat["global_ctr"] = int(row["global_ctr"])
                    timing_stat["time"] = int(row["time"])
                    self.timing_stats.append(timing_stat)

            # If there are at least two stats recovered from vanilla_stats.csv for start and end cycle
            if (len(self.timing_stats) >= 2):
                self.start_cycle = self.timing_stats[0]["global_ctr"]
                self.end_cycle = self.timing_stats[-1]["global_ctr"]
            else:
                self.start_cycle = self._DEFAULT_START_CYCLE
                self.end_cycle = self._DEFAULT_END_CYCLE
            return

        # If the vanilla_stats.csv file has not been given as input
        # Use the default values for start and end cycles
        except IOError as e:
            self.start_cycle = self._DEFAULT_START_CYCLE
            self.end_cycle = self._DEFAULT_END_CYCLE

        return



  
    # main public method
    def generate(self, input_file):
        # parse vanilla_operation_trace.csv
        traces = []
        with open(input_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                trace["x"] = int(row["x"])  
                trace["y"] = int(row["y"])  
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                traces.append(trace)
  
        # get tile-group dim
        self.__get_tg_dim(traces)

        # init image
        self.__init_image()

        # create image
        for trace in traces:
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
        for (operation,color) in chain([(stall_bubble, self.stall_bubble_color[stall_bubble]) for stall_bubble in self.stalls_list],
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

    # look through the input file to get the tile group dimension (x,y)
    def __get_tg_dim(self, traces):
        xs = list(map(lambda t: t["x"], traces))
        ys = list(map(lambda t: t["y"], traces))
        self.xmin = min(xs)
        self.xmax = max(xs)
        self.ymin = min(ys)
        self.ymax = max(ys)
    
        self.xdim = self.xmax-self.xmin+1
        self.ydim = self.ymax-self.ymin+1
        return


    # initialize image
    def __init_image(self):
        self.img_width = 512 # default
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
        row = floor#*(2+(self.xdim*self.ydim))) + (tg_x+(tg_y*self.xdim))


        # determine color
        if trace["operation"] in self.stall_bubble_color.keys():
            self.pixel[col,row] = self.stall_bubble_color[trace["operation"]]
        elif trace["operation"] in self.instr_list:
            self.pixel[col,row] = self.unified_instr_color
        elif trace["operation"] in self.fp_instr_list:
            self.pixel[col,row] = self.unified_fp_instr_color
        else:
            raise Exception('Invalid operation in vanilla operation trace log {}'.format(trace["operation"]))
        return


# Deprecated: We no longer pass in the cycles by hand 
# The appliation parses the start/end cycles from vanilla_stats.csv file
# The action to take in two input arguments for start and 
# end cycle of execution in the form of start_cycle@end_cycle
class CycleAction(argparse.Action):
    def __call__(self, parser, namespace, cycle, option_string=None):
        start_str,end_str = cycle.split("@")

        # Check if start cycle is given as input
        if(not start_str):
            start_cycle = BloodGraph._DEFAULT_START_CYCLE
        else:
            start_cycle = int(start_str)

        # Check if end cycle is given as input
        if(not end_str):
            end_cycle = BloodGraph._DEFAULT_END_CYCLE
        else:
            end_cycle = int(end_str)

        # check if start cycle is before end cycle
        if(start_cycle > end_cycle):
            raise ValueError("start cycle {} cannot be larger than end cycle {}.".format(start_cycle, end_cycle))

        setattr(namespace, "start", start_cycle)
        setattr(namespace, "end", end_cycle)
 
# Parse input arguments and options 
def parse_args():  
    parser = argparse.ArgumentParser(description="Argument parser for blood_graph.py")
    parser.add_argument("--input", default="vanilla_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--timing-stats", default="vanilla_stats.csv", type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--cycle", nargs='?', required=0, action=CycleAction, 
                        const = (str(BloodGraph._DEFAULT_START_CYCLE)+"@"+str(BloodGraph._DEFAULT_END_CYCLE)),
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
  
    bg = BloodGraph(args.timing_stats, args.abstract)
    if not args.no_blood_graph:
        bg.generate(args.input)
    if args.generate_key:
        bg.generate_key()

