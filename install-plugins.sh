#!/bin/bash
source .env

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       WordPress Plugin Installation         ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Проверка доступности WordPress
if ! docker-compose exec -T wordpress wp --allow-root core is-installed > /dev/null 2>&1; then
    echo -e "${RED}WordPress не установлен или контейнер не запущен!${NC}"
    echo -e "${YELLOW}Убедитесь, что WordPress контейнер работает.${NC}"
    exit 1
fi

# Меню выбора категории плагинов
while true; do
    echo -e "\n${BLUE}Выберите категорию плагинов для установки:${NC}"
    echo "1. Безопасность"
    echo "2. SEO и маркетинг"
    echo "3. Производительность"
    echo "4. Контент и редакторы"
    echo "5. Электронная коммерция (WooCommerce)"
    echo "6. Установить список плагинов из файла"
    echo "7. Установить одиночный плагин"
    echo "8. Вернуться в главное меню"
    
    read -p "Ваш выбор: " category
    
    case $category in
        1)
            echo -e "${YELLOW}Установка плагинов безопасности...${NC}"
            docker-compose exec -T wordpress wp plugin install \
                wordfence \
                limit-login-attempts-reloaded \
                wp-security-audit-log \
                two-factor \
                google-authenticator \
                force-strong-passwords \
                --activate --allow-root
            echo -e "${GREEN}Плагины безопасности установлены!${NC}"
            ;;
        2)
            echo -e "${YELLOW}Установка SEO и маркетинговых плагинов...${NC}"
            docker-compose exec -T wordpress wp plugin install \
                wordpress-seo \
                google-analytics-for-wordpress \
                mailchimp-for-wp \
                wp-mail-smtp \
                cookie-notice \
                --activate --allow-root
            echo -e "${GREEN}SEO и маркетинговые плагины установлены!${NC}"
            ;;
        3)
            echo -e "${YELLOW}Установка плагинов производительности...${NC}"
            docker-compose exec -T wordpress wp plugin install \
                redis-cache \
                wp-super-cache \
                wp-rocket \
                litespeed-cache \
                autoptimize \
                flying-scripts \
                --activate --allow-root
            echo -e "${GREEN}Плагины производительности установлены!${NC}"
            ;;
        4)
            echo -e "${YELLOW}Установка плагинов для работы с контентом...${NC}"
            docker-compose exec -T wordpress wp plugin install \
                advanced-custom-fields \
                classic-editor \
                contact-form-7 \
                duplicate-post \
                elementor \
                wp-file-manager \
                --activate --allow-root
            echo -e "${GREEN}Плагины для работы с контентом установлены!${NC}"
            ;;
        5)
            echo -e "${YELLOW}Установка WooCommerce и расширений...${NC}"
            docker-compose exec -T wordpress wp plugin install \
                woocommerce \
                woocommerce-gateway-stripe \
                woocommerce-gateway-paypal-express-checkout \
                mailchimp-for-woocommerce \
                woo-gutenberg-products-block \
                variation-swatches-for-woocommerce \
                --activate --allow-root
            echo -e "${GREEN}WooCommerce и расширения установлены!${NC}"
            ;;
        6)
            read -p "Введите путь к файлу со списком плагинов: " plugins_file
            if [ -f "$plugins_file" ]; then
                echo -e "${YELLOW}Установка плагинов из файла...${NC}"
                plugins_list=$(cat "$plugins_file" | tr '\n' ' ')
                docker-compose exec -T wordpress wp plugin install $plugins_list --activate --allow-root
                echo -e "${GREEN}Плагины из файла установлены!${NC}"
            else
                echo -e "${RED}Файл не найден!${NC}"
            fi
            ;;
        7)
            read -p "Введите слаг плагина для установки: " plugin_slug
            echo -e "${YELLOW}Установка плагина $plugin_slug...${NC}"
            docker-compose exec -T wordpress wp plugin install $plugin_slug --activate --allow-root
            ;;
        8)
            echo -e "${GREEN}Возврат в главное меню...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}"
            ;;
    esac
done
