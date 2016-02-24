#ifndef __included_crawl_compile_flags_h
#define __included_crawl_compile_flags_h

#define CRAWL_CFLAGS "-O2 -pipe -DUSE_TILE -DUSE_TILE_LOCAL -DUSE_SDL -DUSE_GL -DUSE_FT -DUSE_SOUND -Wall -Wformat-security -Wundef -Wno-array-bounds -Wno-format-zero-length -Wmissing-declarations -Wredundant-decls -Wno-parentheses -Wwrite-strings -Wshadow -pedantic -Wuninitialized -Iutil -I. -Irltiles -isystem contrib/install/x86_64-apple-darwin15.0.0/include/SDL2 -isystem contrib/install/x86_64-apple-darwin15.0.0/include/freetype2 -isystem /usr/include/ncurses -isystem contrib/install/x86_64-apple-darwin15.0.0/include -DTOURNEY='0.17' -DWIZARD -DASSERTS -DPROPORTIONAL_FONT=\"contrib/fonts/DejaVuSans.ttf\" -DMONOSPACED_FONT=\"contrib/fonts/DejaVuSansMono.ttf\" -DCLUA_BINDINGS"
#define CRAWL_LDFLAGS "-rdynamic -O2 "
#define CRAWL_HOST "x86_64-apple-darwin15.0.0"
#define CRAWL_ARCH "x86_64-apple-darwin15.0.0"

#endif

