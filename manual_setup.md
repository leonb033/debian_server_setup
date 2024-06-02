# Podman over Wireguard (Manual Setup)
## Podman
> **Enable backports**\
Open sources file and append backports.\
`sudo micro /etc/apt/sources.list`
```
#BACKPORTS
deb http://deb.debian.org/debian bookworm-backports main contrib non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free-firmware
```

> **Update repositories**\
`sudo apt update`

> **Install podman & podman-compose from backports**\
`sudo apt install -t bookworm-backports podman podman-compose`

> **Create nginx container for testing**\
`mkdir ~/nginx && micro ~/nginx/compose.yaml`
```
services:
    nginx:
        container_name: nginx
        image: docker.io/nginx
        restart: unless-stopped
        volumes:
            - ./templates:/etc/nginx/templates
        ports:
            - "8080:80"
        environment:
            - NGINX_PORT=80
```

> **Open nginx port in UFW**\
Open port.\
`sudo ufw allow 8080/tcp`\
Reload firewall.\
`sudo ufw reload`

> **Start nginx container**\
Change directory.\
`cd ~/nginx`\
Start container.\
`sudo podman-compose up -d --force-recreate`

> **Enable auto-start for container**\
Create directory for systemd services.\
`mkdir -p ~/.config/systemd/user`\
Generate systemd file and write to service directory.\
`sudo podman generate systemd --new --name nginx | sudo tee /etc/systemd/system/nginx.service`\
Reload systemd.\
`sudo systemctl daemon-reload`\
Stop container and remove old files.\
`sudo podman stop nginx && podman rm -a && podman volume prune`\
Enable auto-start for service.\
`sudo systemctl enable nginx.service`\
Start service.\
`sudo systemctl start nginx.service`


## Wireguard
### General Setup
> **Install wireguard**\
Debian: `sudo apt install wireguard`\
Fedora: `sudo dnf install wireguard-tools`

> **Create private key file**\
`sudo touch /etc/wireguard/private.key`

> **Set permission of private key file**\
`sudo chmod -R 700 /etc/wireguard/private.key`

> **Generate private key**\
`wg genkey | sudo tee /etc/wireguard/private.key`

> **Generate public key**\
`sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key`

### Server Setup
> **Open wireguard port in UFW**\
Open port.\
`sudo ufw allow 51820/udp`\
Reload firewall.\
`sudo ufw reload`


> **Enable IPv4 Forwarding**\
Open sysctl.conf.\
`sudo micro /etc/sysctl.conf`\
Uncomment this line.\
`net.ipv4.ip_forward=1`\
Apply changes.\
`sudo sysctl -p`

> **Create server config file**\
`sudo micro /etc/wireguard/wg0.conf`
```
[Interface]
Address = 10.10.10.1
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
AllowedIPs = 10.10.10.2, 10.89.0.0/24
PublicKey = <CLIENT_PUBLIC_KEY>
```
PostUp = ip route add 10.89.0.0/24 via 10.10.10.1
PreDown = ip route del 10.89.0.0/24 via 10.10.10.1

> **Enable auto-start for interface**\
`sudo systemctl enable wg-quick@wg0.service`\
**Start interface**\
`sudo systemctl start wg-quick@wg0.service`

### Client Setup
> **Create client config file**\
`sudo micro /etc/wireguard/wireguard.conf`
```
[Interface]
Address = 10.10.10.2
PrivateKey = <CLIENT_PRIVATE_KEY>

[Peer]
Endpoint = 192.168.122.46:51820
AllowedIPs = 10.10.10.1, 10.89.0.0/24
PublicKey = <SERVER_PUBLIC_KEY>
```

> **Import VPN config**\
`sudo nmcli con import type wireguard file /etc/wireguard/wireguard.conf`
