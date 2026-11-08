# Developer documentation

This file explains how to set up the project from scratch, how to build and run it, how to manage the containers and the volumes, and where the data is stored. For the usage side, see `USER_DOC.md`.

## 1. Set up the environment from scratch

### Prerequisites

- A virtual machine running Debian 12, with a user called `rmouafik` (the data folders are created in `/home/rmouafik/data`).
- `sudo`, `make` and `git`:

  ```
  su -
  apt update && apt install -y sudo make git
  usermod -aG sudo rmouafik
  ```

  Then log out and log in again.

- Docker Engine and the Compose plugin, installed from Docker's official apt repository (https://docs.docker.com/engine/install/debian/). The project uses `docker compose` (version 2), not the old `docker-compose` command. Check with:

  ```
  docker --version
  docker compose version
  ```

  To use Docker without `sudo`, add the user to the `docker` group and log in again: `sudo usermod -aG docker $USER`.

### Get the sources

```
git clone <repository-url> inception
cd inception
```

### Configuration files (not in Git)

Two things are ignored by Git and have to be created by hand: `srcs/.env` and the `secrets/` folder.

**`srcs/.env`**: non-secret settings, one `NAME=value` per line.

```
DOMAIN_NAME=rmouafik.42.fr
MYSQL_DATABASE=<database name>
MYSQL_USER=<database user for WordPress>
WP_TITLE=<site title>
WP_ADMIN_USER=<administrator login>
WP_ADMIN_EMAIL=<administrator email>
WP_USER=<second user login>
WP_USER_EMAIL=<second user email>
```

The administrator login must not contain `admin` or `administrator` (in any case), as the subject requires.

**`secrets/`**: the passwords, as plain text files.

```
secrets/db_root_password.txt   the password of the database root user
secrets/db_password.txt        the password of MYSQL_USER
secrets/credentials.txt        two lines:
                                 WP_ADMIN_PASSWORD=<password of the administrator>
                                 WP_USER_PASSWORD=<password of the second user>
```

Do not use the characters `'` and `\` in the database passwords. They are written inside an SQL statement by the MariaDB start script, and they would break it.

Keep the permissions of these files tight, and check with `git status` that they are not tracked.

### Name resolution

The browser must resolve `rmouafik.42.fr` to the VM. On the machine that runs the browser, add `<VM-IP>  rmouafik.42.fr` to `/etc/hosts`.

## 2. Build and launch

Everything goes through the Makefile at the root, which calls `docker compose -f srcs/docker-compose.yml`.

```
make
```

This does, in order:

1. create `/home/rmouafik/data/mariadb` and `/home/rmouafik/data/wordpress` if they do not exist (the volumes cannot start without them),
2. build the three images from the Dockerfiles in `srcs/requirements/`,
3. start the containers in the background.

| Target | Effect |
|---|---|
| `make` / `make up` | Create the data folders, build and start |
| `make down` | Stop and remove the containers and the network |
| `make stop` / `make start` | Stop / start the existing containers |
| `make ps` | Show the state of the containers |
| `make logs` | Follow the logs of all services |
| `make clean` | `down` plus removal of the volume objects (the files on disk stay, see section 4) |
| `make fclean` | `clean`, removal of the images, and deletion of the data folders (uses `sudo`) |
| `make re` | `fclean`, then a new build |

After changing a Dockerfile, a config file or a script, run `make` again: the `--build` option rebuilds what changed. A plain `docker compose restart` does not rebuild images, so it does not pick up changes.

## 3. Manage the containers and the volumes

In the commands below, `$C` stands for `docker compose -f srcs/docker-compose.yml`.

Containers:

```
$C ps                       state of the services
$C logs -f wordpress        logs of one service
docker exec -it nginx bash  shell inside a container
docker exec nginx nginx -t  check the NGINX configuration
$C restart mariadb          restart one service (no rebuild)
$C build --no-cache nginx   rebuild one image without the cache
```

Database:

```
docker exec -it mariadb mariadb -u root -p
```

then, for example, `SHOW DATABASES;` and `SELECT user, host FROM mysql.user;`.

WordPress (WP-CLI is installed in the container):

```
docker exec wordpress wp user list --allow-root
docker exec wordpress php-fpm8.2 -t
```

Volumes and network:

```
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
docker network inspect srcs_inception
```

The names start with `srcs_` because Docker Compose uses the name of the folder that contains the compose file as the project name.

Checks that are useful when validating the project:

```
docker exec <container> cat /proc/1/cmdline | tr '\0' ' '    which process is PID 1
docker exec mariadb mount | grep secrets                     how the secrets are mounted
openssl s_client -connect rmouafik.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect rmouafik.42.fr:443 -tls1_3 </dev/null
```

## 4. Where the data is stored and how it persists

| Volume | Mounted in | Stored on the host |
|---|---|---|
| `mariadb_data` | `mariadb:/var/lib/mysql` | `/home/rmouafik/data/mariadb` |
| `wordpress_data` | `wordpress:/var/www/html` and `nginx:/var/www/html` (read-only) | `/home/rmouafik/data/wordpress` |

Both are named volumes declared with the `local` driver and the options `type: none`, `o: bind` and `device: <folder>`. This is how a named volume is made to store its data in a chosen folder.

Persistence:

- `make down` followed by `make` keeps everything: the site, the users, the posts and the uploads are still there.
- `make clean` removes the Docker volume objects, but the files stay in `/home/rmouafik/data`, because the volumes are bound to those folders. The next start finds the old data again, including the `.done` marker of MariaDB.
- `make fclean` is the only target that really deletes the data. The files belong to the container users (`mysql`, `www-data`), so the deletion needs `sudo`.

How the start scripts decide what to do at each start:

- **MariaDB**: if `/var/lib/mysql/.done` does not exist, it starts a temporary server, creates the database and the user, sets the root password, stops the temporary server and creates the marker file. Otherwise it goes straight to starting the real server. The marker is created last, so a setup interrupted halfway is done again at the next start.
- **WordPress**: it waits for MariaDB (30 tries), then does each step only if needed: download if `wp-load.php` is missing, create `wp-config.php` if it is missing, install the site and create the second user if `wp core is-installed` fails.

## 5. Known problems

- **403 Forbidden on the home page**: the website folder is empty or has no `index.php`. WordPress has not finished its installation (or it is failing). Check `docker logs wordpress` and `docker logs mariadb`.
- **MariaDB restarts in a loop**: read `docker logs mariadb`. The data folder must be usable by the `mysql` user of the container, and the start script must wait for the temporary server before running the SQL.
- **WordPress prints "MariaDB is not reachable"**: the database container is not ready or not reachable. Check that MariaDB is running and that `bind-address` is `0.0.0.0` in its configuration.
- **A configuration file seems to be ignored by MariaDB**: files in `/etc/mysql/mariadb.conf.d/` are only read if their name ends with `.cnf`.
- **`make` fails on the volumes**: the data folders must exist before the containers start. The Makefile creates them, but if you run `docker compose` by hand, create them first.
- **The site stops loading after a reboot of the VM**: its IP address may have changed. Update the line in `/etc/hosts`.