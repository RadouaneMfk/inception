*This project has been created as part of the 42 curriculum by rmouafik.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum. The goal is to build a small web infrastructure with Docker, inside a virtual machine. Every service runs in its own container, and every image is built from a Dockerfile written for this project. Pulling ready-made images is not allowed, except for the Debian base image.

The stack has three services:

- **NGINX**: the only entry point of the infrastructure. It listens on port 443 and accepts TLS 1.2 and TLS 1.3 only.
- **WordPress + php-fpm**: WordPress is downloaded and installed at the first start with WP-CLI. php-fpm listens on port 9000, inside the Docker network only. There is no web server in this container.
- **MariaDB**: the database used by WordPress. It is only reachable from inside the Docker network.

The data is kept in two Docker named volumes (one for the database, one for the website files), stored under `/home/rmouafik/data` on the host. A user-defined bridge network connects the three containers, and each container restarts if it crashes. The website is served at `https://rmouafik.42.fr`.

## Instructions

### Requirements

- A virtual machine running Debian 12.
- Docker Engine, the Docker Compose plugin (`docker compose`), `make` and `git`.
- A user called `rmouafik` in the VM, because the data folders are created in `/home/rmouafik/data`.

### Setup and run

1. Clone the repository.
2. Create `srcs/.env` and the files in `secrets/`. These are ignored by git and are never committed. The list of variables and the format of each file is in `DEV_DOC.md`.
3. On the machine where the browser runs, add the IP address of the VM to `/etc/hosts`:

   ```
   <VM-IP>  rmouafik.42.fr
   ```

4. Run `make` from the root of the repository. It creates the data folders, builds the three images and starts the containers.
5. Open `https://rmouafik.42.fr`. The certificate is self-signed, so the browser shows a warning that you have to accept.

### Main commands

| Command | What it does |
|---|---|
| `make` | Build the images and start everything |
| `make stop` / `make start` | Pause and resume the containers |
| `make down` | Stop and remove the containers and the network, data is kept |
| `make clean` | Same as `down`, and also removes the volume objects |
| `make fclean` | Full cleanup: containers, images and the data in `/home/rmouafik/data` |
| `make re` | `fclean` followed by a fresh build |
| `make ps` / `make logs` | Show the containers / follow their logs |

More details are in `USER_DOC.md` (using the stack) and `DEV_DOC.md` (building and maintaining it).

## Project description

### Docker in this project and the sources included

Docker packages each service with what it needs to run, so the three services can be built, started and removed independently, and the whole stack can be rebuilt from the repository with one command.

The sources are organised like this:

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/            (not in git: passwords)
└── srcs/
    ├── docker-compose.yml
    ├── .env            (not in git: non-secret settings)
    └── requirements/
        ├── mariadb/    Dockerfile, conf/, tools/
        ├── nginx/      Dockerfile, conf/, tools/
        └── wordpress/  Dockerfile, conf/, tools/
```

Each service folder has a Dockerfile, a `conf/` folder with the configuration files copied into the image, and a `tools/` folder with the start script when the service needs one.

### Main design choices

- **Base image**: all three images start from `debian:bookworm-slim` (Debian 12, the penultimate stable release). Everything else is installed with `apt` inside our own Dockerfiles. WP-CLI is downloaded in the WordPress image.
- **One process per container, as PID 1**: each start script ends with `exec` on the real daemon (`mariadbd`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`). The daemon receives the stop signal from Docker directly, and there is no `tail -f`, `sleep infinity` or similar trick.
- **Scripts that can run twice**: MariaDB creates a marker file in its data directory once the setup is done. The WordPress script checks, step by step, whether WordPress is downloaded, configured and installed before doing each step. A restart never reinstalls anything.
- **Waiting for the database**: the WordPress script retries a connection to MariaDB up to 30 times and then stops with an error, so it never loops forever.
- **TLS**: a self-signed certificate is generated when the NGINX image is built, and `ssl_protocols` is set to TLS 1.2 and 1.3 only. Port 80 is not open.
- **php-fpm over TCP**: php-fpm listens on `0.0.0.0:9000` instead of a Unix socket, because NGINX runs in another container and cannot share a socket file with it. The port is not published on the host.
- **Shared website volume**: NGINX mounts the WordPress volume read-only, because it needs to read the files to serve static content and to hand PHP files over to php-fpm.
- **Configuration**: non-secret settings are in `srcs/.env`. Passwords are Docker secrets, read from `/run/secrets/` by the scripts, and never written in a Dockerfile.

### Virtual Machines vs Docker

A virtual machine emulates hardware and runs a complete guest operating system with its own kernel. The isolation is strong, but a VM is heavy: gigabytes of disk, its own memory, and a boot time of a minute or more. A container is just a Linux process isolated with namespaces and cgroups. It shares the kernel of the host, so it is small, starts in seconds and is easy to rebuild. The price is a weaker isolation, since all the containers depend on the same kernel.

In this project we use both: the VM gives a clean and disposable Linux environment where Docker can be installed, and Docker gives one lightweight container per service inside it.

### Secrets vs Environment Variables

Environment variables are simple, but they are visible in `docker inspect`, they are inherited by child processes and they can end up in logs. They are fine for settings that are not sensitive. Docker secrets are files, mounted read-only under `/run/secrets/` in the containers that were given access to them. They are not part of the image layers and not in the environment.

Here, `.env` holds the domain name, the database name, the usernames and the emails. The passwords are in the `secrets/` folder, and the scripts read them with `cat /run/secrets/...`. With Docker Compose a secret is a bind mount of a file from the host (checking with `mount` inside a container shows the disk of the VM, not a RAM filesystem), so it is not encrypted storage. Anyone who can run `docker exec` can read it. That is why `secrets/` is in `.gitignore` and must never be committed. Docker Swarm stores secrets differently, but the subject requires Docker Compose.

### Docker Network vs Host Network

With the host network, a container shares the network stack of the host. There is no isolation, no separate IP address, port conflicts with the host are possible, and everything the container listens on is exposed. The subject forbids it.

We use a user-defined bridge network called `inception`. The containers get private IP addresses, and Docker provides a DNS by service name, so WordPress connects to `mariadb:3306` and NGINX connects to `wordpress:9000` without any IP address. Nothing is reachable from outside unless a port is published, and the only published port in the whole project is 443 on NGINX.

### Docker Volumes vs Bind Mounts

A bind mount maps a path of the host directly into the container. It is simple, but it depends on the layout and the permissions of the host, and Docker does not manage it. A named volume is created and managed by Docker (`docker volume ls`, `docker volume inspect`), it is referred to by its name, and it exists independently from the containers.

The subject asks for named volumes that store their data in `/home/rmouafik/data`. So the two volumes are declared in `docker-compose.yml` with the `local` driver and the options `type: none`, `o: bind` and `device: /home/rmouafik/data/...`. The services only use the volume names, and only the volume definition says where the data lives on the host. A bind mount would have been a host path written directly in the `volumes:` line of a service, which is not allowed here.

## Resources

### References

- Docker documentation: https://docs.docker.com/
- Dockerfile best practices: https://docs.docker.com/build/building/best-practices/
- Docker Compose file reference: https://docs.docker.com/compose/
- Docker Engine installation on Debian: https://docs.docker.com/engine/install/debian/
- NGINX documentation: https://nginx.org/en/docs/
- PHP-FPM manual: https://www.php.net/manual/en/install.fpm.php
- MariaDB Knowledge Base: https://mariadb.com/kb/en/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/

### Use of AI

I used an AI assistant (Claude) during this project, mostly as a tutor and a reviewer:

- To understand concepts before writing code: PID 1 and signals in containers, `exec` in entrypoint scripts, Docker secrets, named volumes with `driver_opts`, FastCGI between NGINX and php-fpm, and TLS settings in NGINX.