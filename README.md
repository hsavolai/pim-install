# About

Howto-guide how to install Akeneo CE PIM (Community Edition) to Linux (Ubuntu 24.04)

# Disclaimer

The method presented here is **highly insecure** and should **not be used in production environments**. It lacks essential security protocols and **does not follow best practices** for system administration, containerization, or deploying Akeneo Community Edition (CE). 

Additionally, this configuration is **incomplete for the full functionality of Akeneo CE** and should only be used for quick setup purposes like development or testing. While it enables you to run MySQL, Elasticsearch, and Akeneo CE with demo data in a container and access it through a browser via an **unencrypted HTTP connection**, it leaves the system highly vulnerable.

This is quick-and-dirty setup to get this running with minimum effort.

**Use this approach entirely at your own risk.**

# Instructions

- Checkout this git repo.

Set up the system using podman (requires both root and 8192mb memory):
```bash
podman machine stop
podman machine rm
podman machine init --memory 8192
podman machine set --rootful
podman machine start
cd pim-install
podman run --rm -it -v "$(pwd)/install:/install" -p 8080:80 ubuntu:22.04 bash
```

When the container is running, execute in the bash prompt and and grab a cup of coffee:
```bash
source /install/install.sh
```

the installation completes with something like "nohup: ignoring input and appending output to 'nohup.out'"

Once the installation is done (there will be a lot of warnings, but that's okay), access the Akeneo CE with your host machine with url:

http://localhost:8080/

Default credentials for the demo installation are **admin**:**admin**
