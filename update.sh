#!/bin/bash
source .env

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       WordPress Update Script              ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Создание резервной копии перед обновлением
echo -e "${YELLOW}Создание резервной копии перед обновлением...${NC}"
./backup.sh

# Обновление образов Docker
echo -e "${YELLOW}Обновление Docker образов...${NC}"
docker-compose pull

# Обновление WordPress
echo -e "${YELLOW}Обновление WordPress...${NC}"
docker-compose exec -T wordpress wp core update --allow-root
docker-compose exec -T wordpress wp core update-db --allow-root

# Обновление плагинов
echo -e "${YELLOW}Обновление плагинов...${NC}"
docker-compose exec -T wordpress wp plugin update --all --allow-root

# Обновление тем
echo -e "${YELLOW}Обновление тем...${NC}"
docker-compose exec -T wordpress wp theme update --all --allow-root

# Перезапуск контейнеров
echo -e "${YELLOW}Перезапуск контейнеров...${NC}"
docker-compose restart

echo -e "${GREEN}Обновление завершено!${NC}"
