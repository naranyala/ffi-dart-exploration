#/usr/bin/bash

zig build-lib src/main.zig -dynamic -OReleaseSmall -target x86_64-windows

zig build-lib src/main.zig -dynamic -OReleaseSmall -target x86_64-linux



