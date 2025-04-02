#!/bin/bash

# Улучшенный WordPress Docker Deployment Script

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       WordPress Docker Deployment           ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Проверка существования .env файла
if [ ! -f .env ]; then
    echo -e "${YELLOW}Файл .env не найден. Нужно создать его.${NC}"
    
    # Запрос домена
    read -p "Введите домен (например, example.com): " domain_name
    
    # Запрос email для Let's Encrypt
    read -p "Введите email для SSL-сертификатов: " acme_email
    
    # Генерация надежных паролей
    mysql_root_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
    mysql_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
    redis_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
    
    # Определение часового пояса
    TZ=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || echo "UTC")
    
    # Создание .env файла
    cat > .env << EOL
# Domain settings
DOMAIN_NAME=${domain_name}
ACME_EMAIL=${acme_email}

# Database settings
MYSQL_ROOT_PASSWORD=${mysql_root_password}
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=${mysql_password}
WP_TABLE_PREFIX=wp_

# Redis settings
REDIS_PASSWORD=${redis_password}

# Timezone
TZ=${TZ}
EOL

    echo -e "${GREEN}Файл .env создан успешно!${NC}"
    
    # Сохранение учетных данных
    echo "WordPress Credentials" > wordpress_credentials.txt
    echo "Domain: $domain_name" >> wordpress_credentials.txt
    echo "MySQL Root Password: $mysql_root_password" >> wordpress_credentials.txt
    echo "MySQL Password: $mysql_password" >> wordpress_credentials.txt
    echo "Redis Password: $redis_password" >> wordpress_credentials.txt
    echo -e "${YELLOW}Учетные данные сохранены в: wordpress_credentials.txt${NC}"
else
    echo -e "${GREEN}Файл .env найден. Загрузка конфигурации...${NC}"
    source .env
fi

# Настройка File Manager
echo -e "${YELLOW}Настройка доступа к файлам WordPress через File Manager...${NC}"
if ! grep -q "FILE_MANAGER_ENABLED" .env; then
    echo "FILE_MANAGER_ENABLED=true" >> .env
    source .env
fi

# Создание необходимых директорий
echo -e "${YELLOW}Создание необходимых директорий...${NC}"
mkdir -p letsencrypt nginx/logs mysql redis nginx/conf.d backups

# Применение оптимизаций для Nginx
echo -e "${YELLOW}Настройка оптимизаций Nginx...${NC}"

# Настройки безопасности
cat > nginx/conf.d/security.conf << 'EOL'
# Заголовки безопасности
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# Отключение вывода версии Nginx
server_tokens off;
EOL

# Настройки кеширования и производительности
cat > nginx/conf.d/performance.conf << 'EOL'
# Кеширование статического контента
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}

# Включение gzip
gzip on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_types text/plain text/css application/javascript application/json image/svg+xml;
EOL

# Установка исполняемых прав на скрипты
chmod +x *.sh

# Проверка существующих контейнеров
echo -e "${YELLOW}Проверка существующих контейнеров...${NC}"
container_names=("wordpress" "wordpress-nginx" "wordpress-db" "wordpress-redis")

# Проверка Traefik отдельно
if docker ps -a --format '{{.Names}}' | grep -q "^traefik$"; then
    echo -e "${YELLOW}Найден существующий контейнер Traefik.${NC}"
    echo -e "${YELLOW}Этот контейнер может использоваться другими сервисами (например, Portainer).${NC}"
    read -p "Использовать существующий Traefik? (y/n): " use_existing_traefik
    
    if [[ "$use_existing_traefik" =~ ^[Yy]$ ]]; then
        # Создаем новый docker-compose без секции Traefik
        echo "# Временный файл, использующий существующий Traefik" > docker-compose.new.yml

        # Удаляем секцию Traefik и сохраняем остальное
        local record_services=false
        local skip_line=false

        while IFS= read -r line; do
            # Начало секции services
            if [[ "$line" =~ ^services: ]]; then
                record_services=true
                echo "$line" >> docker-compose.new.yml
                continue
            fi

            # Начало секции traefik
            if $record_services && [[ "$line" =~ ^[[:space:]]+traefik: ]]; then
                skip_line=true
                continue
            fi

            # Конец секции traefik
            if $skip_line && [[ "$line" =~ ^[[:space:]]+wordpress: ]]; then
                skip_line=false
            fi

            # Записываем строки, если они не в секции traefik
            if ! $skip_line; then
                echo "$line" >> docker-compose.new.yml
            fi
        done < docker-compose.yml

        # Заменяем оригинальный файл
        mv docker-compose.new.yml docker-compose.yml
        echo -e "${GREEN}Настроено использование существующего Traefik.${NC}"
    else
        # Изменяем имя контейнера Traefik в docker-compose.yml
        sed -i 's/container_name: traefik/container_name: wordpress-traefik/g' docker-compose.yml
        # Изменяем имя в лейблах для других сервисов
        sed -i 's/traefik.http.routers/traefik.http.routers.wordpress/g' docker-compose.yml
        sed -i 's/traefik.http.middlewares/traefik.http.middlewares.wordpress/g' docker-compose.yml
        echo -e "${GREEN}Traefik переименован в wordpress-traefik для избежания конфликтов.${NC}"
    fi
fi

# Проверка остальных контейнеров
for container in "${container_names[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
        echo -e "${YELLOW}Найден существующий контейнер: $container. Удаление...${NC}"
        docker stop $container 2>/dev/null
        docker rm $container 2>/dev/null
    fi
done

# Запуск контейнеров
echo -e "${YELLOW}Запуск Docker контейнеров...${NC}"
docker-compose up -d

# Получение публичного IP
public_ip=$(curl -s https://ipinfo.io/ip || echo "Не удалось определить")

# Ожидание запуска контейнеров
echo -e "${YELLOW}Ожидание запуска контейнеров...${NC}"
sleep 10

# Проверка статуса контейнеров
echo -e "${YELLOW}Проверка статуса контейнеров:${NC}"
docker-compose ps

# Создание скрипта для мониторинга
cat > monitor.sh << 'EOL'
#!/bin/bash
source .env

# Проверка доступности сайта
status_code=$(curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN_NAME} 2>/dev/null || echo "000")

if [ "$status_code" != "200" ]; then
    echo "[$(date)] Сайт недоступен (код ответа: $status_code). Перезапуск контейнеров..."
    docker-compose restart
else
    echo "[$(date)] Сайт работает нормально (код ответа: $status_code)"
fi

# Проверка использования диска
disk_usage=$(df -h | grep '/dev/sda1' | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    echo "[$(date)] ПРЕДУПРЕЖДЕНИЕ: Высокое использование диска: ${disk_usage}%"
fi
EOL
chmod +x monitor.sh

# Добавление задачи мониторинга в crontab
(crontab -l 2>/dev/null | grep -v "$(pwd)/monitor.sh"; echo "*/30 * * * * $(pwd)/monitor.sh >> $(pwd)/monitoring.log 2>&1") | crontab -

# Вывод информации о деплое
echo -e "\n${GREEN}Деплой успешно завершен!${NC}"
echo -e "${YELLOW}WordPress развернут с NGINX, SSL и Redis.${NC}"
echo -e "${YELLOW}Может потребоваться несколько минут для полного запуска всех служб.${NC}"
echo -e "${YELLOW}SSL-сертификаты будут автоматически получены от Let's Encrypt.${NC}"
echo -e "${GREEN}IP вашего сервера: ${public_ip}${NC}"
echo -e "${GREEN}Доступ к WordPress: https://${DOMAIN_NAME}${NC}"
echo -e "${GREEN}Админ-панель: https://${DOMAIN_NAME}/wp-admin${NC}"
echo -e "${YELLOW}Для просмотра логов: docker-compose logs${NC}"
echo -e "${YELLOW}Для остановки служб: docker-compose down${NC}"
echo -e "${YELLOW}Для перезапуска служб: docker-compose restart${NC}"
echo -e "${YELLOW}Для создания резервной копии: ./backup.sh${NC}"
echo -e "${YELLOW}Для мониторинга: ./monitor.sh${NC}"

# Установка и настройка File Manager
if [ "${FILE_MANAGER_ENABLED}" = "true" ]; then
  echo -e "${YELLOW}Ожидание инициализации WordPress...${NC}"
  sleep 45 # Ожидание полной инициализации WordPress
  
  echo -e "${YELLOW}Установка WP-CLI в контейнер WordPress...${NC}"
  docker-compose exec -T wordpress bash -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Не удалось установить WP-CLI. Используйте админ-панель для установки плагинов.${NC}"
  else
    echo -e "${GREEN}WP-CLI успешно установлен!${NC}"
    
    echo -e "${YELLOW}Установка и настройка плагина File Manager...${NC}"
    docker-compose exec -T wordpress wp plugin install wp-file-manager --activate --allow-root
    
    # Настройка безопасности File Manager (ограничение доступа только для администраторов)
    docker-compose exec -T wordpress wp option add wp_file_manager_settings '{"fm_enable_root":"1","fm_enable_media":"1","fm_public_write":"0","fm_private_write":"0"}' --format=json
  fi
  
  echo -e "${GREEN}Плагин File Manager успешно установлен${NC}"
  echo -e "${GREEN}Доступ к файловому менеджеру через админ-панель: https://${DOMAIN_NAME}/wp-admin → WP File Manager${NC}"
fi