#!/bin/bash
source .env

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}     WordPress Performance Optimization     ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Создание резервной копии перед оптимизацией
echo -e "${YELLOW}Создание резервной копии перед оптимизацией...${NC}"
./backup.sh

# Оптимизация базы данных
echo -e "${YELLOW}Оптимизация базы данных...${NC}"
docker-compose exec -T wordpress wp db optimize --allow-root

# Установка и настройка кэширования
echo -e "${YELLOW}Настройка кэширования...${NC}"

# Проверка и установка плагина Redis Cache
is_redis_plugin_active=$(docker-compose exec -T wordpress wp plugin is-active redis-cache --allow-root 2>/dev/null || echo "NOT_ACTIVE")
if [ "$is_redis_plugin_active" == "NOT_ACTIVE" ]; then
    echo -e "${YELLOW}Установка и активация плагина Redis Cache...${NC}"
    docker-compose exec -T wordpress wp plugin install redis-cache --activate --allow-root
    docker-compose exec -T wordpress wp redis enable --allow-root
fi

# Проверка и установка плагина WP Super Cache
is_super_cache_active=$(docker-compose exec -T wordpress wp plugin is-active wp-super-cache --allow-root 2>/dev/null || echo "NOT_ACTIVE")
if [ "$is_super_cache_active" == "NOT_ACTIVE" ]; then
    echo -e "${YELLOW}Установка и активация плагина WP Super Cache...${NC}"
    docker-compose exec -T wordpress wp plugin install wp-super-cache --activate --allow-root
    
    # Базовая настройка WP Super Cache
    docker-compose exec -T wordpress wp super-cache enable --allow-root
fi

# Настройка Nginx для кэширования
echo -e "${YELLOW}Настройка кэширования Nginx...${NC}"
cat > nginx/conf.d/cache.conf << 'CACHE_EOL'
# Директория для кэша
fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=wordpress:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;

# Кэширование для WordPress
location ~ \.php$ {
    fastcgi_pass wordpress:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_cache wordpress;
    fastcgi_cache_valid 200 60m;
    fastcgi_cache_bypass $http_pragma;
    fastcgi_cache_methods GET HEAD;
    add_header X-FastCGI-Cache $upstream_cache_status;
}
CACHE_EOL

# Оптимизация изображений
echo -e "${YELLOW}Настройка оптимизации изображений...${NC}"
is_webp_active=$(docker-compose exec -T wordpress wp plugin is-active webp-express --allow-root 2>/dev/null || echo "NOT_ACTIVE")
if [ "$is_webp_active" == "NOT_ACTIVE" ]; then
    echo -e "${YELLOW}Установка и активация плагина WebP Express...${NC}"
    docker-compose exec -T wordpress wp plugin install webp-express --activate --allow-root
fi

# Перезапуск контейнеров для применения изменений
echo -e "${YELLOW}Перезапуск контейнеров для применения изменений...${NC}"
docker-compose restart

echo -e "${GREEN}Оптимизация завершена!${NC}"
