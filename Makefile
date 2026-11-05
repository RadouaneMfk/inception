LOGIN    = rmouafik
DATA_DIR = /home/$(LOGIN)/data
COMPOSE  = docker compose -f srcs/docker-compose.yml

all: up

up:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v --rmi all
	sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

re: fclean all

.PHONY: all up down stop start ps logs clean fclean re