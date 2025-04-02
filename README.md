# WordPress Docker Deployment

This repository contains everything you need to deploy WordPress with Docker, Nginx, Traefik for SSL, and Cloudflare integration on a VPS.

## Features

- 🐳 Docker and Docker Compose deployment
- 🔒 Automatic SSL certificate management with Let's Encrypt
- 🚀 NGINX as reverse proxy for optimal performance
- ☁️ Cloudflare DNS integration
- 🔄 Automatic container restart on failure or system reboot
- 📊 MariaDB for database storage
- 🗄️ Redis for object caching
- 🔧 Optimized configurations for WordPress, PHP, NGINX, and MariaDB
- 💾 Simple backup and restore functionality

## Prerequisites

- A VPS with Docker and Docker Compose installed
- A domain name pointing to your server's IP address
- Cloudflare account (optional, but recommended)

## Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/Rabbittoly/wordpress.git
   cd wordpress
   ```

2. Configure your settings in the `.env` file:
   ```
   cp .env.example .env
   nano .env
   ```
   Update with your domain, email, and preferred passwords.

3. Run the deployment script:
   ```
   chmod +x deploy.sh
   ./deploy.sh
   ```

4. The script will:
   - Install Docker and Docker Compose if needed
   - Create required directories
   - Set up Cloudflare DNS if requested
   - Start the containers
   - Set up Let's Encrypt SSL

5. Access your WordPress site at `https://yourdomain.com`

## Structure

```
├── docker-compose.yml       # Main Docker Compose configuration
├── .env                     # Environment variables
├── deploy.sh                # Deployment script
├── backup.sh                # Backup script
├── nginx/                   # NGINX configuration
│   ├── default.conf         # Site configuration
│   └── nginx.conf           # Main NGINX configuration
├── config/
│   └── uploads.ini          # PHP configuration
├── mysql/
│   └── my.cnf               # MySQL/MariaDB configuration
└── letsencrypt/             # Let's Encrypt data
```

## Containers

- **Traefik**: Handles SSL certificates and acts as entry point
- **WordPress**: WordPress with PHP-FPM
- **NGINX**: Web server as reverse proxy
- **MariaDB**: Database server
- **Redis**: Object cache server

## Configuration

### SSL Certificates

SSL certificates are automatically managed by Traefik using Let's Encrypt. The certificates will be stored in the `letsencrypt` directory.

### Performance Optimizations

This setup includes performance optimizations for:
- **NGINX**: Gzip compression, caching, buffer settings
- **PHP**: Memory limits, upload sizes, execution times
- **MariaDB**: InnoDB settings, query cache
- **WordPress**: Redis object caching capability

## Backup and Restore

### Creating a Backup

Run the backup script:
```
./backup.sh
```

This will:
- Backup WordPress files
- Backup the database
- Create a combined archive
- Optionally upload to an external server
- Optionally clean up old backups

### Restoring from Backup

To restore from a backup:

1. Stop the containers:
   ```
   docker-compose down
   ```

2. Extract the backup:
   ```
   tar -xzf backups/example.com-YYYYMMDD-HHMMSS-full.tar.gz
   ```

3. Restore the files:
   ```
   docker run --rm -v wordpress_data:/var/www/html -v $(pwd)/backups:/backup alpine sh -c "cd /var/www/html && rm -rf * && tar xzf /backup/example.com-YYYYMMDD-HHMMSS-files.tar.gz ."
   ```

4. Restore the database:
   ```
   gunzip < backups/example.com-YYYYMMDD-HHMMSS-db.sql.gz | docker-compose exec -T db mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE
   ```

5. Restart the containers:
   ```
   docker-compose up -d
   ```

## Maintenance

### Updating WordPress

WordPress core, themes, and plugins should be updated through the WordPress admin interface.

### Updating Containers

To update the containers to the latest versions:

```
docker-compose down
docker-compose pull
docker-compose up -d
```

### Viewing Logs

```
# All containers
docker-compose logs

# Specific container
docker-compose logs wordpress
docker-compose logs nginx
docker-compose logs db
```

## Security Considerations

- All passwords are stored in the `.env` file. Keep this file secure.
- Database data is persisted in Docker volumes.
- WordPress files are persisted in Docker volumes.
- The setup uses HTTPS by default and redirects HTTP to HTTPS.
- Database is not exposed to the public internet.

## Troubleshooting

### SSL Certificate Issues

If the SSL certificate isn't being issued:
- Check that your domain is pointing to the correct IP address
- Ensure port 80 and 443 are open in your firewall
- Check Traefik logs: `docker-compose logs traefik`

### WordPress Not Loading

- Check NGINX logs: `docker-compose logs nginx`
- Check WordPress logs: `docker-compose logs wordpress`
- Verify database connectivity: `docker-compose logs db`

## License

This project is licensed under the MIT License - see the LICENSE file for details.