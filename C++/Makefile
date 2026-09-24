BUILD_DIR = build

all:
	cmake -B $(BUILD_DIR) -S .
	cmake --build $(BUILD_DIR)

run: all
	SDL_VIDEODRIVER=x11 ./$(BUILD_DIR)/humanGL

clean:
	rm -rf $(BUILD_DIR)

fclean: clean

re: fclean all

.PHONY: all run clean fclean re