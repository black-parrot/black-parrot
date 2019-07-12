# Multi-corner regression
#

# Process corner format: <corner>_<rc_corner>[_ss]
CORNERS := sspg0p72vm40c_SigRCmax_ss \
           sspg0p72vm40c_SigRCmin_ss \
           sspg0p72vm40c_SigCmax_ss \
           sspg0p72vm40c_SigCmin_ss \
           sspg0p72v125c_SigRCmax_ss \
           sspg0p72v125c_SigRCmin_ss \
           sspg0p72v125c_SigCmax_ss \
           sspg0p72v125c_SigCmin_ss \
           ffpg0p88vm40c_SigRCmax \
           ffpg0p88vm40c_SigRCmin \
           ffpg0p88vm40c_SigCmax \
           ffpg0p88vm40c_SigCmin \
           ffpg0p88v125c_SigRCmax \
           ffpg0p88v125c_SigRCmin \
           ffpg0p88v125c_SigCmax \
           ffpg0p88v125c_SigCmin
RUNS := $(foreach corner, $(CORNERS), $(corner))
REGRESS_LIST := hello_world

BLACK_PARROT_URL := https://github.com/black-parrot/pre-alpha-release.git
BLACK_PARROT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
BLACK_PARROT_DIR := $(shell git rev-parse --show-toplevel)

BSG_DESIGN_BUILD_DIR := $(BLACK_PARROT_DIR)/../bsg_designs/toplevels/bsg_ac_black_parrot_quad_core_wip/testing/post_apr_sdf
BLACK_PARROT_CFG := e_bp_quad_core_cfg
BLACK_PARROT_TB := bp_top_trace_demo


nothing:


checkout:
	-rm -rf tmp.pre-alpha-release/
	git clone $(BLACK_PARROT_URL) tmp.pre-alpha-release
	cd tmp.pre-alpha-release/ && git checkout $(BLACK_PARROT_BRANCH)
	ln -s $(BLACK_PARROT_DIR)/bsg_cadenv tmp.pre-alpha-release/bsg_cadenv
	rm -rf tmp.pre-alpha-release/basejump_stl; ln -s $(BLACK_PARROT_DIR)/basejump_stl tmp.pre-alpha-release/basejump_stl
	rm -rf tmp.pre-alpha-release/bp_common; ln -s $(BLACK_PARROT_DIR)/bp_common tmp.pre-alpha-release/bp_common
	rm -rf tmp.pre-alpha-release/bp_me; ln -s $(BLACK_PARROT_DIR)/bp_me tmp.pre-alpha-release/bp_me
	rm -rf tmp.pre-alpha-release/external; ln -s $(BLACK_PARROT_DIR)/external tmp.pre-alpha-release/external
	for run in $(RUNS); do \
		cp -R tmp.pre-alpha-release/ pre-alpha-release_$$run/; \
	done;
	rm -rf tmp.pre-alpha-release/

bleach-checkout:
	-rm -rf tmp.pre-alpha-release/
	-rm -rf $(foreach run,$(RUNS),pre-alpha-release_$(run))


build: $(foreach corner,$(CORNERS),build-$(corner))

build-%: machine_dir=$(BLACK_PARROT_DIR)/regress/machine-$*
build-%: corner=$(word 1, $(subst _, ,$*))
build-%: rc_corner=$(word 2,$(subst _, ,$*))
build-%: corner_ss=$(word 3,$(subst _, ,$*))
build-%:
	mkdir -p $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) corner=$(corner) rc_corner=$(rc_corner) CORNER_SS=$(corner_ss) BSG_OUT_DIR=$(machine_dir) build

bleach-build:
	-rm -rf $(foreach corner,$(CORNERS),machine-$(corner))
	-rm vc_hdrs.h


run: $(foreach run,$(RUNS),run-$(run))

run-%: run_dir=$(BLACK_PARROT_DIR)/regress/pre-alpha-release_$*/bp_top/syn
run-%: machine_dir=$(BLACK_PARROT_DIR)/regress/machine-$*
run-%:
	$(MAKE) -C $(run_dir) build.v CFG=$(BLACK_PARROT_CFG)
	cp -r $(machine_dir)/simv* $(run_dir)/results/vcs/$(BLACK_PARROT_TB).$(BLACK_PARROT_CFG).build/
	for test in $(REGRESS_LIST); do \
		$(MAKE) -C $(run_dir) sim.v CFG=$(BLACK_PARROT_CFG) PROG=$$test; \
	done;

clean_runs: $(foreach run,$(RUNS),clean-$(run))

clean-%: machine_dir=$(BLACK_PARROT_DIR)/regress/machine-$*
clean-%: run_dir=$(BLACK_PARROT_DIR)/regress/pre-alpha-release_$*/bp_top/syn
clean-%:
	$(MAKE) -C $(run_dir) clean


bleach_all: bleach-checkout bleach-build
