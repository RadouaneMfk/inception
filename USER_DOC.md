# User documentation

This file explains how to use the Inception stack without knowing how it is built. For the technical side, see `DEV_DOC.md`.

## What the stack provides

| Service | What it does | Reachable from outside? |
|---|---|---|
| NGINX | Receives the HTTPS requests (port 443) and sends them to WordPress | Yes, on port 443 only |
| WordPress + php-fpm | The website and its administration panel | No, only through NGINX |
| MariaDB | The database where WordPress stores its pages, users and settings | No |

The website is at `https://rmouafik.42.fr` and the administration panel is at `https://rmouafik.42.fr/wp-admin`.

## Start and stop

All commands are run from the root of the repository, in the virtual machine.

| Command | Effect |
|---|---|
| `make` | Builds the images if needed and starts the three containers |
| `make stop` | Stops the containers without removing them |
| `make start` | Starts them again after a `stop` |
| `make down` | Stops and removes the containers and the network. The data is kept |
| `make fclean` | Removes everything, **including the website and the database** |

The first start takes a bit longer, because WordPress has to be downloaded and installed. Wait a minute or two before opening the site.

`make fclean` deletes all the data and cannot be undone. Use it only to start again from zero.

## Access the website and the administration panel

1. The name `rmouafik.42.fr` has to point to the virtual machine. On the computer where the browser runs, add this line to `/etc/hosts` (it needs root rights):

   ```
   <VM-IP>  rmouafik.42.fr
   ```

   The IP address of the VM is shown by `ip a` inside the VM. If the site stops loading one day, check that this address did not change.

2. Open `https://rmouafik.42.fr` in the browser. The certificate is self-signed, so the browser shows a security warning. This is expected: accept it and continue.
3. For the administration panel, go to `https://rmouafik.42.fr/wp-admin` and log in with the administrator account. The second account can log in at the same place, but it only has the rights of an author.

## Locate and manage the credentials

The credentials are not stored in the Git repository. They are in two places on the machine that runs the project:

- `srcs/.env`: non-secret settings. The domain name, the database name, the database user, the site title, and the usernames and emails of the two WordPress accounts.
- `secrets/`: the passwords.
  - `db_root_password.txt`: the password of the database root user
  - `db_password.txt`: the password of the database user used by WordPress
  - `credentials.txt`: the passwords of the two WordPress accounts, one per line (`WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`)

Keep these files private, and never add them to Git.

**Changing a password.** Editing a file in `secrets/` is not enough once the site is installed, because the passwords were already saved inside the database at the first start. There are two ways:

- For a WordPress account: log in to the administration panel and change the password in the *Users* menu.
- For everything else: change the file and then run `make fclean` followed by `make`. This rebuilds the stack from zero and deletes the existing site and database.

## Check that the services are running

1. List the containers:

   ```
   make ps
   ```

   The three containers (`nginx`, `wordpress`, `mariadb`) must be in the `running` state. If one is restarting all the time, look at its logs.

2. Read the logs:

   ```
   make logs
   ```

   Press `Ctrl+C` to leave. To see only one service: `docker logs wordpress`.

3. Test the website from the machine with the browser:

   ```
   curl -kI https://rmouafik.42.fr
   ```

   An answer such as `HTTP/1.1 200 OK` (or a redirect) means NGINX and WordPress are working. The `-k` option is there because of the self-signed certificate.

4. Check that port 80 is closed. This command must fail:

   ```
   curl -m 5 http://rmouafik.42.fr
   ```

If something does not work, `DEV_DOC.md` has a short list of known problems.