# WordPress LEMP Stack - Intelligent Build Script

An intelligent, automated WordPress hosting solution for Ubuntu servers with LEMP stack (Linux, Nginx, MariaDB, PHP-FPM) and Redis object caching. This script automatically detects system resources and optimizes configurations accordingly.

## Features

- **Intelligent Resource Detection**: Automatically detects CPU, RAM, and disk space
- **Optimized Configuration**: Generates PHP, MySQL, Nginx, and Redis configurations based on available resources
- **Multiple WordPress Sites**: Support for hosting multiple WordPress sites on one server
- **SSL/TLS Automation**: Automatic SSL certificate installation with Let's Encrypt
- **Redis Object Cache**: Built-in Redis support for WordPress object caching
- **Automated Backups**: Scheduled daily backups with configurable retention
- **Security Hardening**: Firewall configuration, MySQL security, and WordPress hardening
- **Interactive Menu**: User-friendly menu system for server management
- **Performance Monitoring**: Built-in monitoring tools for system resources
- **Performance Settings Viewer**: View all current PHP, MySQL, Nginx, and Redis configurations with detailed reports

## Requirements

- **Operating System**: Ubuntu 20.04 LTS, 22.04 LTS, or 24.04 LTS
- **RAM**: Minimum 512MB (1GB+ recommended)
- **Disk Space**: Minimum 10GB free
- **Root Access**: Must be run as root or with sudo

## Quick Start

### 1. Clone or Download

```bash
git clone <repository-url> wpserver
cd wpserver
```

### 2. Run Installation

```bash
sudo ./build.sh --install
```

This will:
- Detect your system resources
- Install LEMP stack components (only what's needed)
- Configure services with optimized settings
- Set up security (firewall, MySQL)
- Configure automated backups
- Offer to create your first WordPress site

### 3. Add Your First WordPress Site

During installation, you'll be prompted to add your first site. You can also add sites later:

```bash
sudo ./build.sh --add-site example.com
```

### 4. Install SSL Certificate

```bash
# Interactive menu
sudo ./build.sh --menu
# Select option 3 → Manage Existing Site → Install SSL

# Or directly:
sudo ./build.sh --add-site example.com
# (SSL installation will be offered during site creation)
```

## Usage

### Command Line Interface

```bash
# Show help
./build.sh --help

# Run full installation
sudo ./build.sh --install

# Launch interactive menu
sudo ./build.sh --menu

# Add new WordPress site
sudo ./build.sh --add-site example.com

# List all sites
./build.sh --list-sites

# Backup all sites
sudo ./build.sh --backup-all

# Show system status
./build.sh --system-status

# View all performance settings
sudo ./build.sh --performance

# Show version
./build.sh --version
```

### Interactive Menu

Launch the menu system:

```bash
sudo ./build.sh --menu
# Or simply:
sudo ./build.sh
```

Menu Options:
1. **Install New WordPress Site** - Create a new WordPress installation
2. **List All WordPress Sites** - View all registered sites
3. **Manage Existing Site** - SSL, backups, removal
4. **System Status & Monitoring** - View resources and service status
5. **Backup Management** - Manual backups, backup list
6. **Performance Tuning** - View all settings, PHP/MySQL/Nginx/Redis configs, clear caches
7. **Security Management** - Firewall, SSL certificates
8. **Exit** - Exit menu system

#### Performance Tuning Submenu:
1. **Show All Performance Settings** - Complete overview of all configurations
2. **Show PHP Configuration** - PHP.ini, FPM pool settings, loaded modules
3. **Show MySQL Configuration** - InnoDB settings, connections, runtime values
4. **Show Nginx Configuration** - Workers, cache, compression, enabled sites
5. **Show Redis Configuration** - Memory settings, persistence, runtime stats
6. **Recalculate Resources** - Re-detect system resources and show allocations
7. **Clear All Caches** - Clear Redis and Nginx FastCGI caches
8. **Save Configuration Report** - Generate timestamped performance report
9. **Back to Main Menu**

## Installation Process

The installation follows these phases:

### Phase 1: Pre-flight Checks
- Verify root privileges
- Check internet connectivity
- Detect operating system (Ubuntu version)
- Verify disk space (minimum 10GB)
- Create directory structure

### Phase 2: System Resource Detection
- Detect CPU cores (for Nginx workers, PHP-FPM processes)
- Detect total RAM (for memory allocation)
- Detect available disk space
- Calculate optimal configuration values

### Phase 3: Software Detection
- Check for existing Nginx installation
- Check for MariaDB/MySQL
- Check for PHP and version
- Check for Redis
- Check for Certbot
- Display what will be installed/configured

### Phase 4: Package Installation
- Update package lists
- Add required repositories (Ondrej PHP PPA, MariaDB repo)
- Install only missing components:
  - Nginx web server
  - MariaDB database server
  - PHP-FPM and extensions (mysql, curl, gd, mbstring, xml, redis, imagick, opcache, etc.)
  - Redis server
  - Certbot (Let's Encrypt)
  - WP-CLI (WordPress command-line interface)
  - Monitoring tools (htop, iotop)

### Phase 5: Service Configuration
- Generate optimized Nginx configuration
- Generate PHP.ini with calculated memory limits
- Generate PHP-FPM pool with calculated process settings
- Generate MariaDB configuration with InnoDB buffer pool sizing
- Generate Redis configuration with maxmemory settings
- Apply and test all configurations

### Phase 6: Security Hardening
- MySQL secure installation (automated)
- Configure UFW firewall (allow SSH, HTTP, HTTPS)
- Set secure file permissions
- Disable dangerous PHP functions
- Generate strong random passwords

### Phase 7: Setup Automation
- Configure automated daily backups (2 AM)
- Setup SSL certificate auto-renewal
- Create monitoring scripts

## Resource Allocation

The script intelligently allocates resources based on available RAM:

### 1GB RAM Server
- InnoDB Buffer Pool: 400MB
- PHP Max Children: 10
- Redis Memory: 128MB
- PHP Memory Limit: 256MB

### 2GB RAM Server
- InnoDB Buffer Pool: 800MB
- PHP Max Children: 20
- Redis Memory: 128MB
- PHP Memory Limit: 256MB

### 4GB RAM Server
- InnoDB Buffer Pool: 1800MB
- PHP Max Children: 30
- Redis Memory: 256MB
- PHP Memory Limit: 384MB

### 8GB+ RAM Server
- InnoDB Buffer Pool: 45% of total RAM
- PHP Max Children: 60+
- Redis Memory: 512MB+
- PHP Memory Limit: 512MB

### CPU-Based Settings
- Nginx Workers: Equal to CPU cores
- PHP-FPM Start Servers: CPU cores × 2
- PHP-FPM Min Spare: CPU cores × 1
- PHP-FPM Max Spare: CPU cores × 3

## Viewing Performance Settings

After installation, you can view and review all current performance configurations:

### Command Line
```bash
# View all performance settings at once
sudo ./build.sh --performance

# Or use the alias
sudo ./build.sh --show-settings
```

### Via Interactive Menu
```bash
sudo ./build.sh --menu
# Select option 6: Performance Tuning
```

### What You Can View

1. **Complete Overview** - All system resources, calculated allocations, and service status
2. **PHP Settings** - Memory limits, upload sizes, execution times, OPcache, FPM pool configuration, loaded modules
3. **MySQL/MariaDB Settings** - InnoDB buffer pool, log file sizes, max connections, query cache, runtime values
4. **Nginx Settings** - Worker processes, FastCGI cache, gzip compression, client limits, enabled sites
5. **Redis Settings** - Memory limits, eviction policy, persistence status, current memory usage

### Performance Reports

Generate a detailed timestamped report of all configurations:

```bash
sudo ./build.sh --performance
# Then select option 8: Save Configuration Report
```

Reports are saved to `/opt/wpserver/logs/performance-report-YYYYMMDD_HHMMSS.txt` and include:
- System resources (CPU, RAM, disk)
- All calculated resource allocations
- Complete PHP configuration with file paths
- MySQL/MariaDB settings with runtime values
- Nginx configuration details
- Redis configuration and statistics
- Service status for all components

These reports are useful for:
- Documenting server configuration
- Troubleshooting performance issues
- Planning server upgrades
- Comparing configurations across servers
- Compliance and audit requirements

## Directory Structure

```
/opt/wpserver/              # Installation directory
├── build.sh                # Main script
├── lib/                    # Function libraries
│   ├── core.sh            # Logging, utilities
│   ├── detection.sh       # System detection
│   ├── install.sh         # Package installation
│   ├── config.sh          # Configuration generation
│   ├── wordpress.sh       # WordPress management
│   ├── ssl.sh             # SSL certificates
│   ├── security.sh        # Security hardening
│   ├── backup.sh          # Backup operations
│   └── menu.sh            # Interactive menu
├── scripts/
│   ├── daily-backup.sh    # Automated backup script
│   └── monitor.sh         # System monitoring
├── config/
│   └── wpserver.conf      # Sites registry
├── logs/
│   ├── install.log        # Installation log
│   ├── error.log          # Error log
│   └── backup.log         # Backup log
└── backups/               # Backup storage
    ├── databases/
    └── files/

/var/www/                  # WordPress sites
├── example.com/
│   ├── public_html/       # WordPress files
│   ├── logs/              # Site-specific logs
│   └── ssl/               # SSL certificates
```

## Configuration Files

### Generated Configurations

After installation, the script generates optimized configurations:

- **Nginx Main**: `/etc/nginx/nginx.conf`
- **Nginx Sites**: `/etc/nginx/sites-available/{domain}`
- **PHP.ini**: `/etc/php/{version}/fpm/php.ini`
- **PHP-FPM Pool**: `/etc/php/{version}/fpm/pool.d/www.conf`
- **MariaDB**: `/etc/mysql/mariadb.conf.d/99-custom.cnf`
- **Redis**: `/etc/redis/redis.conf`

### Credentials Storage

All passwords and credentials are stored securely:

- **Location**: `/root/.wpserver-credentials`
- **Permissions**: 600 (read/write for root only)
- **Contains**: Database passwords, MariaDB root password, WordPress admin passwords

## WordPress Site Management

### Adding a New Site

```bash
sudo ./build.sh --add-site example.com
```

This will:
1. Create directory structure (`/var/www/example.com/`)
2. Create database and user with random secure passwords
3. Download latest WordPress
4. Generate `wp-config.php` with Redis support
5. Create Nginx server block configuration
6. Set secure file permissions
7. Offer SSL installation
8. Display credentials

### Managing Existing Sites

Use the interactive menu:

```bash
sudo ./build.sh --menu
# Select option 3: Manage Existing Site
```

Or use command-line options to:
- Install SSL certificate
- Create backup
- Remove site (with confirmation)

### WordPress with Redis

All WordPress sites are automatically configured for Redis object caching:

```php
// Auto-added to wp-config.php
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```

To activate, install the "Redis Object Cache" plugin from WordPress admin.

## SSL/TLS Certificates

### Automatic SSL with Let's Encrypt

```bash
# During site creation, you'll be offered SSL installation
# Or install later:
sudo ./build.sh --menu
# Option 3 → Manage Existing Site → Install SSL Certificate
```

### What Happens:
1. Certbot requests certificate from Let's Encrypt
2. Nginx configuration is updated for HTTPS
3. HTTP→HTTPS redirect is configured
4. Auto-renewal is set up (certificates renew automatically)

### Manual SSL Renewal

```bash
sudo certbot renew
```

Automatic renewal runs via systemd timer (twice daily).

## Backups

### Automated Daily Backups

Backups run automatically at 2 AM daily via cron. Each backup includes:
- Database dump (compressed)
- WordPress files (wp-content directory)
- Nginx configuration
- Backup manifest

**Retention**: 7 days (configurable in `lib/backup.sh`)

### Manual Backups

```bash
# Backup all sites
sudo ./build.sh --backup-all

# Backup via menu
sudo ./build.sh --menu
# Option 5: Backup Management
```

### Backup Location

```
/opt/wpserver/backups/{timestamp}_{domain}/
├── database.sql.gz
├── files.tar.gz
├── nginx.conf
└── manifest.txt
```

## Monitoring

### System Monitor Script

```bash
sudo /opt/wpserver/scripts/monitor.sh
```

Shows:
- System resources (CPU, RAM, disk usage)
- Service status (Nginx, MariaDB, PHP-FPM, Redis)
- Connection tests
- WordPress site count

### Service Status

```bash
# Check individual services
systemctl status nginx
systemctl status mariadb
systemctl status php8.2-fpm  # or your PHP version
systemctl status redis-server

# View logs
tail -f /var/log/nginx/error.log
tail -f /opt/wpserver/logs/error.log
```

## Security

### Security Features

1. **Firewall (UFW)**
   - Default deny incoming
   - Allow SSH (22), HTTP (80), HTTPS (443)

2. **MariaDB Security**
   - Random strong root password
   - Remove anonymous users
   - Disable remote root login
   - Remove test database

3. **WordPress Hardening**
   - Disable file editing via admin
   - Force SSL for admin area
   - Secure file permissions (755/644)
   - wp-config.php with 440 permissions

4. **PHP Security**
   - Disabled dangerous functions
   - OPcache enabled for performance
   - Exposed PHP version hidden

5. **Nginx Security Headers**
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection
   - Referrer-Policy

### Firewall Management

```bash
# View firewall status
sudo ufw status verbose

# Add custom rule
sudo ufw allow from 192.168.1.0/24 to any port 3306
```

## Performance Optimization

### FastCGI Caching

All WordPress sites are configured with Nginx FastCGI caching:
- Cache path: `/var/cache/nginx`
- Cache size: 100MB
- Inactive time: 60 minutes
- Automatic cache bypass for admin pages and logged-in users

### PHP OPcache

Enabled by default with optimized settings:
- Memory: 128MB
- Interned strings buffer: 16MB
- Max accelerated files: 10,000

### Redis Object Cache

Redis is configured for WordPress object caching:
- Memory limit: Based on server RAM
- Eviction policy: allkeys-lru
- Persistence: Disabled (for caching only)

### Clear All Caches

```bash
# Via menu
sudo ./build.sh --menu
# Option 6: Performance Tuning → Clear All Caches

# Or manually
sudo redis-cli FLUSHALL
sudo rm -rf /var/cache/nginx/*
sudo systemctl reload nginx
```

## Troubleshooting

### Installation Issues

**Problem**: Package installation fails
```bash
# Solution: Update package lists
sudo apt-get update
sudo apt-get upgrade
```

**Problem**: Service won't start
```bash
# Check status and logs
sudo systemctl status nginx
sudo journalctl -u nginx -n 50

# Test configuration
sudo nginx -t
sudo php-fpm8.2 -t
```

### WordPress Issues

**Problem**: White screen / 500 error
```bash
# Check PHP error log
sudo tail -f /var/log/php8.2-fpm.log

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log

# Check site-specific logs
sudo tail -f /var/www/example.com/logs/error.log
```

**Problem**: Database connection error
```bash
# Verify MariaDB is running
sudo systemctl status mariadb

# Test database connection
mysql -u wp_username -p wp_database
```

### SSL Issues

**Problem**: SSL certificate installation fails
```bash
# Check domain DNS
dig example.com

# Verify Nginx configuration
sudo nginx -t

# Check Certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## Advanced Usage

### Custom PHP Version

To use a different PHP version, modify `PHP_MAJOR_VERSION` in `lib/detection.sh` before installation.

### Custom Resource Allocation

Edit the `calculate_resources()` function in `lib/detection.sh` to adjust allocation formulas.

### Additional WordPress Sites

No limit on the number of sites. Resources are shared based on initial server capacity calculation.

## Logs

All operations are logged:

- **Installation Log**: `/opt/wpserver/logs/install.log`
- **Error Log**: `/opt/wpserver/logs/error.log`
- **Backup Log**: `/opt/wpserver/logs/backup.log`
- **Nginx Access**: `/var/www/{domain}/logs/access.log`
- **Nginx Error**: `/var/www/{domain}/logs/error.log`

## Uninstallation

To completely remove the WordPress LEMP server:

```bash
# Remove all WordPress sites
sudo rm -rf /var/www/*

# Remove LEMP stack (if desired)
sudo apt-get remove --purge nginx mariadb-server php8.2-fpm redis-server

# Remove wpserver directory
sudo rm -rf /opt/wpserver
sudo rm -f /usr/local/bin/wpserver
```

## Support

For issues, questions, or contributions, please check:
- Installation logs: `/opt/wpserver/logs/install.log`
- Error logs: `/opt/wpserver/logs/error.log`
- System monitor: `/opt/wpserver/scripts/monitor.sh`

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please submit pull requests or open issues on the repository.

## Version

Current Version: 1.0.0
