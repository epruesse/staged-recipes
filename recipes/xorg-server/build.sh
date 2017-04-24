#! /bin/bash

#set -e
IFS=$' \t\n' # workaround for conda 4.2.13+toolchain bug

# Adopt a Unix-friendly path if we're on Windows (see bld.bat).
[ -n "$PATH_OVERRIDE" ] && export PATH="$PATH_OVERRIDE"

# On Windows we want $LIBRARY_PREFIX in both "mixed" (C:/Conda/...) and Unix
# (/c/Conda) forms, but Unix form is often "/" which can cause problems.
if [ -n "$LIBRARY_PREFIX_M" ] ; then
    mprefix="$LIBRARY_PREFIX_M"
    if [ "$LIBRARY_PREFIX_U" = / ] ; then
        uprefix=""
    else
        uprefix="$LIBRARY_PREFIX_U"
    fi
else
    mprefix="$PREFIX"
    uprefix="$PREFIX"
fi

# On Windows we need to regenerate the configure scripts.
if [ -n "$VS_MAJOR" ] ; then
    am_version=1.15 # keep sync'ed with meta.yaml
    export ACLOCAL=aclocal-$am_version
    export AUTOMAKE=automake-$am_version
    autoreconf_args=(
        --force
        --install
        -I "$mprefix/share/aclocal"
        -I "$mprefix/mingw-w64/share/aclocal" # note: this is correct for win32 also!
    )
    autoreconf "${autoreconf_args[@]}"

    # And we need to add the search path that lets libtool find the
    # msys2 stub libraries for ws2_32.
    platlibs=$(cd $(dirname $(gcc --print-prog-name=ld))/../lib && pwd -W)
    export LDFLAGS="$LDFLAGS -L$platlibs"
fi

set -x
export PKG_CONFIG_LIBDIR=$uprefix/lib:$uprefix/share
export PKG_CONFIG_PATH=$uprefix/lib/pkgconfig:$uprefix/share/pkgconfig
configure_args=(
    --prefix=$mprefix
    --disable-dependency-tracking
    --disable-selective-werror
    --disable-silent-rules
    --disable-glx
    --with-apple-applications-dir=$PREFIX/Applications
    --with-bundle-id-prefix=io.github.conda-forge
    --without-dtrace
    --without-doxygen
    --without-fop
    --without-xmlto
    --disable-devel-docs
    --disable-dri2
    --disable-dri3
    --disable-libdrm
)

if [ -n "$VS_MAJOR" ] ; then
    ### Windows
    # Unix domain sockets aren't gonna work on Windows
    configure_args+=(--disable-unix-transport)
    # Enable WindowsWM
    configure_args+=(--enable-windowswm)
elif [ x"`uname`" = x"Darwin" ]; then
    ### OSX
    # Use CommonCrypto on OSX
    configure_args+=(--with-sha1=CommonCrypto)
else
    ### Linux
    # package "dri" missing
    configure_args+=(--disable-dri)
    # actual xorg xserver needs root, no use in conda
    # we only want xnest, xdmx, xvfb and xwayland
    configure_args+=(--disable-xorg)
fi

./configure "${configure_args[@]}" || sh
make -j$CPU_COUNT
make install
make check

rm -rf $uprefix/share/doc $uprefix/share/man
