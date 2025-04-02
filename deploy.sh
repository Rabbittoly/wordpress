#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WordPress Docker Deployment${NC}"
echo "=============================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed successfully!${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose installed successfully!${NC}"
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p letsencrypt nginx/logs mysql config

# Check if the .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file. Please update it with your settings...${NC}"
    cp .env.example .env
    echo -e "${RED}Please update the .env file with your domain and credentials before continuing!${NC}"
    echo -e "Would you like to edit it now? (y/n)"
    read -r edit_env
    if [[ "$edit_env" =~ ^[Yy]$ ]]; then
        ${EDITOR:-vi} .env
    else
        echo -e "${YELLOW}Don't forget to update .env before starting the containers!${NC}"
    fi
else
    echo -e "${GREEN}.env file already exists.${NC}"
fi

# Set proper permissions
echo -e "${YELLOW}Setting proper permissions...${NC}"
chmod +x deploy.sh
chmod +x backup.sh

# Configure Cloudflare
echo -e "${YELLOW}Would you like to configure Cloudflare DNS now? (y/n)${NC}"
read -r configure_cloudflare
if [[ "$configure_cloudflare" =~ ^[Yy]$ ]]; then
    # Source the .env file to get the domain
    source .env
    
    echo -e "${YELLOW}Please enter your Cloudflare email:${NC}"
    read -r cloudflare_email
    
    echo -e "${YELLOW}Please enter your Cloudflare API key:${NC}"
    read -r cloudflare_api_key
    
    # Get the public IP address
    public_ip=$(curl -s https://ipinfo.io/ip)
    
    echo -e "${YELLOW}Setting up DNS record for ${DOMAIN_NAME} pointing to ${public_ip}${NC}"
    
    # Use Cloudflare API to set up DNS record
    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN_NAME}" \
        -H "X-Auth-Email: ${cloudflare_email}" \
        -H "X-Auth-Key: ${cloudflare_api_key}" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)
        
    if [ -z "$zone_id" ]; then
        echo -e "${RED}Could not find zone for domain ${DOMAIN_NAME}. Please set up DNS manually.${NC}"
    else
        echo -e "${GREEN}Found zone ID: ${zone_id}${NC}"
        
        # Create A record
        response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${cloudflare_email}" \
            -H "X-Auth-Key: ${cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${DOMAIN_NAME}\",\"content\":\"${public_ip}\",\"ttl\":1,\"proxied\":true}")
            
        if echo "$response" | grep -q '"success":true'; then
            echo -e "${GREEN}DNS record created successfully!${NC}"
        else
            echo -e "${RED}Failed to create DNS record. Error: ${response}${NC}"
            echo -e "${YELLOW}Please set up DNS manually.${NC}"
        fi
    fi
fi

# Start containers
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker-compose up -d

# Display information
echo -e "\n${GREEN}Deployment Complete!${NC}"
echo -e "${YELLOW}WordPress is now being deployed with NGINX, SSL, and Cloudflare integration.${NC}"
echo -e "${YELLOW}It may take a minute or two for the services to fully start.${NC}"
echo -e "${YELLOW}SSL certificates will be automatically obtained from Let's Encrypt.${NC}"
echo -e "${GREEN}Access your WordPress site at: https://${DOMAIN_NAME}${NC}"
echo -e "${YELLOW}To complete WordPress setup, visit: https://${DOMAIN_NAME}/wp-admin${NC}"
echo -e "${YELLOW}To check logs: docker-compose logs${NC}"
echo -e "${YELLOW}To stop services: docker-compose down${NC}"
echo -e "${YELLOW}To restart services: docker-compose restart${NC}"
echo -e "${YELLOW}To create a backup: ./backup.sh${NC}"
