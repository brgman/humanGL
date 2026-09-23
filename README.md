# Friction specifically between Zig 0.16 (unstable, often breaking API) and @cImport, which doesn't always perfectly parsite "dirty" system headers.

# why C files ?

GLAD generates a loader for **OpenGL 4.0** in the form of a C-file - Zig compiles it directly, without additional tools, since GL-functions newer version 1.1 need to be loaded in rantime through pointers, and not connected statically.

_To run on the shcool PC - use video driver x11_
```
SDL_VIDEODRIVER=x11 ./zig-out/bin/humangl; echo "exit code: $?"
```

du -h --max-depth=1 /home/abergman/.var 2>/dev/null | sort -rh | head -20
