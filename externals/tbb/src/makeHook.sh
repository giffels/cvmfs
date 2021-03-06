#!/bin/sh

# There is a bug in TBB that gets triggered by GCC6 optimizations:
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=71388
# We set workaround CXXFLAGS if necessary
if echo "int main() {}" | c++ -fno-lifetime-dse -E - >/dev/null 2>&1; then
  TBB_WORKAROUND_CXX_FLAGS="-fno-lifetime-dse"
fi


make clean
export CUSTOM_SUFFIX="_cvmfs";                                     \
export CXXFLAGS="$(echo $CVMFS_BASE_CXX_FLAGS | sed s/-fvisibility=hidden//) -Wformat $TBB_WORKAROUND_CXX_FLAGS";  \
make

# Install
if [ x"$(uname)" = x"Darwin" ]; then
  shlib_ext="dylib"
else
  shlib_ext="so"
fi
cp -rv include/serial $EXTERNALS_INSTALL_LOCATION/include/
cp -rv include/tbb $EXTERNALS_INSTALL_LOCATION/include/
cp -rv build_debug/libtbb*.${shlib_ext}* $EXTERNALS_INSTALL_LOCATION/lib/
cp -rv build_release/libtbb*.${shlib_ext}* $EXTERNALS_INSTALL_LOCATION/lib/
