# WordPress Docker Deployment

This repository contains everything you need to deploy WordPress with Docker, Nginx, Traefik for SSL, and Cloudflare integration on a VPS. You can use this as a template for client sites with quick and easy installation.

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
- ⚡ One-command installation for quick deployment

## Prerequisites

- A VPS with SSH access
- A domain name pointing to your server's IP address
- Cloudflare account (optional, but recommended)

## One-Command Installation

The fastest way to deploy this WordPress template is using our installer:

```bash
# Download the installer
curl -s https://raw.githubusercontent.com/Rabbittoly/wordpress/main/install.sh -o wp-install.sh
chmod +x wp-install.sh
./wp-install.sh
```

Or with wget:

```bash
wget -q https://raw.githubusercontent.com/Rabbittoly/wordpress/main/install.sh -O wp-install.sh
chmod +x wp-install.sh
./wp-install.sh
```

The installer will:
- Install Docker and Docker Compose if needed
- Clone this repository
- Guide you through basic configuration
- Generate secure passwords
- Set up your WordPress installation
- Deploy everything automatically

## Manual Installation

If you prefer a manual approach:

1. Clone this repository:
   ```bash
   git clone https://github.com/Rabbittoly/wordpress.git
   cd wordpress
   ```

2. Configure your settings in the `.env` file:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Update with your domain, email, and preferred passwords.

3. Run the deployment script:
   ```bash
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
```bash
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
   ```bash
   docker-compose down
   ```

2. Extract the backup:
   ```bash
   tar -xzf backups/example.com-YYYYMMDD-HHMMSS-full.tar.gz
   ```

3. Restore the files:
   ```bash
   docker run --rm -v wordpress_wordpress_data:/var/www/html -v $(pwd)/backups:/backup alpine sh -c "cd /var/www/html && rm -rf * && tar xzf /backup/example.com-YYYYMMDD-HHMMSS-files.tar.gz ."
   ```

4. Restore the database:
   ```bash
   # Load environment variables
   source .env
   # Restore database
   gunzip < backups/example.com-YYYYMMDD-HHMMSS-db.sql.gz | docker-compose exec -T db mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
   ```

5. Restart the containers:
   ```bash
   docker-compose up -d
   ```

## Maintenance

### Updating WordPress

WordPress core, themes, and plugins should be updated through the WordPress admin interface.

### Updating Containers

To update the containers to the latest versions:

```bash
docker-compose down
docker-compose pull
docker-compose up -d
```

### Viewing Logs

```bash
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
## Server Installation

To install on a specific server with SSH access:

1. Connect to your server:
   ```bash
   ssh user@your-server-ip
   ```

2. Download and run the installer:
   ```bash
   curl -s https://raw.githubusercontent.com/Rabbittoly/wordpress/main/install.sh -o wp-install.sh
   chmod +x wp-install.sh
   ./wp-install.sh
   ```
   
   Alternatively, you can clone the repository:
   ```bash
   git clone --depth 1 https://github.com/Rabbittoly/wordpress.git
   cd wordpress
   ./install.sh
   ```

3. Choose your installation directory:
   - Install in the current directory
   - Create a subdirectory in the current location
   - Specify a custom path for installation

4. Follow the on-screen prompts to configure your WordPress site.

## Using as a Template

This repository is designed to be used as a template for client WordPress installations:

1. Share the one-command installer with your client
2. Let them run it on their server
3. The installation script will guide them through the process
4. All necessary components will be installed and configured automatically

When deployed, it provides a complete WordPress hosting environment with:
- WordPress with PHP 8.2
- NGINX as a reverse proxy
- MariaDB as the database
- Redis for object caching
- Automatic SSL with Let's Encrypt
- Traefik for handling routing and SSL
- Cloudflare DNS integration (optional)

## Configuration Files

- `.env` - Environment variables (domain, passwords, etc.)
- `docker-compose.yml` - Docker services configuration
- `nginx/default.conf` - NGINX configuration
- `config/uploads.ini` - PHP configuration
- `mysql/my.cnf` - MySQL/MariaDB configuration

## Maintenance Scripts

- `deploy.sh` - Deploy or update the WordPress installation
- `backup.sh` - Create a backup of WordPress files and database
- `restore.sh` - Restore from a backup
- `install.sh` - One-command installer for new deployments
- `wp-files.sh` - Quick access to WordPress files via shell
- `monitor.sh` - Monitoring and auto-recovery script

## File Management

This deployment offers two methods to manage WordPress files:

### 1. WP File Manager (Graphical Interface)
After installation, a File Manager plugin is automatically installed and configured in WordPress:
- Access it via WordPress admin panel: https://your-domain.com/wp-admin → WP File Manager
- Allows secure file operations directly from the browser
- Perfect for clients with limited technical knowledge

### 2. Shell Access (Command Line)
For more advanced users or when admin panel is not accessible:
- Run: `./wp-files.sh` to access WordPress files via command line
- Navigate to `/var/www/html` to work with WordPress files
- Type `exit` when done

