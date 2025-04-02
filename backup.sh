#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Create backup directory
BACKUP_DIR="backups"
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_NAME="${DOMAIN_NAME//[^a-zA-Z0-9]/_}-$TIMESTAMP"

echo -e "${GREEN}Starting WordPress backup: $BACKUP_NAME${NC}"

# Backup WordPress files
echo -e "${YELLOW}Backing up WordPress files...${NC}"
docker run --rm --volumes-from wordpress -v $(pwd)/$BACKUP_DIR:/backup alpine sh -c "cd /var/www/html && tar czf /backup/$BACKUP_NAME-files.tar.gz ."

# Backup WordPress database
echo -e "${YELLOW}Backing up WordPress database...${NC}"
docker-compose exec db sh -c "mysqldump -u $MYSQL_USER -p'$MYSQL_PASSWORD' $MYSQL_DATABASE | gzip > /tmp/$BACKUP_NAME-db.sql.gz"
docker cp wordpress-db:/tmp/$BACKUP_NAME-db.sql.gz $BACKUP_DIR/
docker-compose exec db sh -c "rm /tmp/$BACKUP_NAME-db.sql.gz"

# Create a combined backup
echo -e "${YELLOW}Creating combined backup archive...${NC}"
tar czf $BACKUP_DIR/$BACKUP_NAME-full.tar.gz $BACKUP_DIR/$BACKUP_NAME-files.tar.gz $BACKUP_DIR/$BACKUP_NAME-db.sql.gz

# Cleanup individual backup files (optional)
# rm $BACKUP_DIR/$BACKUP_NAME-files.tar.gz $BACKUP_DIR/$BACKUP_NAME-db.sql.gz

# Set proper permissions
chmod 600 $BACKUP_DIR/$BACKUP_NAME-full.tar.gz

echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${YELLOW}Backup location: $BACKUP_DIR/$BACKUP_NAME-full.tar.gz${NC}"

# Optional: Upload to external storage
echo -e "${YELLOW}Would you like to upload the backup to an external server via SCP? (y/n)${NC}"
read -r upload_backup
if [[ "$upload_backup" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Enter the remote server username:${NC}"
    read -r remote_user
    echo -e "${YELLOW}Enter the remote server address:${NC}"
    read -r remote_server
    echo -e "${YELLOW}Enter the remote backup path:${NC}"
    read -r remote_path
    
    echo -e "${YELLOW}Uploading backup to ${remote_user}@${remote_server}:${remote_path}...${NC}"
    scp $BACKUP_DIR/$BACKUP_NAME-full.tar.gz ${remote_user}@${remote_server}:${remote_path}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup uploaded successfully!${NC}"
    else
        echo -e "${RED}Backup upload failed.${NC}"
    fi
fi

# Cleanup old backups
echo -e "${YELLOW}Would you like to clean up backups older than 30 days? (y/n)${NC}"
read -r cleanup_backups
if [[ "$cleanup_backups" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleaning up old backups...${NC}"
    find $BACKUP_DIR -name "*.tar.gz" -type f -mtime +30 -delete
    echo -e "${GREEN}Old backups cleaned up!${NC}"
fi

echo -e "${GREEN}Backup process completed!${NC}"
