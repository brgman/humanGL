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

## Informations

- `gl.getString(name)` : renvoie une chaîne de texte décrivant le pilote (version OpenGL, fabricant, carte graphique). On l'utilise avec `gl.VERSION` pour vérifier que le contexte est bien chargé.

## Shaders

- `gl.createShader(type)` : crée un objet shader vide et renvoie son identifiant. Le type est `gl.VERTEX_SHADER` ou `gl.FRAGMENT_SHADER`.
- `gl.shaderSource(shader, count, strings, lengths)` : donne au shader son code source GLSL. `count` est le nombre de chaînes, `lengths` vaut `null` quand les chaînes se terminent par un zéro.
- `gl.compileShader(shader)` : demande au pilote de compiler le code source du shader.
- `gl.getShaderiv(shader, pname, params)` : lit une propriété du shader. Avec `gl.COMPILE_STATUS`, elle indique si la compilation a réussi.
- `gl.getShaderInfoLog(shader, maxLength, length, log)` : copie le message d'erreur de compilation dans un tampon, pour pouvoir l'afficher.
- `gl.deleteShader(shader)` : supprime l'objet shader. On peut le faire dès que le programme est lié, car le programme en garde sa propre copie.

## Programme

- `gl.createProgram()` : crée un programme vide, qui assemblera les shaders.
- `gl.attachShader(program, shader)` : attache un shader compilé au programme.
- `gl.linkProgram(program)` : relie le vertex shader et le fragment shader en un seul programme exécutable par le GPU.
- `gl.getProgramiv(program, pname, params)` : lit une propriété du programme. Avec `gl.LINK_STATUS`, elle indique si l'édition de liens a réussi.
- `gl.getProgramInfoLog(program, maxLength, length, log)` : copie le message d'erreur d'édition de liens dans un tampon.
- `gl.useProgram(program)` : active le programme. Tous les dessins suivants utilisent ses shaders.
- `gl.deleteProgram(program)` : supprime le programme à la fin de l'exécution.

## Uniforms (variables envoyées aux shaders)

- `gl.getUniformLocation(program, name)` : renvoie l'emplacement d'un uniform à partir de son nom (par exemple `"uModel"`). On garde ce numéro pour l'envoi des valeurs.
- `gl.uniformMatrix4fv(location, count, transpose, value)` : envoie une ou plusieurs matrices 4×4 de nombres flottants. `transpose` vaut `gl.FALSE` car nos matrices sont déjà en column-major.
- `gl.uniform3f(location, x, y, z)` : envoie un vecteur de 3 flottants (la taille `uSize` et la couleur `uColor`).

## Tampons (buffers) et VAO

- `gl.genBuffers(n, buffers)` : crée `n` identifiants de tampons (VBO) qui vivront dans la mémoire du GPU.
- `gl.bindBuffer(target, buffer)` : active un tampon pour la cible indiquée. Avec `gl.ARRAY_BUFFER`, les commandes suivantes concernent ce tampon de sommets.
- `gl.bufferData(target, size, data, usage)` : alloue le tampon actif et copie les données du CPU vers le GPU. `size` est en octets. `gl.STATIC_DRAW` indique que les données ne changeront presque jamais.
- `gl.deleteBuffers(n, buffers)` : libère les tampons.
- `gl.genVertexArrays(n, arrays)` : crée `n` objets VAO. Un VAO mémorise comment lire les tampons de sommets.
- `gl.bindVertexArray(vao)` : active un VAO. Il restitue tous les réglages d'attributs enregistrés avec lui.
- `gl.deleteVertexArrays(n, arrays)` : libère les VAO.
- `gl.vertexAttribPointer(index, size, type, normalized, stride, offset)` : décrit le format d'un attribut. `index` est l'emplacement dans le shader (`location`), `size` le nombre de composantes (3 pour une position), `type` le type (`gl.FLOAT`), `stride` la distance en octets entre deux sommets, `offset` la position de l'attribut dans un sommet.
- `gl.enableVertexAttribArray(index)` : active l'attribut, sinon le shader ne lit pas ses données.

## Dessin

- `gl.drawArrays(mode, first, count)` : lance le dessin. `mode` est le type de primitive (`gl.TRIANGLES`), `first` l'indice du premier sommet, `count` le nombre de sommets à traiter.
- `gl.clearColor(r, g, b, a)` : choisit la couleur utilisée pour effacer l'écran.
- `gl.clear(mask)` : efface les tampons indiqués par le masque. `gl.COLOR_BUFFER_BIT` efface l'image, `gl.DEPTH_BUFFER_BIT` efface le tampon de profondeur. On combine les deux avec `|`.
- `gl.viewport(x, y, width, height)` : définit la zone de la fenêtre où OpenGL dessine, en pixels. Elle doit suivre la taille de la fenêtre.

## États

- `gl.enable(capability)` : active une fonctionnalité d'OpenGL. Avec `gl.DEPTH_TEST`, on active le test de profondeur : un pixel n'est dessiné que s'il est plus proche que ce qui est déjà affiché.

## Constantes utilisées

- `gl.VERSION` : demande la chaîne de version à `getString`.
- `gl.VERTEX_SHADER` et `gl.FRAGMENT_SHADER` : types de shaders.
- `gl.COMPILE_STATUS` et `gl.LINK_STATUS` : propriétés à interroger après la compilation et l'édition de liens.
- `gl.ARRAY_BUFFER` : cible des tampons de sommets.
- `gl.STATIC_DRAW` : indice d'usage pour des données écrites une fois et dessinées souvent.
- `gl.FLOAT` : type de données « nombre flottant 32 bits ».
- `gl.FALSE` : valeur booléenne OpenGL (zéro).
- `gl.DEPTH_TEST` : fonctionnalité de test de profondeur.
- `gl.COLOR_BUFFER_BIT` et `gl.DEPTH_BUFFER_BIT` : masques pour `clear`.
- `gl.TRIANGLES` : mode de dessin « un triangle pour chaque groupe de 3 sommets ».

## Fonctions SDL liées à OpenGL

Elles ne font pas partie d'OpenGL mais créent et gèrent le contexte.

- `SDL_GL_SetAttribute(attr, value)` : règle les attributs du futur contexte (version, profil core, double tampon, profondeur, multi-échantillonnage). À appeler avant `SDL_CreateWindow`.
- `SDL_GL_CreateContext(window)` : crée le contexte OpenGL de la fenêtre et le rend actif.
- `SDL_GL_DestroyContext(context)` : détruit le contexte à la fin.
- `SDL_GL_SetSwapInterval(interval)` : règle la synchronisation verticale. Avec 1, le dessin suit la fréquence de l'écran.
- `SDL_GL_GetProcAddress(name)` : renvoie l'adresse d'une fonction OpenGL par son nom. `zopengl` s'en sert pour charger toutes les fonctions.
- `SDL_GL_SwapWindow(window)` : échange le tampon arrière et le tampon avant : l'image dessinée devient visible.

## Chargeur

- `zopengl.loadCoreProfile(getProcAddress, major, minor)` : charge toutes les fonctions du profil core pour la version demandée en appelant notre `getProcAddress`. Renvoie une erreur si le chargement échoue.

## Sources
https://www.youtube.com/watch?v=GnoauFXoxwo&list=PLfyiNADFEW5dE5hJ4xWGbIOGu3V2k3iru
