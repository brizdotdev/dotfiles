# Install Docker without Docker Desktop

- [Source - Blog](https://nickjanetakis.com/blog/install-docker-in-wsl-2-without-docker-desktop)
- [Source - YouTube](https://www.youtube.com/watch?v=SDk3pqFXgs8)

```sh
# Install Docker, you can ignore the warning from Docker about using WSL
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the Docker group
sudo usermod -aG docker $USER

# Install Docker Compose v2
sudo apt-get update && sudo apt-get install docker-compose-plugin

# Sanity check that both tools were installed successfully
docker --version
docker compose version

# Using Ubuntu 22.04 or Debian 10 / 11? You need to do 1 extra step for iptables
# compatibility, you'll want to choose option (1) from the prompt to use iptables-legacy.
sudo update-alternatives --config iptables
```

All you have to do is drop this into your `~/.profile`, `.zprofile` or equivalent file:

```sh
if grep -q "microsoft" /proc/version > /dev/null 2>&1; then
    if service docker status 2>&1 | grep -q "is not running"; then
        wsl.exe --distribution "${WSL_DISTRO_NAME}" --user root \
            --exec /usr/sbin/service docker start > /dev/null 2>&1
    fi
fi
```