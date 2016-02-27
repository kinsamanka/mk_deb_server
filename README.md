# mk_deb_server
Docker-compose scripts for hosting the packages built by Travis-CI

## Prerequisites
- Install `docker-compose` by following the instructions [here](https://docs.docker.com/compose/install/)
- [Travis-CI](https://travis-ci.org/) account

## Installation
- Clone this repository 

	```
	git clone https://github.com/machinekit/mk_deb_server
	```
- Perform initial setup 

	```
    cd mk_deb_server
    ./setup.sh
    ```
- Encrypt sftp access key 

    ```
    REPO=<USER/machinekit> ./cmds/encrypt_sftp_keys.sh
    ```

  `travis-cli` will ask for github login details.
  The user must have admin privileges over `<USER/machinekit>`
 
- Add GPG signing key  
  A passwordless GPG subkey is needed for reprepro. Follow the steps as outlined [here](https://www.gnupg.org/faq/gnupg-faq.html#automated_use) to remove the passphrase. Copy `secring.auto` to `keys/no_passwd_reprepro.key`. A more detailed guide for setting up a GPG key for passwordless signing can be found [here](https://www.digitalocean.com/community/tutorials/how-to-use-reprepro-for-a-secure-package-repository-on-ubuntu-14-04).

- Startup the docker containers

  ```
  docker-compose up -d
  ```
- The default configuration will listen on ports `9080` and `9443` for the web access and port `9022` for the sftp access

## Additional steps
- Setup your firewall rules so that the three ports (`9080`, `9443` and `9022`) can be accessed from the wan side
- Optionally enable port-forwarding
- Go to the [Travis-CI](https://travis-ci.org/) settings page for the repo `<USER/machinekit>` and add the following __*Environment Variables*__:
  - `SFTP_DEPLOY_ADDR`
  - `SFTP_DEPLOY_PORT`

## Notes
- To shutdown the containers:

  ```
  cd <mk_deb_server dir>
  docker-compose stop
  ```
- To start again:

  ```
  cd <mk_deb_server dir>
  docker-compose start
  ```
- More info about Docker containers can be found [here](https://docs.docker.com/compose/)

## Adding/Removing Packages
- Determine the name of the running reprepro container:

  ```
  cd <mk_deb_server dir>
  docker-compose ps
  ```
  Sample output:
    ```
        Name                  Command            State                       Ports
    --------------------------------------------------------------------------------------------------
    deb_data          /true                       Exit 0
    deb_reprepro      /bin/sh -c /run.sh          Up
    deb_sftp_server   /bin/sh -c /run.sh travis   Up       0.0.0.0:6022->22/tcp
    deb_web_server    nginx -g daemon off;        Up       0.0.0.0:6443->443/tcp, 0.0.0.0:6080->80/tcp
    ```
  The reprepro container is named `deb_reprepro`

- To add a package:
  - Copy the new package to `<mk_deb_server dir>/incoming`
  - check if the package is signed by running `debsig-verify <package.deb>`
  - If the package has not been signed with the GPG key, run the following command first:
    ```
    docker exec mk_reprepro dpkg-sig -k <GPG_KEY> --sign builder /incoming/<package.deb>
    ```
  - Run the following command:
    ```
    docker exec <container> reprepro --delete includedeb <suite> /incoming/<package.deb>
    ```
    Note:
  
      `<container>` - reprepro docker container name  
      `<suite>`     - debian release (*wheezy*/*jessie*)  
      `<GPG_KEY>`   - public gpg key (this is not the GPG subkey)

- To remove a package:
  ```
  docker exec <container> reprepro remove <suite> <packagename>
  ```
  Take note of the debian package naming scheme:

    `<packagename>_<VersionNumber>-<DebianRevisionNumber>_<DebianArchitecture>.deb`
  
  Example: if the package name is `libczmq-dbg_2.2.0-0.6~1jessie~1da_amd64.deb`, remove it by executing:
  ```
  docker exec <container> reprepro remove jessie libczmq-dbg
  ```

  
