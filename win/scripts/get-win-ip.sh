#!/bin/sh
## Get Windows IP address from WSL
## https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip
cat /etc/resolv.conf | grep nameserver | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"