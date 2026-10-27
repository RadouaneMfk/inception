#!/bin/bash

set -e

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

if [ ! -f "/var/lib/mysql/.done" ]; then
    echo "Initializing Mariadb data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    mysqld_safe --data=/var/lib/mysql &

    mariadb -u root <<-EOF
        CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOF

    mysqladmin shutdown -u root -p"${DB_ROOT_PASSWORD}"
    touch /var/lib/mysql/.done

fi

echo "Starting mariadb..."
exec mysqld_safe --datadir=/var/lib/mysql
