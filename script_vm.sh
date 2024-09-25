#!/bin/bash

# Mise à jour et mise à niveau des paquets
sudo apt update
sudo apt upgrade -y

# Configuration du SSH pour utiliser le port 22 (automatisé)
sudo sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
sudo systemctl restart ssh
sudo systemctl status ssh

# Configuration du pare-feu avec nftables pour SSH, HTTP et HTTPS
sudo bash -c 'cat > /etc/nftables.conf << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Acceptation des connexions déjà établies et du trafic interne
        ct state established,related accept
        iif "lo" accept
        
        # SSH
        tcp dport 22 accept
        
        # HTTP
        tcp dport 80 accept
        
        # HTTPS
        tcp dport 443 accept
        
        # Rejeter tout autre trafic
        reject with icmp type admin-prohibited
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF'

# Application des règles de pare-feu
sudo nft -f /etc/nftables.conf

# Installation des paquets nécessaires pour Docker
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Ajout de la clé GPG Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajout du dépôt Docker à APT sources
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mise à jour des paquets et installation de Docker
sudo apt update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Vérification du statut de Docker
sudo systemctl status docker

# Installation de Docker Compose
VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
sudo curl -L "https://github.com/docker/compose/releases/download/$VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Ajout de l'utilisateur actuel au groupe docker pour éviter d'utiliser sudo
sudo usermod -aG docker $USER

# Activation de Docker au démarrage
sudo systemctl enable docker
