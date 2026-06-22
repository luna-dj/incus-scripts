#!/usr/bin/env bash
# install/nextcloud-install.sh — Nextcloud installation (runs inside container)

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-install.func)"

header_info "Nextcloud"
setting_up_container
network_check
configure_apt

msg_info "Installing Dependencies"
install_packages apache2 mariadb-server php php-cli php-mysql php-xml php-mbstring php-curl php-gd php-intl php-zip php-bcmath php-gmp php-imagick libapache2-mod-php unzip wget
msg_ok "Dependencies installed"

msg_info "Configuring Database"
systemctl start mariadb
mysql << 'SQL'
CREATE DATABASE IF NOT EXISTS nextcloud DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
SQL
msg_ok "Database configured"

msg_info "Downloading Nextcloud"
NEXTCLOUD_VERSION=$(curl -fsSL https://api.github.com/repos/nextcloud/server/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
wget -q "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.gz" -O /tmp/nextcloud.tar.gz
tar -xzf /tmp/nextcloud.tar.gz -C /var/www/
chown -R www-data:www-data /var/www/nextcloud
rm -f /tmp/nextcloud.tar.gz
msg_ok "Nextcloud ${NEXTCLOUD_VERSION} downloaded"

msg_info "Configuring Apache"
cat > /etc/apache2/sites-available/nextcloud.conf << 'APACHE'
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud
    <Directory /var/www/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog ${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
APACHE

a2ensite nextcloud.conf
a2dissite 000-default.conf
a2enmod rewrite headers env dir mime
systemctl restart apache2
msg_ok "Apache configured"

enable_service mariadb
enable_service apache2

IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GR}Nextcloud installed!${NC}"
echo -e "${GR}Access: http://${IP}${NC}"
echo ""
echo -e "${YL}Complete setup via the web UI:${NC}"
echo -e "${YL}  Admin account: create your own${NC}"
echo -e "${YL}  Database: nextcloud / nextcloud / nextcloud${NC}"
echo -e "${YL}  Database host: localhost${NC}"
echo ""
