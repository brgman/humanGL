# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: abergman <abergman@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/09/21 08:55:15 by abergman          #+#    #+#              #
#    Updated: 2026/09/21 09:22:16 by abergman         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = humangl

all: $(NAME)

$(NAME):
	zig build

run:
	SDL_VIDEODRIVER=x11 zig build run
	
clean:
	rm -rf .zig-cache

fclean: clean
	rm -rf zig-out

re: fclean all

.PHONY: all run clean fclean re