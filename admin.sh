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
    echo "10. Установить дополнительные плагины"
    echo "11. Выход"
    
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
                    ./optimize.sh
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
            echo -e "${YELLOW}Установка дополнительных плагинов...${NC}"
            ./install-plugins.sh
            ;;
        11)
            echo -e "${GREEN}До свидания!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}"
            ;;
    esac
done
