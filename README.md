# Docker Release Image for Commonjava Maven Projects

This Docker image is intended to standardize the way we run project releases where Apache Maven is in use. It forms a clean, known build environment in which there is no pre-existing Maven state (local repository) and where only the basics necessary for a Maven release are present.

## Contents

<!-- toc -->

- [Getting the Image](#getting-the-image)
- [Building the Image](#building-the-image)
- [Using the Image](#using-the-image)
  * [Pre-Requisite: GPG](#pre-requisite-gpg)
  * [Pre-Requisite: Maven Settings](#pre-requisite-maven-settings)
  * [Pre-Requisite: Git Configuration](#pre-requisite-git-configuration)
  * [Pre-Requisite: SSH Keys for GitHub](#pre-requisite-ssh-keys-for-github)
  * [Fixing the Selinux Context for `private/`](#fixing-the-selinux-context-for-private)
  * [Ready to Run](#ready-to-run)
  * [Cleaning Up](#cleaning-up)
- [ADVANCED: Releases That Manage Containers](#advanced-releases-that-manage-containers)
  * [Enable TCP Connections To Docker](#enable-tcp-connections-to-docker)
  * [Inter-Container Communications](#inter-container-communications)
  * [Docker vs. firewalld](#docker-vs-firewalld)

<!-- tocstop -->

## Getting the Image

This image should be available via:

```
$ docker pull docker.io/commonjava/maven-release
```

## Building the Image

If you make changes to the environment, you'll need to rebuild it. Maybe the easiest way to do this is:

```
$ ./scripts/build-image.sh
```

This script simply builds the Dockerfile from the current directory ($PWD) using the tag `docker.io/commonjava/maven-release`.

**NOTE:** You'll need to run the `build-image.sh` script from the **root** of this git repository, where the Dockerfile is located.

## Using the Image

To run a release with this Docker image, you'll need to satisfy some prerequisites in terms of configuration. These congfiguration files are not stored in the image because they're private to you. This git repository contains a convenience script for launching a Docker container to run your release, but it assumes you have all of your configuration assembled in a directory within the git working directory called `private/`. Follow the instructions below to setup these configurations.

### Pre-Requisite: GPG

You need to have a GPG configuration directory that you can provide via volume mount to the Docker container. To set this up, you need to install GPG, then generate a default key for signing build output. You can find more information about this at: [Working with PGP Signatures - Sonatype](http://central.sonatype.org/pages/working-with-pgp-signatures.html).

Once you have a directory called $HOME/.gnupg, you can copy this whole directory to `<maven-release-git-workdir>/private/gnupg`.


### Pre-Requisite: Maven Settings

You'll need a Maven `settings.xml` capable of authenticating to the Sonatype OSS staging server, and potentially, to Docker. It will also have to know about the GPG key / passphrase you setup above. Since we really don't want to leave passwords available in plaintext in your `settings.xml`, it's a good idea to encrypt the passwords before adding them. To do that, its helpful if you have Maven installed. If you don't, install it now.

Next, copy the `<maven-release-git-workdir>/private.template/m2` directory to `$HOME/.m2`. If you have a `$HOME/.m2` already, move it out of the way temporarily. Follow the instructions at [Maven - Password Encryption](https://maven.apache.org/guides/mini/guide-encryption.html) to setup your master key and then encrypt passphrases for all of the necessary fields in the `$HOME/.m2/settings.xml` you just copied. There will be 3-4 passwords / passphrases you need to encrypt here.

Once that's complete, copy your `$HOME/.m2` to `<maven-release-git-workdir>/private/m2` and, if appropriate, restore your original `$HOME/.m2` directory.

### Pre-Requisite: Git Configuration

Since a standard Maven release involves creation of a Git tag (not to mention pushing various commits), you need to give Git some basic information about who you are. You can copy the `<maven-release-git-workdir>/private.template/gitconf` directory into `<maven-release-git-workdir>/private/gitconf` and then just edit the file to fill in real values for the placeholders.

### Pre-Requisite: SSH Keys for GitHub

Again, since the Maven release will tag and push commits to GitHub, it's important that you have a SSH public key registered on GitHub (see your account settings, under SSH Keys on the left-hand side). Then, you have to provide the corresponding private key to this Docker container so it can push content on your behalf. You can simply copy the correct `id_rsa` file to `<maven-release-git-workdir>/private/ssh`.

### Fixing the Selinux Context for `private/`

Once you assemble all of these configurations, you may need to correct the selinux context on the `private/` sub-directories:

```
$ chcon -Rt svirt_sandbox_file_t <maven-release-git-workdir>/private/*
```

### Ready to Run

The final pieces you have to know before you run your release are:

* Your GitHub URL (Use the `git@github.com:Commonjava/foo.git` / SSH URL so you can use your SSH key)
* The Git branch from which you wish to run the release (OPTIONAL; defaults to `master`)

When you have all this assembled, you can run the release with:

```
$ ./scripts/start-release.sh <GIT-URL> [<GIT-BRANCH>] [<MAVEN_OPTIONS>]
```

**NOTE:** If you want to provide extra Maven options to this script, you'll need to add the branch to the call, even if the branch is `master`.

### Cleaning Up

If you peek at the `scripts/start-release.sh` script, you'll see that we don't use the Docker `--rm` option to the run command. This is intentional. If the build fails for a mysterious reason, keeping the container will allow you to copy the contents from the `/home/maven/` directory and possibly figure out what went wrong.

The consequence of this is that, if you don't clean up your Docker system yourself, you'll begin to accumulate old maven-release containers. This causes quite a lot of clutter, and can fill up your hard drive over time. To clean, you can use:

```
$ for c in $(docker ps -a | grep 'commonjava/maven-release' | grep Exited | awk '{print $1}'); do docker rm $c; done
```

## ADVANCED: Releases That Manage Containers

Some Maven builds we have in Commonjava require building Docker images and running Docker containers in order to do integration tests. When you have a project like this, you'll need to make special preparations for the Docker environment in which you intend to run releases.

### Enable TCP Connections To Docker

If you're going to use Docker containers during your release, your Docker daemon must listen on a TCP port. To enable this, edit your `/etc/sysconfig/docker` file as follows:

```
OPTIONS='--selinux-enabled --log-driver=journald -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock'
```

Then, restart your Docker daemon using something like:

```
$ systemctl restart docker
```

### Inter-Container Communications

Docker containers can't talk to each other when they use the default `docker0` network bridge. They can't even see each other. So, if your release (running in a container) needs to start other containers and then communicate with them, you'll need to create a separate Docker network for that. Since you're going to be interacting with the outside world (pulling down Maven plugins, publishing build output, etc.), this network will have to be a bridge network. By default (and for historical reasons), the `<maven-release-git-workdir>/scripts/start-release.sh` script assumes this network will be called `ci-network` and use the IP address range `172.18.0.0/24`, which means the DOCKER_HOST	environment variable passed into the release container will be `tcp://172.18.0.1:2375`.

You can create this `ci-network` bridge using the following command:

```
$ docker network create -d bridge ci-network
```

### Docker vs. firewalld

Docker and firewalld have a fraught relationship. For most Docker use cases, they work together well enough. However, when you have a Docker container that requires access to the Docker daemon (to build or run containers), firewalld will do its best to block your access.

I'm still working out the details of how to script this elegantly, but you need to add your new network bridge to the `trusted` firewall zone. This worked for me:


```
$ export gwip=$(docker network inspect ci-network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
$ export ifc=$(ip -4 addr show | grep -B1 ${gwip} | head -1 | awk '{print $2}' | sed 's/://')

Once you have the iterface, move it to the 'trusted' firewall zone...

$ firewall-cmd --permanent --zone=public --remove-interface=$ifc
$ firewall-cmd --permanent --zone=trusted --change-interface=ifc

Then, make sure the NetworkManager scripts reflect this change...

$ vi /etc/sysconfig/network-scripts/ifcfg-$ifc

VERIFY that ZONE=trusted

Now, stop docker and restart / reload firewalld

$ systemctl stop docker
$ systemctl restart firewalld  # OR: firewall-cmd --reload

Just to be sure the interface is set up correctly, reload it and then verify the zone it's in...

$ ifdown $ifc
$ ifup $ifc
$ firewall-cmd --get-zone-of-interface=$ifc
trusted

Now, restart Docker
$ systemctl start docker
```


