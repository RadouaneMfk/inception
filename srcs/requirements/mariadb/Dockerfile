FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y mariadb-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/mariadb.cnf

COPY tools/init_db.sh /usr/local/bin/init_db.sh

RUN chmod +x /usr/local/bin/init_db.sh

EXPOSE 3306

ENTRYPOINT ["init_db.sh"]
