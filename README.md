# HumanGL

Written in Zig.

## Status

WIP. What works right now:

- SDL3 window with an OpenGL 4.0 core context
- OpenGL function loading with [zopengl](https://github.com/zig-gamedev/zopengl)
- Shaders (vertex + fragment), VAO/VBO, uniforms
- Test scene: orange triangle inside a blue circle on a grey background,
  stays round when the window is resized
- ESC or closing the window quits

## Build and run

Needs Zig 0.17 and SDL3 installed on the system.
```
make run
```
or
```
SDL_VIDEODRIVER=x11 zig build run
```

`SDL_VIDEODRIVER=x11` is needed on the school PCs.
