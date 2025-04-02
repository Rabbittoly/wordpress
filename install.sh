#!/bin/bash

# Улучшенный WordPress Docker Template Installation Script

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
setup_logging() {
  # Создание директории для логов
  mkdir -p logs
  LOG_FILE="logs/install_$(date +"%Y%m%d_%H%M%S").log"
  # Запись лога
  echo "[$(date)] Начало установки WordPress" > "$LOG_FILE"
}

# Запуск логирования
setup_logging

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}    WordPress Docker Template Installer      ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Функция проверки системных требований
check_system_requirements() {
  echo -e "${YELLOW}Проверка системных требований...${NC}"
  
  # Проверка свободного места
  AVAILABLE_DISK=$(df -m / | tail -1 | awk '{print $4}')
  if [ "$AVAILABLE_DISK" -lt 2048 ]; then
    echo -e "${YELLOW}Предупреждение: Доступно менее 2GB дискового пространства.${NC}"
  fi
}

# Запуск проверки
check_system_requirements

# Проверка и установка Docker
if ! command -v docker &> /dev/null; then
  echo -e "${RED}Docker не установлен. Установка Docker...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  sudo usermod -aG docker $USER
  if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка: Не удалось установить Docker${NC}"
    exit 1
  fi
  echo -e "${GREEN}Docker успешно установлен!${NC}"
fi

# Проверка и установка Docker Compose
if ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}Docker Compose не установлен. Установка Docker Compose...${NC}"
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка: Не удалось установить Docker Compose${NC}"
    exit 1
  fi
  echo -e "${GREEN}Docker Compose успешно установлен!${NC}"
fi

# Запрос директории установки
echo -e "${YELLOW}Выберите вариант установки:${NC}"
echo "1. Установить в текущую директорию ($(pwd))"
echo "2. Создать поддиректорию в текущей директории"
echo "3. Указать полный путь для установки"
read -p "Выберите вариант [1-3]: " install_option

case $install_option in
  1)
    # Установка в текущую директорию
    install_dir="."
    echo -e "${GREEN}Будет использована текущая директория: $(pwd)${NC}"
    # Проверка, пуста ли директория
    if [ "$(ls -A | grep -v '^\.'| wc -l)" -ne 0 ]; then
      echo -e "${YELLOW}Предупреждение: Текущая директория не пуста. Продолжить? (y/n)${NC}"
      read -p "" continue_empty
      if [[ ! "$continue_empty" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Установка отменена.${NC}"
        exit 0
      fi
    fi
    ;;
  2)
    # Создание поддиректории
    read -p "Введите имя поддиректории (по умолчанию: wordpress): " subdir_name
    subdir_name=${subdir_name:-wordpress}
    install_dir="$subdir_name"
    
    if [ -d "$install_dir" ]; then
      echo -e "${RED}Директория $install_dir уже существует. Выберите другое имя или удалите существующую директорию.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Будет создана директория: $(pwd)/$install_dir${NC}"
    ;;
  3)
    # Указание полного пути
    read -p "Введите полный путь для установки: " full_path
    if [ -z "$full_path" ]; then
      echo -e "${RED}Путь не может быть пустым.${NC}"
      exit 1
    fi
    
    # Проверка существования директории
    if [ -d "$full_path" ]; then
      echo -e "${YELLOW}Директория $full_path уже существует. Если продолжить, файлы могут быть перезаписаны.${NC}"
      read -p "Продолжить? (y/n): " continue_overwrite
      if [[ ! "$continue_overwrite" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Установка отменена.${NC}"
        exit 0
      fi
    else
      # Создание директории, если она не существует
      mkdir -p "$full_path"
      if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось создать директорию $full_path. Проверьте права доступа.${NC}"
        exit 1
      fi
    fi
    
    install_dir="$full_path"
    echo -e "${GREEN}Будет использован путь: $install_dir${NC}"
    ;;
  *)
    echo -e "${RED}Некорректный выбор. Установка отменена.${NC}"
    exit 1
    ;;
esac

# Клонирование репозитория
echo -e "${GREEN}Клонирование репозитория WordPress...${NC}"

# Разная логика в зависимости от типа инсталляции
if [ "$install_dir" = "." ]; then
  # В текущую директорию - клонируем содержимое без папки
  git clone --depth 1 https://github.com/Rabbittoly/wordpress.git temp_wp_clone
  if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка: Не удалось клонировать репозиторий${NC}"
    exit 1
  fi
  # Копируем содержимое без .git и удаляем временную директорию
  cp -r temp_wp_clone/* .
  cp -r temp_wp_clone/.* . 2>/dev/null || true
  rm -rf temp_wp_clone
  echo -e "${GREEN}Файлы успешно скопированы в текущую директорию${NC}"
else
  # Клонирование в указанную директорию
  git clone --depth 1 https://github.com/Rabbittoly/wordpress.git "$install_dir"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка: Не удалось клонировать репозиторий в $install_dir${NC}"
    exit 1
  fi
  echo -e "${GREEN}Репозиторий успешно клонирован в $install_dir${NC}"
fi

# Переход в директорию установки
cd "$install_dir"

# Настройка WordPress
echo -e "${YELLOW}Настройка вашего WordPress сайта...${NC}"

# Валидация ввода домена
domain_valid=false
while [ "$domain_valid" = false ]; do
  read -p "Введите имя домена (например, example.com): " domain_name
  
  # Проверка на пустое значение
  if [ -z "$domain_name" ]; then
    echo -e "${RED}Ошибка: Имя домена не может быть пустым.${NC}"
    continue
  fi
  
  # Проверка формата домена
  if [[ ! "$domain_name" =~ \. ]]; then
    echo -e "${RED}Ошибка: Неверный формат домена. Введите корректный домен (например, example.com).${NC}"
    continue
  fi
  
  # Подтверждение домена
  echo -e "${YELLOW}Вы ввели: ${GREEN}$domain_name${NC}"
  read -p "Это верно? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    domain_valid=true
  fi
done

# Валидация ввода email
email_valid=false
while [ "$email_valid" = false ]; do
  read -p "Введите ваш email для SSL-сертификатов Let's Encrypt: " acme_email
  
  # Проверка на пустое значение
  if [ -z "$acme_email" ]; then
    echo -e "${RED}Ошибка: Email не может быть пустым.${NC}"
    continue
  fi
  
  # Проверка формата email
  if [[ ! "$acme_email" =~ @ ]]; then
    echo -e "${RED}Ошибка: Неверный формат email. Введите корректный email.${NC}"
    continue
  fi
  
  # Подтверждение email
  echo -e "${YELLOW}Вы ввели: ${GREEN}$acme_email${NC}"
  read -p "Это верно? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    email_valid=true
  fi
done

# Запрос email для уведомлений
read -p "Введите email для отправки уведомлений (оставьте пустым, чтобы отключить): " notify_email

# Генерация надежных паролей
echo -e "${GREEN}Генерация надежных паролей...${NC}"
mysql_root_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
mysql_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
redis_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')

# Создание .env файла
echo -e "${GREEN}Создание .env файла...${NC}"
cat > .env << EOL
# Domain settings
DOMAIN_NAME=${domain_name}
ACME_EMAIL=${acme_email}
NOTIFY_EMAIL=${notify_email}

# Database settings
MYSQL_ROOT_PASSWORD=${mysql_root_password}
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=${mysql_password}
WP_TABLE_PREFIX=wp_

# Redis settings
REDIS_PASSWORD=${redis_password}

# Timezone
TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
EOL

# Создание необходимых директорий
mkdir -p letsencrypt nginx/logs backups nginx/conf.d

# Установка исполняемых прав для скриптов
chmod +x deploy.sh backup.sh restore.sh

# Отображение сводки конфигурации
echo -e "${GREEN}Сводка конфигурации:${NC}"
echo "Домен: $domain_name"
echo "Директория установки: $(pwd)"
echo ""
echo -e "${YELLOW}Пароли сохранены в файле .env:${NC}"
echo "Пароль root MySQL: $mysql_root_password"
echo "Пароль базы данных WordPress: $mysql_password"
echo "Пароль Redis: $redis_password"
echo ""

# Сохранение учетных данных в файл
echo "WordPress Setup Credentials" > wordpress_credentials.txt
echo "Domain: $domain_name" >> wordpress_credentials.txt
echo "MySQL Root Password: $mysql_root_password" >> wordpress_credentials.txt
echo "MySQL Password: $mysql_password" >> wordpress_credentials.txt
echo "Redis Password: $redis_password" >> wordpress_credentials.txt
echo -e "${YELLOW}Учетные данные сохранены в: wordpress_credentials.txt${NC}"

# Создание файла для мониторинга
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
EOL
chmod +x monitor.sh

# Создание файла администрирования
cat > admin.sh << 'EOL'
#!/bin/bash
echo "===== WordPress Admin Panel ====="
echo "1. Перезапустить службы"
echo "2. Остановить службы"
echo "3. Запустить службы"
echo "4. Показать логи"
echo "5. Создать резервную копию"
echo "0. Выход"

read -p "Выберите опцию: " option

case $option in
  1) docker-compose restart ;;
  2) docker-compose down ;;
  3) docker-compose up -d ;;
  4) docker-compose logs ;;
  5) ./backup.sh ;;
  0) exit 0 ;;
  *) echo "Неверный выбор" ;;
esac
EOL
chmod +x admin.sh

# Запрос на запуск деплоя
read -p "Запустить деплой сейчас? (y/n): " start_deploy
if [[ "$start_deploy" =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}Запуск деплоя...${NC}"
  ./deploy.sh
else
  echo -e "${YELLOW}Деплой не запущен. Вы можете запустить его позже с помощью ./deploy.sh${NC}"
fi

echo -e "${GREEN}Установка завершена!${NC}"
if [[ "$start_deploy" =~ ^[Yy]$ ]]; then
  echo -e "Ваш WordPress сайт должен быть доступен по адресу: https://$domain_name"
  echo -e "Для входа в админ-панель перейдите по адресу: https://$domain_name/wp-admin"
fi
echo -e "Для управления сайтом используйте: ./admin.sh"

# Предложение перейти в директорию установки, если она не является текущей
if [ "$install_dir" != "." ] && [ -d "$install_dir" ]; then
  echo -e "${YELLOW}Хотите перейти в директорию установки? (y/n)${NC}"
  read -p "" cd_to_dir
  if [[ "$cd_to_dir" =~ ^[Yy]$ ]]; then
    cd_command="cd \"$install_dir\""
    echo -e "${GREEN}Выполните следующую команду для перехода в директорию:${NC}"
    echo -e "${BLUE}$cd_command${NC}"
    
    # Для bash/zsh, которые поддерживают PROMPT_COMMAND
    export LAST_DIR="$install_dir"
    echo -e "${GREEN}Или просто закройте этот терминал и откройте новый в директории установки.${NC}"
  fi
fi