#!/bin/bash

# Simple WordPress Docker Template Installation Script
# Repository: https://github.com/Rabbittoly/wordpress

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}    WordPress Docker Template Installer      ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed successfully!${NC}"
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose installed successfully!${NC}"
fi

# Get installation directory
read -p "Enter installation directory name (default: wordpress): " install_dir
install_dir=${install_dir:-wordpress}

if [ -d "$install_dir" ]; then
    echo -e "${RED}Directory $install_dir already exists. Please choose another name or remove the existing directory.${NC}"
    exit 1
fi

# Clone the repository
echo -e "${GREEN}Cloning WordPress template repository...${NC}"
git clone https://github.com/Rabbittoly/wordpress.git "$install_dir"
cd "$install_dir"

# Create .env file with user input
echo -e "${YELLOW}Setting up your WordPress site...${NC}"
read -p "Enter your domain name (e.g., example.com): " domain_name
read -p "Enter your email for Let's Encrypt SSL certificates: " acme_email

# Generate strong passwords
mysql_root_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
mysql_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
redis_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

# Create .env file
echo -e "${GREEN}Creating .env file...${NC}"
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
TZ=UTC
EOL

# Create necessary directories
mkdir -p letsencrypt nginx/logs backups

# Make scripts executable
chmod +x deploy.sh backup.sh restore.sh

# Display configuration summary
echo -e "${GREEN}Configuration summary:${NC}"
echo "Domain: $domain_name"
echo "Installation Directory: $(pwd)"
echo ""
echo -e "${YELLOW}Passwords have been saved in the .env file:${NC}"
echo "MySQL Root Password: $mysql_root_password"
echo "WordPress Database Password: $mysql_password"
echo "Redis Password: $redis_password"
echo ""

# Backup credentials to a file
echo "WordPress Setup Credentials" > wordpress_credentials.txt
echo "Domain: $domain_name" >> wordpress_credentials.txt
echo "MySQL Root Password: $mysql_root_password" >> wordpress_credentials.txt
echo "MySQL Password: $mysql_password" >> wordpress_credentials.txt
echo "Redis Password: $redis_password" >> wordpress_credentials.txt
echo -e "${YELLOW}Credentials backed up to: wordpress_credentials.txt${NC}"

# Start deployment
echo -e "${GREEN}Starting deployment...${NC}"
./deploy.sh

echo -e "${GREEN}Installation completed!${NC}"
echo -e "Your WordPress site should now be available at: https://$domain_name"
