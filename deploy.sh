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
    
    # Запрос данных для WordPress
    read -p "Введите заголовок сайта: " wp_title
    read -p "Введите имя администратора: " wp_admin_user
    read -p "Введите пароль администратора (оставьте пустым для генерации): " wp_admin_password
    read -p "Введите email администратора: " wp_admin_email
    
    # Генерация надежного пароля, если не введен
    if [ -z "$wp_admin_password" ]; then
        wp_admin_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
        echo -e "${GREEN}Сгенерирован пароль для администратора: $wp_admin_password${NC}"
    fi
    
    # Генерация надежных паролей для сервисов
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

# WordPress settings
WP_TITLE="${wp_title}"
WP_ADMIN_USER=${wp_admin_user}
WP_ADMIN_PASSWORD=${wp_admin_password}
WP_ADMIN_EMAIL=${wp_admin_email}

# Timezone
TZ=${TZ}

# File Manager settings
FILE_MANAGER_ENABLED=true
EOL

    echo -e "${GREEN}Файл .env создан успешно!${NC}"
    
    # Сохранение учетных данных
    echo "WordPress Credentials" > wordpress_credentials.txt
    echo "Domain: $domain_name" >> wordpress_credentials.txt
    echo "Site Title: $wp_title" >> wordpress_credentials.txt
    echo "Admin Username: $wp_admin_user" >> wordpress_credentials.txt
    echo "Admin Password: $wp_admin_password" >> wordpress_credentials.txt
    echo "Admin Email: $wp_admin_email" >> wordpress_credentials.txt
    echo "MySQL Root Password: $mysql_root_password" >> wordpress_credentials.txt
    echo "MySQL Password: $mysql_password" >> wordpress_credentials.txt
    echo "Redis Password: $redis_password" >> wordpress_credentials.txt
    echo -e "${YELLOW}Учетные данные сохранены в: wordpress_credentials.txt${NC}"
    
    # Установка прав на файл с учетными данными
    chmod 600 wordpress_credentials.txt
else
    echo -e "${GREEN}Файл .env найден. Загрузка конфигурации...${NC}"
    source .env
fi

# Создание необходимых директорий
echo -e "${YELLOW}Создание необходимых директорий...${NC}"
mkdir -p letsencrypt nginx/logs mysql redis nginx/conf.d backups wp-content/{plugins,themes,uploads}

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

# Создание конфигурации для wp-config.php
cat > wp-config-custom.php << 'EOL'
<?php
// ** Настройки Redis кэширования ** //
define('WP_CACHE', true);
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PASSWORD', getenv('REDIS_PASSWORD'));
define('WP_REDIS_PORT', '6379');

// ** Дополнительные настройки безопасности ** //
define('DISALLOW_FILE_EDIT', true);
define('AUTOMATIC_UPDATER_DISABLED', false);
define('WP_AUTO_UPDATE_CORE', 'minor');

// ** Настройки для разработки ** //
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
EOL

# Создание docker-compose.yml, если его нет
if [ ! -f docker-compose.yml ]; then
    echo -e "${YELLOW}Создание docker-compose.yml...${NC}"
    cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  traefik:
    container_name: traefik
    image: traefik:v2.9
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--accesslog=true"
      - "--log.level=INFO"
    networks:
      - wp_network

  db:
    container_name: wordpress-db
    image: mysql:8.0
    restart: always
    volumes:
      - "./mysql:/var/lib/mysql"
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wp_network

  redis:
    container_name: wordpress-redis
    image: redis:6-alpine
    restart: always
    volumes:
      - "./redis:/data"
    command: redis-server --requirepass ${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wp_network

  wordpress:
    container_name: wordpress
    image: wordpress:6-fpm
    restart: always
    depends_on:
      - db
      - redis
    volumes:
      - "./wp-content:/var/www/html/wp-content"
      - "./wp-config-custom.php:/var/www/html/wp-config-custom.php"
    environment:
      - WORDPRESS_DB_HOST=db
      - WORDPRESS_DB_NAME=${MYSQL_DATABASE}
      - WORDPRESS_DB_USER=${MYSQL_USER}
      - WORDPRESS_DB_PASSWORD=${MYSQL_PASSWORD}
      - WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
      - WORDPRESS_CONFIG_EXTRA=include_once('/var/www/html/wp-config-custom.php');
    healthcheck:
      test: ["CMD", "php", "-v"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wp_network

  nginx:
    container_name: wordpress-nginx
    image: nginx:1.21-alpine
    restart: always
    depends_on:
      - wordpress
    volumes:
      - "./nginx/conf.d:/etc/nginx/conf.d"
      - "./nginx/logs:/var/log/nginx"
      - "./wp-content:/var/www/html/wp-content"
      - "./wp-content/uploads:/var/www/html/wp-content/uploads"
    networks:
      - wp_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`${DOMAIN_NAME}`)"
      - "traefik.http.routers.wordpress.entrypoints=websecure"
      - "traefik.http.routers.wordpress.tls=true"
      - "traefik.http.routers.wordpress.tls.certresolver=myresolver"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"

networks:
  wp_network:
    driver: bridge
EOL

    # Создание nginx.conf для проксирования запросов к WordPress
    mkdir -p nginx/conf.d
    cat > nginx/conf.d/default.conf << EOL
server {
    listen 80;
    server_name localhost;

    # WordPress root
    root /var/www/html;
    index index.php;

    # Логи
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Обработка запросов к статическим файлам
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Проксирование PHP запросов к контейнеру WordPress
    location ~ \.php$ {
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # Запрет доступа к служебным файлам
    location ~ /\.(ht|git) {
        deny all;
    }
}
EOL
fi

# Создание скрипта для резервного копирования
cat > backup.sh << 'EOL'
#!/bin/bash
source .env

# Директория для бэкапов
BACKUP_DIR="./backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/wordpress_backup_$DATE.tar.gz"

# Создаем директорию для бэкапов, если её нет
mkdir -p $BACKUP_DIR

echo "Создание резервной копии базы данных..."
docker-compose exec -T db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} > $BACKUP_DIR/db_backup_$DATE.sql

echo "Архивирование файлов WordPress..."
tar -czf $BACKUP_FILE wp-content $BACKUP_DIR/db_backup_$DATE.sql

# Удаляем временный дамп базы
rm $BACKUP_DIR/db_backup_$DATE.sql

echo "Резервная копия создана: $BACKUP_FILE"

# Удаление старых резервных копий (оставляем последние 5)
ls -t $BACKUP_DIR/wordpress_backup_*.tar.gz | tail -n +6 | xargs -r rm -f

echo "Старые резервные копии удалены."
EOL
chmod +x backup.sh

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

# Проверка состояния контейнеров
containers=("wordpress" "wordpress-nginx" "wordpress-db" "wordpress-redis")
for container in "${containers[@]}"; do
    status=$(docker ps -f "name=$container" --format "{{.Status}}" | grep -q "Up" && echo "OK" || echo "DOWN")
    if [ "$status" == "DOWN" ]; then
        echo "[$(date)] ПРЕДУПРЕЖДЕНИЕ: Контейнер $container остановлен. Попытка перезапуска..."
        docker start $container
    fi
done
EOL
chmod +x monitor.sh

# Создание скрипта администратора для управления WordPress
cat > admin.sh << 'EOL'
#!/bin/bash
source .env

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       WordPress Admin Management Tool       ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Проверка состояния WordPress
echo -e "${YELLOW}Проверка состояния WordPress...${NC}"
wp_status=$(docker-compose ps wordpress | grep "Up" && echo "OK" || echo "DOWN")

if [ "$wp_status" == "DOWN" ]; then
    echo -e "${RED}WordPress контейнер не запущен!${NC}"
    echo -e "${YELLOW}Запуск контейнеров...${NC}"
    docker-compose up -d
    sleep 10
fi

# Меню управления
while true; do
    echo -e "\n${BLUE}Выберите действие:${NC}"
    echo "1. Установить/активировать плагин"
    echo "2. Обновить WordPress"
    echo "3. Обновить все плагины"
    echo "4. Создать резервную копию"
    echo "5. Восстановить из резервной копии"
    echo "6. Изменить пароль администратора"
    echo "7. Перезапустить контейнеры"
    echo "8. Просмотреть логи"
    echo "9. Изменить настройки производительности"
    echo "10. Выход"
    
    read -p "Ваш выбор: " choice
    
    case $choice in
        1)
            read -p "Введите имя плагина для установки: " plugin_name
            echo -e "${YELLOW}Установка плагина $plugin_name...${NC}"
            docker-compose exec -T wordpress wp plugin install $plugin_name --activate --allow-root
            ;;
        2)
            echo -e "${YELLOW}Обновление WordPress до последней версии...${NC}"
            docker-compose exec -T wordpress wp core update --allow-root
            docker-compose exec -T wordpress wp core update-db --allow-root
            echo -e "${GREEN}WordPress обновлен!${NC}"
            ;;
        3)
            echo -e "${YELLOW}Обновление всех плагинов...${NC}"
            docker-compose exec -T wordpress wp plugin update --all --allow-root
            echo -e "${GREEN}Все плагины обновлены!${NC}"
            ;;
        4)
            echo -e "${YELLOW}Создание резервной копии...${NC}"
            ./backup.sh
            ;;
        5)
            echo -e "${YELLOW}Доступные резервные копии:${NC}"
            ls -lt ./backups/ | grep wordpress_backup | head -n 10
            read -p "Введите имя файла для восстановления: " backup_file
            
            if [ -f "./backups/$backup_file" ]; then
                echo -e "${YELLOW}Восстановление из резервной копии...${NC}"
                
                # Распаковка архива во временную директорию
                mkdir -p ./temp_restore
                tar -xzf "./backups/$backup_file" -C ./temp_restore
                
                # Восстановление базы данных
                echo -e "${YELLOW}Восстановление базы данных...${NC}"
                docker-compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} < ./temp_restore/db_backup_*.sql
                
                # Восстановление файлов
                echo -e "${YELLOW}Восстановление файлов...${NC}"
                rsync -a ./temp_restore/wp-content/ ./wp-content/
                
                # Очистка
                rm -rf ./temp_restore
                
                echo -e "${GREEN}Восстановление завершено!${NC}"
            else
                echo -e "${RED}Файл резервной копии не найден!${NC}"
            fi
            ;;
        6)
            read -p "Введите новый пароль для пользователя ${WP_ADMIN_USER}: " new_password
            echo -e "${YELLOW}Изменение пароля...${NC}"
            docker-compose exec -T wordpress wp user update ${WP_ADMIN_USER} --user_pass=${new_password} --allow-root
            echo -e "${GREEN}Пароль изменен!${NC}"
            # Обновление в .env
            sed -i "s/WP_ADMIN_PASSWORD=.*/WP_ADMIN_PASSWORD=${new_password}/" .env
            ;;
        7)
            echo -e "${YELLOW}Перезапуск контейнеров...${NC}"
            docker-compose restart
            echo -e "${GREEN}Контейнеры перезапущены!${NC}"
            ;;
        8)
            echo -e "${YELLOW}Выберите контейнер для просмотра логов:${NC}"
            echo "1. WordPress"
            echo "2. Nginx"
            echo "3. MySQL"
            echo "4. Redis"
            echo "5. Все контейнеры"
            read -p "Ваш выбор: " log_choice
            
            case $log_choice in
                1) docker-compose logs --tail=100 wordpress ;;
                2) docker-compose logs --tail=100 nginx ;;
                3) docker-compose logs --tail=100 db ;;
                4) docker-compose logs --tail=100 redis ;;
                5) docker-compose logs --tail=100 ;;
                *) echo -e "${RED}Неверный выбор!${NC}" ;;
            esac
            ;;
        9)
            echo -e "${YELLOW}Настройка производительности:${NC}"
            echo "1. Включить Object Cache (Redis)"
            echo "2. Настроить Nginx для кэширования"
            echo "3. Оптимизировать базу данных"
            echo "4. Вернуться в главное меню"
            
            read -p "Ваш выбор: " perf_choice
            
            case $perf_choice in
                1)
                    echo -e "${YELLOW}Установка и настройка Object Cache...${NC}"
                    docker-compose exec -T wordpress wp plugin install redis-cache --activate --allow-root
                    docker-compose exec -T wordpress wp redis enable --allow-root
                    echo -e "${GREEN}Object Cache настроен!${NC}"
                    ;;
                2)
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
                    docker-compose restart nginx
                    echo -e "${GREEN}Кэширование Nginx настроено!${NC}"
                    ;;
                3)
                    echo -e "${YELLOW}Оптимизация базы данных...${NC}"
                    docker-compose exec -T wordpress wp db optimize --allow-root
                    echo -e "${GREEN}База данных оптимизирована!${NC}"
                    ;;
                4) ;;
                *) echo -e "${RED}Неверный выбор!${NC}" ;;
            esac
            ;;
        10)
            echo -e "${GREEN}До свидания!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}"
            ;;
    esac
done
EOL
chmod +x admin.sh

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

# Ожидание запуска контейнеров и инициализации базы данных
echo -e "${YELLOW}Ожидание запуска и инициализации контейнеров...${NC}"
sleep 30

# Проверка состояния контейнеров
echo -e "${YELLOW}Проверка статуса контейнеров:${NC}"
docker-compose ps

# Инициализация WordPress, если еще не настроен
echo -e "${YELLOW}Проверка статуса установки WordPress...${NC}"
is_installed=$(docker-compose exec -T wordpress wp core is-installed --allow-root 2>/dev/null || echo "NOT_INSTALLED")

if [ "$is_installed" == "NOT_INSTALLED" ]; then
    echo -e "${YELLOW}WordPress еще не установлен. Инициализация...${NC}"
    
    # Установка WordPress core
    docker-compose exec -T wordpress wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root
    
    # Проверка результата установки
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}WordPress успешно установлен!${NC}"
        
        # Настройка постоянных ссылок
        docker-compose exec -T wordpress wp rewrite structure '/%postname%/' --allow-root
        
        # Удаление demo контента
        docker-compose exec -T wordpress wp post delete 1 --force --allow-root
        docker-compose exec -T wordpress wp post delete 2 --force --allow-root
        
        # Установка языка
        docker-compose exec -T wordpress wp language core install ru_RU --activate --allow-root
        
        # Установка и активация базовых плагинов
        echo -e "${YELLOW}Установка базовых плагинов...${NC}"
        docker-compose exec -T wordpress wp plugin install \
            wp-super-cache \
            wordfence \
            webp-express \
            contact-form-7 \
            wp-file-manager \
            --activate --allow-root
        
        # Установка темы
        docker-compose exec -T wordpress wp theme install astra --activate --allow-root
        
        echo -e "${GREEN}Базовые плагины и тема установлены!${NC}"
    else
        echo -e "${RED}Ошибка установки WordPress. Проверьте логи контейнера.${NC}"
    fi
fi

# Установка и настройка File Manager, если включен
if [ "${FILE_MANAGER_ENABLED}" = "true" ]; then
    echo -e "${YELLOW}Настройка File Manager...${NC}"
    
    # Проверка установки WP-CLI
    if ! docker-compose exec -T wordpress which wp >/dev/null 2>&1; then
        echo -e "${YELLOW}Установка WP-CLI в контейнер WordPress...${NC}"
        docker-compose exec -T wordpress bash -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"
    fi
    
    # Проверка установки плагина File Manager
    is_plugin_active=$(docker-compose exec -T wordpress wp plugin is-active wp-file-manager --allow-root 2>/dev/null || echo "NOT_ACTIVE")
    
    if [ "$is_plugin_active" == "NOT_ACTIVE" ]; then
        echo -e "${YELLOW}Установка и активация плагина File Manager...${NC}"
        docker-compose exec -T wordpress wp plugin install wp-file-manager --activate --allow-root
        
        # Настройка безопасности File Manager
        docker-compose exec -T wordpress wp option add wp_file_manager_settings '{"fm_enable_root":"1","fm_enable_media":"1","fm_public_write":"0","fm_private_write":"0"}' --format=json --allow-root
        
        echo -e "${GREEN}Плагин File Manager установлен и настроен!${NC}"
    else
        echo -e "${GREEN}Плагин File Manager уже установлен.${NC}"
    fi
fi

# Добавление задачи мониторинга в crontab
(crontab -l 2>/dev/null | grep -v "$(pwd)/monitor.sh"; echo "*/30 * * * * $(pwd)/monitor.sh >> $(pwd)/monitoring.log 2>&1") | crontab -

# Создание скрипта для обновления
cat > update.sh << 'EOL'
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
EOL
chmod +x update.sh

# Создание скрипта для оптимизации производительности
cat > optimize.sh << 'EOL'
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
EOL
chmod +x optimize.sh

# Создание скрипта для настройки безопасности
cat > secure.sh << 'EOL'
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
EOL
chmod +x secure.sh

# Вывод информации о деплое
echo -e "\n${GREEN}Деплой успешно завершен!${NC}"
echo -e "${YELLOW}WordPress развернут с NGINX, SSL и Redis.${NC}"
echo -e "${YELLOW}Может потребоваться несколько минут для полного запуска всех служб и получения SSL-сертификатов.${NC}"
echo -e "${GREEN}IP вашего сервера: ${public_ip}${NC}"
echo -e "${GREEN}Доступ к WordPress: https://${DOMAIN_NAME}${NC}"
echo -e "${GREEN}Админ-панель: https://${DOMAIN_NAME}/wp-admin${NC}"
echo -e "${GREEN}Логин администратора: ${WP_ADMIN_USER}${NC}"
echo -e "${GREEN}Пароль администратора: ${WP_ADMIN_PASSWORD}${NC}"

echo -e "\n${BLUE}Доступные команды:${NC}"
echo -e "${YELLOW}./admin.sh${NC} - Управление WordPress (плагины, обновления, и т.д.)"
echo -e "${YELLOW}./backup.sh${NC} - Создание резервной копии"
echo -e "${YELLOW}./update.sh${NC} - Обновление WordPress, плагинов и тем"
echo -e "${YELLOW}./optimize.sh${NC} - Оптимизация производительности"
echo -e "${YELLOW}./secure.sh${NC} - Настройка безопасности"
echo -e "${YELLOW}./monitor.sh${NC} - Проверка статуса сайта"
echo -e "${YELLOW}docker-compose logs${NC} - Просмотр логов контейнеров"
echo -e "${YELLOW}docker-compose down${NC} - Остановка всех контейнеров"
echo -e "${YELLOW}docker-compose up -d${NC} - Запуск всех контейнеров"

# Запись информации о деплое в файл
echo "WordPress Deployment Information" > deployment_info.txt
echo "Domain: ${DOMAIN_NAME}" >> deployment_info.txt
echo "Server IP: ${public_ip}" >> deployment_info.txt
echo "Admin URL: https://${DOMAIN_NAME}/wp-admin" >> deployment_info.txt
echo "Admin Username: ${WP_ADMIN_USER}" >> deployment_info.txt
echo "Admin Password: ${WP_ADMIN_PASSWORD}" >> deployment_info.txt
echo "MySQL Root Password: ${MYSQL_ROOT_PASSWORD}" >> deployment_info.txt
echo "MySQL WordPress User: ${MYSQL_USER}" >> deployment_info.txt
echo "MySQL WordPress Password: ${MYSQL_PASSWORD}" >> deployment_info.txt
echo "Redis Password: ${REDIS_PASSWORD}" >> deployment_info.txt
echo "Deployment Date: $(date)" >> deployment_info.txt
chmod 600 deployment_info.txt

echo -e "\n${GREEN}Информация о развертывании сохранена в файле: deployment_info.txt${NC}"
echo -e "${YELLOW}ВНИМАНИЕ: Храните этот файл в безопасном месте, он содержит все учетные данные.${NC}"

exit 0