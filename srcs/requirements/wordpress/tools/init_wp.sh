#!/bin/bash
set -e

DB_PASSWORD=$(cat ../../run/secrets/db_password)
WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' ../../run/secrets/credentials | cut -d= -f2-)
WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' ../../run/secrets/credentials | cut -d= -f2-)

cd /var/www/html


tries=0
until mariadb-admin ping -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" --silent; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
        echo "MariaDB is not reachable"
        exit 1
    fi
    sleep 2
done


if [ ! -f wp-load.php ]; then
    wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost=mariadb
fi

if ! wp core is-installed --allow-root; then
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 -F

