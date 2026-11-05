FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl nginx \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/rmouafik.key \
        -out /etc/nginx/ssl/rmouafik.crt \
        -subj "/CN=rmouafik.42.fr"

RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY conf/nginx.conf /etc/nginx/conf.d/inception.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
