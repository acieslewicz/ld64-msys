# ld64-msys
Apple LD64 linker for MSYS2 (Windows) and Linux and Unix.

This is a fork/copy of https://github.com/tpoechtrager/cctools-port

Especially https://github.com/tpoechtrager/cctools-port/tree/master/cctools/ld64

It has been adapted to compile with clang 12 on various OS including Windows and Linux.

The cctools are not needed anymore. Clang itself has all that is needed.

# Fork contains patches to get it building in MINGW64 with Clang19
Building:
```bash
pacman_packages.sh
buildblocksninja.sh
buildmmanninja.sh
buildtapininja.sh
buildld64make.sh
puts markdown.to_html
```

