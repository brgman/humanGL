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
```bash
make run
```
or 
```bash
SDL_VIDEODRIVER=x11 zig build run
```

`SDL_VIDEODRIVER=x11` is needed on the school PCs.

## Trubleshutting

```bash
ls ~/.config/Code/User/globalStorage/ziglang.vscode-zig/zig/
export PATH="$HOME/.config/Code/User/globalStorage/ziglang.vscode-zig/zig/x86_64-linux-0.17.0:$PATH"
zig version
make run
```

# Fonctions OpenGl

Les noms sont ceux de `zopengl.bindings` (alias `gl` dans le code). La fonction C correspondante porte le préfixe `gl` et une majuscule : `gl.clear` correspond à `glClear`, `gl.drawArrays` à `glDrawArrays`.

## Sources
https://www.youtube.com/watch?v=GnoauFXoxwo&list=PLfyiNADFEW5dE5hJ4xWGbIOGu3V2k3iru
