#!/bin/bash
source .env

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       WordPress Security Setup             ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Создание резервной копии перед настройкой безопасности
echo -e "${YELLOW}Создание резервной копии...${NC}"
./backup.sh

# Установка и настройка Wordfence
echo -e "${YELLOW}Настройка безопасности с Wordfence...${NC}"
is_wordfence_active=$(docker-compose exec -T wordpress wp plugin is-active wordfence --allow-root 2>/dev/null || echo "NOT_ACTIVE")
if [ "$is_wordfence_active" == "NOT_ACTIVE" ]; then
    echo -e "${YELLOW}Установка и активация плагина Wordfence...${NC}"
    docker-compose exec -T wordpress wp plugin install wordfence --activate --allow-root
fi

# Настройка безопасного wp-config.php
echo -e "${YELLOW}Настройка безопасного wp-config.php...${NC}"
cat > wp-config-security.php << 'WPSECURITY_EOL'
<?php
// Улучшенные настройки безопасности
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);  // Только для разработки, в продакшене установите true
define('FORCE_SSL_ADMIN', true);
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);

// Ограничение числа ревизий
define('WP_POST_REVISIONS', 3);

// Отключение прямого доступа к файлам плагинов и тем
define('CONCATENATE_SCRIPTS', true);
define('AUTOSAVE_INTERVAL', 300); // 5 минут
WPSECURITY_EOL

# Добавление настроек безопасности в основной файл конфигурации
docker-compose exec -T wordpress bash -c 'cat /var/www/html/wp-config-security.php >> /var/www/html/wp-config-custom.php'

# Настройка безопасности Nginx
echo -e "${YELLOW}Настройка безопасности Nginx...${NC}"
cat > nginx/conf.d/security-enhanced.conf << 'NGINX_SEC_EOL'
# Дополнительные заголовки безопасности
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Отключение вывода версии Nginx
server_tokens off;

# Блокировка доступа к скрытым файлам
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

# Блокировка доступа к конфигурационным файлам WordPress
location ~* wp-config.php {
    deny all;
}

# Блокировка доступа к установочным скриптам
location ~* (install|upgrade).php {
    deny all;
}

# Блокировка доступа к файлам логов
location ~* \.(log|txt|sql)$ {
    deny all;
}
NGINX_SEC_EOL

# Перезапуск контейнеров для применения изменений
echo -e "${YELLOW}Перезапуск контейнеров для применения изменений...${NC}"
docker-compose restart

echo -e "${GREEN}Настройка безопасности завершена!${NC}"
