# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: abergman <abergman@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/09/21 08:55:15 by abergman          #+#    #+#              #
#    Updated: 2026/10/16 12:50:04 by abergman         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME     = humangl
ZIG      = zig
VIDEODRV = x11

.PHONY: all $(NAME) run clean fclean re

all: $(NAME)

$(NAME):
	$(ZIG) build
	cp zig-out/bin/$(NAME) ./$(NAME)

run:
	SDL_VIDEODRIVER=$(VIDEODRV) $(ZIG) build run

clean:
	rm -rf .zig-cache

fclean: clean
	rm -rf zig-out $(NAME)

re: fclean all