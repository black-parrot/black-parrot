#!/bin/bash
source /opt/venv/bin/activate
source scl_source enable devtoolset-11
source scl_source enable rh-git218

# Add tools to path
export PATH=/opt/autotools/bin:$PATH
export PATH=/opt/cmake/bin:$PATH

# Add boost variables
export BOOST_ROOT=/opt/boost
export BOOST_INCLUDEDIR=/opt/boost/include
export BOOST_LIBRARYDIR=/opt/boost/lib

exec "$@"
