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


## Prerequisites
Ghost-backend can run on a local machine for testing purposes or in a production environment. The setup has been tested locally on macOS and a Virtual Private Server (VPS) running Ubuntu 20.04 LTS.

### Recommended Server Sizing
Ghost is a relatively light-weight application that requires 1 GB of memory. 

### Host Operating System
<!-- TODO: check Ubuntu 20.04 -->
Most VPS providers offer several Linux distributions to be installed on your VPS. Although Docker and Ghost are compatible with many of them, Ghost recommends Ubuntu 18.04 LTS. The Long Time Support (LTS) edition is the most stable version and is the recommended environment for a production system.

### Other Prerequisites
* **A registered domain name is required** - Not only will this help people to find your blog, but it is also required for configuring SSL certificates to enable secure traffic via https. You should have the ability to manually configure DNS entries for your domain too.

* **Docker Compose and Docker Swarm are required** - Ghost and the MariaDB Database will be deployed as Docker containers in swarm mode to enable Docker secrets. This [repository][ubuntu-docker] provides a script to harden the host and to deploy Docker securely.

* **A (cloud) backup service is highly recommended** - To enable versioning and disaster recovery, an offsite backup is highly recommended. This package uses [Backblaze B2] as cloud storage provider, but there are many options available.

<!--TODO: test email -->
* **An email service is optional** - Having an email service allows you to receive system notifications from Ghost.


## Testing

### Step 1 - Title



## Deployment
The steps for deploying in production are slightly different than for local testing. Below four steps highlight the changes compared to the testing walkthrough.


### Step 1 - Title
*Unchanged*


## Usage
Usage


## Contributing
1. Clone the repository and create a new branch 
    ```
    $ git checkout https://github.com/markdumay/ghost-backend.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes

## Credits
Ghost-backend is inspired by the following code repositories and blog articles:
* A Fresh Cloud - [Mariabackup bash scripts][mariabackup]

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
[mariabackup]: https://afreshcloud.com/sysadmin/mariabackup-bash-scripts

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/ghost-backend.git
[ubuntu-docker]: https://github.com/markdumay/ubuntu-docker
