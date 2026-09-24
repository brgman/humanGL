#include <glad/glad.h>       // before SDL.h (glad lui-même détermine les GL-types)
#include <SDL3/SDL.h>
#include <cstdio>

int main() {
    // 1. Initialisation SDL - sous-système vidéo uniquement
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::fprintf(stderr, "main: SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    // 2. Attributs de contexte - AVANT la création de la fenêtre
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    // 3. fenêtre de drapeau OpenGL
    SDL_Window* window = SDL_CreateWindow(
        "HumanGL",
        800, 600,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
    );
    if (!window) { 
        std::fprintf(stderr, "main: SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    // 4. Créer un contexte
    SDL_GLContext gl_context = SDL_GL_CreateContext(window);
    if (!gl_context) {
        std::fprintf(stderr, "main: SDL_GL_CreateContext failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    // 5. Charger les indicateurs dans la fonction OpenGL via GLAD
    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress)) {
        std::fprintf(stderr, "main: gladLoadGLLoader failed\n");
        return 1;
    }

    std::printf("main: OpenGL loaded: %s\n", glGetString(GL_VERSION));

    // 6. Main loop
    bool running = true;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
            if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE) {
                running = false;
            }
        }

        glClearColor(0.3f, 0.3f, 0.3f, 1.0f); // gray
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        SDL_GL_SwapWindow(window);
    }

    // 7. Clean resources
    SDL_GL_DestroyContext(gl_context);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}