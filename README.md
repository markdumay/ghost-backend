# Package

<!-- Tagline -->
<p align="center">
    <b>Deploy Ghost Blog as Back-End Docker Service</b>
    <br />
</p>


<!-- Badges -->
<p align="center">
    <a href="https://github.com/markdumay/ghost-backend/commits/master" alt="Last commit">
        <img src="https://img.shields.io/github/last-commit/markdumay/ghost-backend.svg" />
    </a>
    <a href="https://github.com/markdumay/ghost-backend/issues" alt="Issues">
        <img src="https://img.shields.io/github/issues/markdumay/ghost-backend.svg" />
    </a>
    <a href="https://github.com/markdumay/ghost-backend/pulls" alt="Pulls">
        <img src="https://img.shields.io/github/issues-pr-raw/markdumay/ghost-backend.svg" />
    </a>
    <a href="https://hub.docker.com/r/markdumay/ghost-backend" alt="Docker Image Size">
        <img src="https://img.shields.io/docker/image-size/markdumay/ghost-backend.svg" />
    </a>
    <a href="https://hub.docker.com/repository/docker/markdumay/ghost-backend/builds" alt="Docker Build">
        <img src="https://img.shields.io/docker/cloud/build/markdumay/ghost-backend.svg" />
    </a>
    <a href="https://github.com/markdumay/ghost-backend/blob/master/LICENSE" alt="License">
        <img src="https://img.shields.io/github/license/markdumay/ghost-backend.svg" />
    </a>
</p>

<!-- Table of Contents -->
<p align="center">
  <a href="#about">About</a> •
  <a href="#built-with">Built With</a> •
  <a href="#prerequisites">Prerequisites</a> •
  <a href="#testing">Testing</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#donate">Donate</a> •
  <a href="#license">License</a>
</p>


## About
[Ghost][ghost_info] is a popular open source Content Management System (CMS) based on Node.js. It was founded in 2013 and has seen more than 2 million installs to date. The team behind Ghost offers a managed service that gets you started in minutes. However, in this tutorial we will be looking into self-hosting Ghost as a back-end service on a Virtual Private Server (VPS). The final configuration aims to be both secure and scaleable.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [Ghost][ghost_url] - Content Management System
* [Docker][docker_url] - Container platform (including Swarm and Compose)
* [MariaDB][mariadb_url] - Community-developed fork of MySQL relational database
* [Mariabackup][mariabackup] - Open source tool provided by MariaDB for performing physical online backups
* [HTTPS Portal][portal_url] - Fully automated HTTPS server
* [Restic][restic_url] - Backup program with cloud storage integration

## Prerequisites
Ghost-backend can run on a local machine for testing purposes or in a production environment. The setup has been tested locally on macOS and a Virtual Private Server (VPS) running Ubuntu 20.04 LTS. The cloud backup functionality has been tested with [Backblaze B2].

### Recommended Server Sizing
Ghost is a relatively light-weight application that requires 1 GB of memory. 

### Host Operating System
<!-- TODO: check Ubuntu 20.04 -->
Most VPS providers offer several Linux distributions to be installed on your VPS. Although Docker and Ghost are compatible with many of them, Ghost recommends Ubuntu 18.04 LTS. The Long Time Support (LTS) edition is the most stable version and is the recommended environment for a production system.

### Other Prerequisites
* **A registered domain name is required** - Not only will this help people to find your blog, but it is also required for configuring SSL certificates to enable secure traffic via https. You should have the ability to manually configure DNS entries for your domain too.

* **Docker Compose and Docker Swarm are required** - Ghost and the MariaDB Database will be deployed as Docker containers in swarm mode to enable Docker secrets. This [repository][ubuntu-docker] provides a script to harden the host and to deploy Docker securely.

* **A (cloud) backup service is highly recommended** - To enable versioning and disaster recovery, an offsite backup is highly recommended. Restic provides [integrations][restic_integration] for Amazon S3, Minio Server, Openstack Swift, Backblaze B2, Microsoft Azure Blob Storage, and Google Cloud Storage. Other methods include SFTP, REST Server, or rclone. This readme uses Backblaze B2 as an example.
  
<!--TODO: test email -->
* **An email service is optional** - Having an email service allows you to receive system notifications from Ghost.


## Testing
It is recommended to test the services locally before deploying them to production. Running the service with `docker-compose` greatly simplifies validating everything is working as expected. Below four steps will allow you to run the services on your local machine and validate it is working correctly.

### Step 1 - Clone the Repository
The first step is to clone the repository to a local folder. Assuming you are in the working folder of your choice, clone the repository files. Git automatically creates a new folder `ghost-backend` and copies the files to this directory. Now change your working folder to be prepared for the next steps.

```console
git clone https://github.com/markdumay/ghost-backend.git
cd ghost-backend
```

### Step 2 - Create Docker Secrets
As Docker-compose does not support external Swarm secrets, we will create local secret files for testing purposes. 

```console
mkdir secrets
printf password > secrets/db_root_password
printf ghost > secrets/db_user
printf password > secrets/db_password
printf ghost_backup > secrets/db_backup_user
printf password > secrets/db_backup_password
printf password > secrets/restic_password
```

Next you will need to configure the tokens required to connect with your cloud storage provider. Below example defines the tokens for [Backblaze B2]. `Ghost-backend` automatically stages any Docker secret starting with the prefix `STAGE_`. In below example, `STAGE_B2_ACCOUNT_ID` becomes available as `B2_ACCOUNT_ID` for restic. This [link][restic_integration] provides an overview of the tokens required for each supported cloud provider. Be sure to properly update the `XXX` values too.

```
printf XXX > secrets/STAGE_B2_ACCOUNT_ID
printf XXX > secrets/STAGE_B2_ACCOUNT_KEY
```

### Step 3 - Update the Environment Variables
The `docker-compose.yml` file uses environment variables to simplify the configuration. You can use the sample file in the repository as a starting point.

```console
mv sample.env .env
```

The `.env` file specifies eight variables. Adjust them as needed:


| Variable              | Default             | Description |
|-----------------------|---------------------|-------------|
| **DOMAINS_BLOG**      | `example.com`       | Defines the domain name of your blog. Exclude the `http://` and `https://` protocols. |
| **DOMAINS_ADMIN**     | `admin.example.com` | Defines the optional admin domain name of your blog. Exclude the `http://` and `https://` protocols. |
| **DB_NAME**           | `ghost`             | The name of the database to be used by Ghost and MariaDB. |
| **DB_USER**           | `ghost`             | The name of database user to be used by Ghost when connecting with MariaDB. Ensure it is the same value as the secret `db_user`. |
| **ADMIN_EMAIL**       | `admin@example.com` | Email address for notifications from Ghost and Let's Encrypt.
| **THEMES**            | `true`              | Indicates wether the default Ghost theme (Casper) should be installed.
| **BACKUP**            | `remote`            | Indicates wether to schedule backups automatically. Settings can be either `none` for no backups, `local` for local backups only, or `remote` for both local and remote backups.
| **RESTIC_REPOSITORY** | `b2:bucket-name:/`  | Email address for notifications from Ghost and Let's Encrypt.


### Step 4 - Run Docker Service
Test the Docker services with `docker-compose`.

```console
docker-compose up
```

After pulling the images from the Docker Hub, you should see several messages. Below excerpt shows the key messages per section.

#### Enabling Automated Backups
During boot, `ghost-backend` enables the local and remote backups in line with the `BACKUP` setting (see <a href="#step-3---update-the-environment-variables">Step 3</a>). First the cron jobs for local backups are scheduled. A delta / incremental backup is scheduled 30 minutes past every hour. Full backups are scheduled at 00:00 am and 12:00 pm daily. Next, the latest `restic` binary is downloaded and installed (`mariabackup` is already present in the parent's Docker image provided by MariaDB). Once restic is installed, it is scheduled to run 45 minutes past every hour. Restic compares the local files with the latest snapshot available in the repository. If needed, it updates the remote repository automatically using `restic_password` as encryption password (see <a href="#step-2---create-the-docker-secrets">Step 2</a>). In the background, old restic snapshots are removed daily at 01:15 am. Restic also updates itself at 04:15 am if a new binary is available. Finally, the cron daemon is fired up.
```
mariadb_1 | [Note] Enabling local and remote backup
mariadb_1 | [Note] Adding backup cron jobs
mariadb_1 | [Note] View the cron logs in '/var/log/mariabackup.log'
mariadb_1 | [Note] Installed restic 0.9.6 compiled with go1.13.4 on linux/amd64
mariadb_1 | [Note] Adding restic cron jobs
mariadb_1 | [Note] View the cron log in '/var/log/restic.log'
mariadb_1 | [Note] Initialized cron daemon

```

### Initializing the MariaDB Database
Once the backups are set up, the MariaDB database is initialized. MariaDB starts a temporary server, creates the Ghost schema and gives the required priviliges to the Ghost user. A user `ghost_backup` is created for the `mariabackup` cron jobs scheduled in the previous section. Once the initialization is done, the actual MariaDB server is started.
```
mariadb_1 | [Note] [Entrypoint]: Entrypoint script for MySQL Server 1:10.3.22+maria~bionic started.
mariadb_1 | [Note] [Entrypoint]: Temporary server started.
mariadb_1 | [Note] [Entrypoint]: Creating database ghost
mariadb_1 | [Note] [Entrypoint]: Creating user ghost
mariadb_1 | [Note] [Entrypoint]: Giving user ghost access to schema ghost
mariadb_1 | [Note] Creating mariadb backup user 'ghost_backup' for database
mariadb_1 | [Note] [Entrypoint]: MySQL init process done. Ready for start up.
```

### Starting the MariaDB Database
With the database properly initialized, MariaDB can start accepting connections. The default port is `3306`.
```
mariadb_1 | [Note] mysqld: ready for connections.
mariadb_1 | Version: '10.3.22-MariaDB-1:10.3.22+maria~bionic'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  [...]
```

### Initializing Ghost Data
The `docker-compose` configuration instructs Ghost to wait for the database to become available on port `3306`. Once the database is available, Ghost will create and populate all tables, models, and relations at the first run.
```
ghost_1 | docker-compose-wait - Everything's fine, the application can now start!
ghost_1 | INFO Creating table: [...]
ghost_1 | INFO Model: [...]
ghost_1 | [INFO Relation: [...]
```

### Starting the Ghost Server
Once the data is available, Ghost will start running in production mode. Typically the initial run takes up to a minute. The boot time is drastically reduced if the data is already available. You can now access Ghost at `http://example.com` and setup your (administrative) user(s).
```
ghost_1    | [2020-06-17 11:45:40] INFO Ghost is running in production...
ghost_1    | [2020-06-17 11:45:40] INFO Your site is now available on http://example.com
ghost_1    | [2020-06-17 11:45:40] INFO Ctrl+C to shut down
ghost_1    | [2020-06-17 11:45:40] INFO Ghost boot 24.849s
```

## Deployment
The steps for deploying in production are slightly different than for local testing. Below four steps highlight the changes compared to the testing walkthrough.


### Step 1 - Clone the Repository
*Unchanged*

### Step 2 - Create Docker Secrets
<!-- TODO: add create_secret script -->
Instead of file-based secrets, you will now create secure secrets. Docker secrets can be easily created using pipes. Do not forget to include the final `-`, as this instructs Docker to use piped input. Update the credentials as needed.

```console
printf mail@example.com | docker secret create CF_Email -
printf password | docker secret create CF_Token -
printf admin | docker secret create SYNO_Username -
printf password | docker secret create SYNO_Password -
```


printf password | docker secret create db_root_password -
printf ghost | docker secret create db_user -
printf password | docker secret create db_password -
printf ghost_backup | docker secret create db_backup_user -
printf password | docker secret create db_backup_password -
printf password | docker secret create restic_password -
printf XXX | docker secret create STAGE_B2_ACCOUNT_ID -
printf XXX | docker secret create STAGE_B2_ACCOUNT_KEY -

If you do not feel comfortable copying secrets from your command line, you can use the wrapper `create_secret.sh`. This script prompts for a secret and ensures sensitive data is not displayed in your console.

```console
./create_secret.sh db_root_password
./create_secret.sh db_user
./create_secret.sh db_password
./create_secret.sh db_backup_user
./create_secret.sh db_backup_password
./create_secret.sh restic_password
./create_secret.sh STAGE_B2_ACCOUNT_ID
./create_secret.sh STAGE_B2_ACCOUNT_KEY
```

The `docker-compose.yml` in the repository defaults to set up for local testing. Update the `secrets` section to use Docker secrets instead of local files.

```Dockerfile
secrets:
    CF_Email:
        external: true
    CF_Token:
        external: true
    SYNO_Username:
        external: true
    SYNO_Password:
        external: true
```

### Step 3 - Update the Environment Variables
<!-- Check variables -->
*Unchanged, however, set DOMAINS_BLOG, DOMAINS_ADMIN, and TARGET to production once everything is working properly*

### Step 4 - Run Docker Service
The Docker service will be deployed to a Docker Stack in production. Unlike Docker Compose, Docker Stack does not automatically create local folders. Create empty folders for the `mariadb` and `ghost` data. Next, deploy the Docker Stack using `docker-compose` as input. This ensures the environment variables are parsed correctly.


```console
mkdir -p data/mariadb/mysql
mkdir -p data/mariadb/backup
mkdir -p data/mariadb/log
mkdir -p data/ghost
docker-compose config | docker stack deploy -c - ghost-backend
```

Run the following command to inspect the status of the Docker Stack.

```console
docker stack services ghost-backend
```

You should see the value `1/1` for `REPLICAS` for the Synology TLS service if the stack was initialized correctly. It might take a while before the services are up and running, so simply repeat the command after a few minutes if needed.

```
ID  NAME                MODE        REPLICAS    IMAGE                               PORTS
*** ghost-backend_acme   replicated  1/1         markdumay/ghost-backend:2.8.6
```

You can view the service log with `docker service logs ghost-backend_acme` once the service is up and running. Refer to the paragraph <a href="#step-4---run-with-docker-compose">Step 4 - Run with Docker Compose</a> for validation of the logs.

Debugging swarm services can be quite challenging. If for some reason your service does not initiate properly, you can get its task ID with `docker service ps ghost-backend_acme`. Running `docker inspect <task-id>` might give you some clues to what is happening. Use `docker stack rm ghost-backend` to remove the docker stack entirely.

## Usage
Usage

### Restore
<!-- TODO: elaborate for Docker Compose-->
Stop Docker containers `docker-compose down'
Enter mariadb command-mode: `docker-compose run mariadb bash'
Start Docker containers `docker-compose down'

<!-- TODO: elaborate for Docker Stack-->
docker-compose -f docker-compose-restore.yml up

## Contributing
1. Clone the repository and create a new branch 
    ```
    $ git checkout https://github.com/markdumay/ghost-backend.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes

## Credits
Ghost-backend is inspired by the following code repositories and blog articles:
* A Fresh Cloud - [Mariabackup bash scripts][mariabackup_bash]

## Donate
<a href="https://www.buymeacoffee.com/markdumay" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-orange.png" alt="Buy Me A Coffee" style="height: 51px !important;width: 217px !important;"></a>

## License
<a href="https://github.com/markdumay/ghost-backend/blob/master/LICENSE" alt="License">
    <img src="https://img.shields.io/github/license/markdumay/ghost-backend.svg" />
</a>

Copyright © [Mark Dumay][blog]



<!-- MARKDOWN PUBLIC LINKS -->
[Backblaze B2]: https://www.backblaze.com/b2/cloud-storage.html
[docker_url]: https://docker.com
[ghost_info]: https://ghost.org/docs/concepts/introduction/
[ghost_url]: https://ghost.org
[mariabackup_bash]: https://afreshcloud.com/sysadmin/mariabackup-bash-scripts
[mariabackup]: https://mariadb.com/kb/en/mariabackup-overview/
[mariadb_url]: https://mariadb.com
[restic_url]: https://restic.net
[restic_integration]: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/ghost-backend.git
[ubuntu-docker]: https://github.com/markdumay/ubuntu-docker
