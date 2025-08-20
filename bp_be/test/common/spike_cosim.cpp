
#include "svdpi.h"

#include <riscv/cfg.h>
#include <riscv/debug_module.h>
#include <riscv/devices.h>
#include <riscv/log_file.h>
#include <riscv/processor.h>
#include <riscv/simif.h>

#include <fesvr/memif.h>
#include <fesvr/elfloader.h>
#include <riscv/sim.h>
#include <fesvr/htif.h>
#include <vector>
#include <map>
#include <string>
#include <memory>
#include <sys/mman.h>
#include <sys/types.h>

#include <mutex>

static cfg_t cfg;
static std::vector<std::pair<reg_t, abstract_mem_t*>> mems;
static std::vector<device_factory_sargs_t> plugin_device_factories;
static std::vector<std::string> args;
static debug_module_config_t dm_config;

static sim_t* handle = nullptr;
static std::once_flag handle_init_once, handle_fini_once;

// https://github.com/ucb-bar/testchipip/blob/edacb214f081e5034f131af74efa0ac5f4452ee6/src/main/resources/testchipip/csrc/cospike_impl.cc#L29
class loadmem_memif_t : public memif_t {
    public:
        loadmem_memif_t(uint8_t* _data, size_t _start) : memif_t(nullptr), data(_data), start(_start) {}
        void write(addr_t taddr, size_t len, const void* src) override
        {
            addr_t addr = taddr - start;
            memcpy(data + addr, src, len);
        }
        void read(addr_t taddr, size_t len, void* bytes) override {
            assert(false);
        }
        endianness_t get_target_endianness() const override {
            return endianness_little;
        }
    private:
        uint8_t* data;
        size_t start;
};

extern "C" void* cosim_init(int ncpus, int memsize) {
    size_t memory_size = memsize;
    size_t base = 0x80000000;
    size_t size = memory_size*1024*1024;

    std::call_once(handle_init_once, [&] {
        uint8_t *data = (uint8_t*) mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
        mems.push_back(std::make_pair(base, new mem_t(size)));
        cfg.bootargs = nullptr;
        cfg.isa = "rv64imafdcZifencei_Zicsr_Zba_Zbb_Zbc_Zbs";
        cfg.priv = "msu";
        cfg.start_pc = base;
        cfg.pmpregions = 0;

        args.push_back("prog.riscv");

        handle = new sim_t(&cfg, false,
                mems,
                plugin_device_factories,
                args,
                dm_config, nullptr,
                false, nullptr,
                false,
                nullptr,
                0
                );

        reg_t entry;
        loadmem_memif_t loadmem_memif(data, base);
        load_elf("prog.riscv", &loadmem_memif, &entry, 0);

        bus_t temp_mem_bus;
        for (auto& pair : mems) temp_mem_bus.add_device(pair.first, pair.second);

        printf("Matching spike memory initial state for region %lx-%lx\n", base, base + size);
        if (!temp_mem_bus.store(base, size, data)) {
            printf("Error, unable to match memory at address %lx\n", base);
            abort();
        }

        std::shared_ptr<mem_t> host = std::make_shared<mem_t>(1 << 20);
        handle->add_device(0x100000, host);

        handle->configure_log(true, false);
        handle->get_core(0)->get_state()->pc = base;
        handle->set_debug(0);
    });

    return handle;
}

extern "C" int cosim_step(sim_t *sim_pointer,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status) {

    processor_t *p = sim_pointer->get_core(0);
    state_t *s = p->get_state();
    uint64_t emu_pc = s->pc;

    if (pc != s->pc) {
        printf("[error] EMU PC %016" PRIx64 ", DUT PC %016" PRIx64 "\n", emu_pc, pc);
        return -1;
    }

    p->step(1);

    auto& mem_write = s->log_mem_write;
    auto& log = s->log_reg_write;
    auto& mem_read = s->log_mem_read;

    for (auto &regwrite : log) {
        int emu_rd = regwrite.first >> 4;
        int emu_type = regwrite.first & 0xf;
        int emu_wdata = regwrite.second.v[0];

        if (wdata != emu_wdata) {
            printf("[error] EMU PC %016" PRIx64 ", DUT PC %016" PRIx64 "\n", emu_pc, pc);
            printf("[error] EMU WDATA %016" PRIx64 ", DUT WDATA %016" PRIx64 "\n", emu_wdata, wdata);
            return -1;
        }
    }

    return 0;
}

extern "C" void cosim_trap(sim_t *sim_pointer,
         int hartid,
         uint64_t cause) {
    processor_t *p = sim_pointer->get_core(0);
    p->step(1);
}

extern "C" void* cosim_finish(sim_t *sim_pointer) {
    std::call_once(handle_fini_once, [&] {
        std::cout << "Terminating Spike cosimulation" << std::endl;
        delete sim_pointer;
    });
    return NULL;
}

