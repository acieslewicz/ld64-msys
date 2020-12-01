#!/usr/bin/env bash

export LC_ALL=C
pushd "${0%/*}" &>/dev/null

PLATFORM=$(uname -s)
OPERATING_SYSTEM=$(uname -s | cut -f 1 -d '_')

if [ $OPERATING_SYSTEM == "Android" ]; then
  export CC="clang -D__ANDROID_API__=26"
  export CXX="clang++ -D__ANDROID_API__=26"
fi

GNUMAKE="make"
if [ $OPERATING_SYSTEM == "FreeBSD" ] || [ $OPERATING_SYSTEM == "OpenBSD" ] || [ $OPERATING_SYSTEM == "NetBSD" ] || [ $OPERATING_SYSTEM == "Solaris" ]; then
  GNUMAKE="gmake"
fi

if [ -z "$LLVM_DSYMUTIL" ]; then
    LLVM_DSYMUTIL=llvm-dsymutil
fi

if [ -z "$LLVM_GSYMUTIL" ]; then
    LLVM_GSYMUTIL=llvm-gsymutil
fi

if [ -z "$JOBS" ]; then
    JOBS=$(nproc 2>/dev/null || ncpus 2>/dev/null || echo 1)
fi

set -e

function verbose_cmd
{
    echo "$@"
    eval "$@"
}

function extract()
{
    echo "extracting $(basename $1) ..."
    local tarflags="xf"

    case $1 in
        *.tar.xz)
            xz -dc $1 | tar $tarflags -
            ;;
        *.tar.gz)
            gunzip -dc $1 | tar $tarflags -
            ;;
        *.tar.bz2)
            bzip2 -dc $1 | tar $tarflags -
            ;;
        *)
            echo "unhandled archive type" 1>&2
            exit 1
            ;;
    esac
}

function git_clone_repository
{
    local url=$1
    local branch=$2
    local directory

    directory=$(basename $url)
    directory=${directory/\.git/}

    if [ -n "$CCTOOLS_IOS_DEV" ]; then
        rm -rf $directory
        cp -r $CCTOOLS_IOS_DEV/$directory .
        return
    fi

    if [ ! -d $directory ]; then
        local args=""
        test "$branch" = "master" && args="--depth 1"
        git clone $url $args
    fi

    pushd $directory &>/dev/null

    git reset --hard
    git clean -fdx
    git checkout $branch
    git pull origin $branch

    popd &>/dev/null
}

TMPDIR="$PWD/tmp"
mkdir -p $TMPDIR

TARGETDIR="$PWD/target"
SDKDIR="$TARGETDIR/SDK"

PATCH_DIR=$PWD/../../patches

mkdir -p $TARGETDIR
mkdir -p $TARGETDIR/bin
mkdir -p $SDKDIR

echo ""
echo "*** checking SDK ***"
echo ""

pushd $SDKDIR &>/dev/null

SYSLIB=$(find $SDKDIR -name libSystem.dylib -o -name libSystem.tbd | head -n1)
if [ -z "$SYSLIB" ]; then
    echo "SDK should contain libSystem{.dylib,.tbd}" 1>&2
    exit 1
fi
popd &>/dev/null

echo ""
echo "*** checking/getting dsymutil ***"
echo ""

OK=0

set +e
which $LLVM_DSYMUTIL &>/dev/null
if [ $? -eq 0 ]; then
    case $($LLVM_DSYMUTIL --version | \
           grep "LLVM version" | head -1 | awk '{print $3}') in
        3.8*|3.9*|4.0*|5.0*|6.0*|7.0*|8.0*|9.0*|10.0*|11.0*|12.0*) OK=1 ;;
    esac
fi
set -e

if [ $OK -eq 1 ]; then
    ln -sf $(which $LLVM_DSYMUTIL) $TARGETDIR/bin/dsymutil
    pushd $TARGETDIR/bin &>/dev/null
    # ln -sf $TRIPLE-lipo lipo
    popd &>/dev/null
elif ! which dsymutil &>/dev/null; then
    echo "int main(){return 0;}" | cc -xc -O2 -o $TARGETDIR/bin/dsymutil -
fi

OK=0

set +e
which $LLVM_GSYMUTIL &>/dev/null
if [ $? -eq 0 ]; then
    case $($LLVM_GSYMUTIL --version | \
           grep "LLVM version" | head -1 | awk '{print $3}') in
        3.8*|3.9*|4.0*|5.0*|6.0*|7.0*|8.0*|9.0*|10.0*|11.0*|12.0*) OK=1 ;;
    esac
fi
set -e

if [ $OK -eq 1 ]; then
    ln -sf $(which $LLVM_GSYMUTIL) $TARGETDIR/bin/gsymutil
    pushd $TARGETDIR/bin &>/dev/null
    # ln -sf $TRIPLE-lipo lipo
    popd &>/dev/null
elif ! which dsymutil &>/dev/null; then
    echo "int main(){return 0;}" | cc -xc -O2 -o $TARGETDIR/bin/dsymutil -
fi

echo ""
echo "*** building blocks ***"
echo ""

pushd ../../blocks/ &>/dev/null
INSTALLPREFIX=$TARGETDIR ./build.sh
popd &>/dev/null


if [ "$OSTYPE" == "msys" ]; then
    echo ""
    echo "*** building mman ***"
    echo ""

    pushd ../../mman/ &>/dev/null
    INSTALLPREFIX=$TARGETDIR ./build.sh
    popd &>/dev/null
fi

echo ""
echo "*** building ldid ***"
echo ""

pushd tmp &>/dev/null
rm -rf ldid
mkdir -p ldid
cp -r ./../../../ldid ./
pushd ldid &>/dev/null
$GNUMAKE INSTALLPREFIX=$TARGETDIR -j$JOBS install
popd &>/dev/null
popd &>/dev/null

echo ""
echo "*** building apple-libtapi ***"
echo ""

pushd tmp &>/dev/null
git_clone_repository https://github.com/LongDirtyAnimAlf/libtapi-msys
pushd libtapi-msys &>/dev/null
INSTALLPREFIX=$TARGETDIR ./build.sh
popd &>/dev/null
popd &>/dev/null


echo ""
echo "*** building ld64 ***"
echo ""

pushd tmp &>/dev/null
mkdir -p ld
pushd ld &>/dev/null
../../../../ld/configure --prefix=$TARGETDIR --with-libtapi=$TARGETDIR
# $GNUMAKE clean && $GNUMAKE -j$JOBS && $GNUMAKE install
$GNUMAKE -j$JOBS && $GNUMAKE install
popd &>/dev/null
popd &>/dev/null

echo ""
echo "*** All done ***"
echo ""
