#!/usr/bin/env bash

echo ""
echo "*** Getting needed packages ***"
echo ""

HOST=x86_64

pacman -S mingw-w64-$HOST-cmake --noconfirm
pacman -S mingw-w64-$HOST-clang --noconfirm
pacman -S make --noconfirm
pacman -S mingw-w64-$HOST-dlfcn --noconfirm

echo ""
echo "*** All done ***"
echo ""
