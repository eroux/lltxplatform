#!/bin/bash

set -e

rm -f built-archs.lst

if [[ "$1" == -c ]]
then
    configure=1
    shift
else
    configure=0
fi

build() {
    local arch="$1"
    echo "Building for architecture $arch..."
    shift
    export build_dir="$PWD/build/$arch"
    export stage_dir="$PWD/stage/$arch"
    if [[ "$configure" == 1 || ! -d "$build_dir" ]]
    then
        mkdir -v -p "$build_dir" "$stage_dir"
        (
            set -e
            cd "$build_dir"
            ../../configure --prefix="$stage_dir" "$@"
        )
    fi
    (
        set -e
        cd "$build_dir"
        make install
    )
    echo "$arch" >> built-archs.lst
    echo
}

cross_windows() {
    for host in i{6..3}86-mingw32{,msvc}
    do
	if which "$host-gcc" > /dev/null 2>&1
	then
	    build win32 "--host=$host" "$@"
	    break
	fi
    done
}

cross_osx() {
    local arch="$1"
    local host="$2"
    shift 2
    build "$arch" "--host=$host" "$@"
}

cross_linux() {
    local arch
    while IFS=';' read -r dir flag
    do
	arch=''
	if [[ "$dir" != . && -n "$flag" ]]
	then
	    case "$dir" in
		32) arch=i386-linux ;;
		64) arch=x86_64-linux ;;
	    esac
	    [[ -n "$arch" ]] && build "$arch" "--host=$arch" "CC=gcc -${flag:1}" "$@"
	fi
    done < <(gcc -print-multi-lib)
}

native_arch="$(bash texlive-arch.sh)"

build "$native_arch" "$@"

case "$native_arch" in
    x86_64-darwin)
        cross-osx universal-darwin i386-apple-darwin9.0 --disable-dependency-tracking "$@"
	;;
    *-linux)
	cross_windows "$@"
	cross_linux "$@"
	;;
esac
