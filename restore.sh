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

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide the backup file path${NC}"
    echo -e "Usage: ./restore.sh backups/example.com-YYYYMMDD-HHMMSS-full.tar.gz"
    exit 1
fi

BACKUP_FILE=$1
BACKUP_DIR="restore_temp"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Starting WordPress restoration from backup: $BACKUP_FILE${NC}"

# Create temporary directory
echo -e "${YELLOW}Creating temporary directory...${NC}"
mkdir -p $BACKUP_DIR

# Extract backup archive
echo -e "${YELLOW}Extracting backup files...${NC}"
tar -xzf $BACKUP_FILE -C $BACKUP_DIR

# Check if needed files exist
DB_BACKUP=$(find $BACKUP_DIR -name "*-db.sql.gz" | head -1)
FILES_BACKUP=$(find $BACKUP_DIR -name "*-files.tar.gz" | head -1)

if [ -z "$DB_BACKUP" ] || [ -z "$FILES_BACKUP" ]; then
    echo -e "${RED}Error: Could not find required backup files in archive${NC}"
    echo -e "${RED}Database backup: $DB_BACKUP${NC}"
    echo -e "${RED}Files backup: $FILES_BACKUP${NC}"
    rm -rf $BACKUP_DIR
    exit 1
fi

# Stop the containers
echo -e "${YELLOW}Stopping WordPress containers...${NC}"
docker-compose down

# Restore WordPress files
echo -e "${YELLOW}Restoring WordPress files...${NC}"
docker run --rm -v wordpress_data:/var/www/html -v $(pwd)/$FILES_BACKUP:/backup.tar.gz alpine sh -c "rm -rf /var/www/html/* && tar -xzf /backup.tar.gz -C /var/www/html"

# Start database container only
echo -e "${YELLOW}Starting database container...${NC}"
docker-compose up -d db
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 10

# Restore database
echo -e "${YELLOW}Restoring WordPress database...${NC}"
gunzip < $DB_BACKUP | docker-compose exec -T db mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE

# Start all containers
echo -e "${YELLOW}Starting all containers...${NC}"
docker-compose up -d

# Cleanup
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf $BACKUP_DIR

echo -e "${GREEN}Restoration completed successfully!${NC}"
echo -e "${YELLOW}Your WordPress site has been restored to: https://${DOMAIN_NAME}${NC}"
echo -e "${YELLOW}If you encounter any issues, check the logs with: docker-compose logs${NC}"
