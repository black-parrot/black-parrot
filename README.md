**The structure of the BlackParrot repository branches.**

The *dev* branch contains the most recent development version, being tested internally.

The *master* branch contains most recent stable version.

The *fe_dev*, *be_dev*, and *me_dev* branches are used to do development on the three major components of the BlackParrot core. 

**Development flow.**

When a new feature is ready for wider use across the BlackParrot development team, it is pushed from *fe_dev*, *be_dev*, or *me_dev* to *dev*, so the wider team can test. When we are satisfied with *dev*, we push to *master* so the world can use it.

**Project Status.**

The next release of Black Parrot, v 0.5, is coming in July 2019, and will contain support for 1 to 8-way cache coherent multicore, and include baseline user and privilege mode functionality.

**CI**

master: [![Gitlab
CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/master/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) 

dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) 

fe_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/fe_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) be_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/be_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) me_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/me_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) sw_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/sw_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines)
