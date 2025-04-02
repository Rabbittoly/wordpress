#!/bin/bash
source .env

# Директория для бэкапов
BACKUP_DIR="./backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/wordpress_backup_$DATE.tar.gz"

# Создаем директорию для бэкапов, если её нет
mkdir -p $BACKUP_DIR

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Создание резервной копии WordPress...${NC}"
echo -e "${YELLOW}Дата: $(date)${NC}"

# Проверка доступности контейнеров
if ! docker-compose ps | grep -q "wordpress.*Up"; then
    echo -e "${RED}Ошибка: WordPress контейнер не запущен!${NC}"
    exit 1
fi

echo "Создание резервной копии базы данных..."
docker-compose exec -T db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} > $BACKUP_DIR/db_backup_$DATE.sql

# Проверка успешности дампа базы
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании дампа базы данных!${NC}"
    rm -f $BACKUP_DIR/db_backup_$DATE.sql
    exit 1
fi

echo "Архивирование файлов WordPress..."
tar -czf $BACKUP_FILE wp-content $BACKUP_DIR/db_backup_$DATE.sql

# Проверка успешности создания архива
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании архива!${NC}"
    rm -f $BACKUP_DIR/db_backup_$DATE.sql
    exit 1
fi

# Удаляем временный дамп базы
rm $BACKUP_DIR/db_backup_$DATE.sql

# Получение размера файла резервной копии
backup_size=$(du -h $BACKUP_FILE | cut -f1)

echo -e "${GREEN}Резервная копия успешно создана: $BACKUP_FILE (размер: $backup_size)${NC}"

# Удаление старых резервных копий (оставляем последние 5)
echo "Управление старыми резервными копиями..."
backup_count=$(ls -1 $BACKUP_DIR/wordpress_backup_*.tar.gz 2>/dev/null | wc -l)

if [ $backup_count -gt 5 ]; then
    echo "Удаление старых резервных копий (сохраняются только последние 5)..."
    ls -t $BACKUP_DIR/wordpress_backup_*.tar.gz | tail -n +6 | xargs -r rm -f
    echo -e "${GREEN}Старые резервные копии удалены.${NC}"
else
    echo -e "${GREEN}Всего резервных копий: $backup_count (не более 5, удаление не требуется).${NC}"
fi

# Информация о свободном месте на диске
disk_free=$(df -h . | awk 'NR==2 {print $4}')
echo -e "${YELLOW}Свободное место на диске: $disk_free${NC}"

echo -e "${GREEN}Процесс резервного копирования завершен успешно!${NC}"
