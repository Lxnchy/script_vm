#!/bin/bash

echo "Mise à jour des paquets..."
sudo apt update -y
echo "Mise à niveau des paquets..."
sudo apt upgrade -y
echo "Mise à jour et mise à niveau terminées."

echo "Configuration de SSH pour utiliser le port 22..."
sudo sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
sudo systemctl restart ssh
echo "SSH configuré et redémarré."

echo "Configuration du pare-feu avec nftables pour SSH, HTTP, et HTTPS..."
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

echo "Application des règles de pare-feu avec nftables..."
sudo nft -f /etc/nftables.conf
echo "Pare-feu configuré."

echo "Installation des paquets nécessaires pour Docker..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
echo "Paquets pour Docker installés."

echo "Ajout de la clé GPG Docker..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "Clé GPG Docker ajoutée."

echo "Ajout du dépôt Docker à APT sources..."
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "Dépôt Docker ajouté."

echo "Mise à jour des paquets pour Docker..."
sudo apt update -y
echo "Mise à jour des paquets terminée."

echo "Installation de Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
echo "Docker installé."

echo "Vérification du statut de Docker..."
if systemctl status docker | grep -q "active (running)"; then
    echo "Docker est correctement installé et fonctionne."
else
    echo "Docker n'a pas pu être démarré. Vérifiez les logs."
    exit 1
fi

echo "Vérification si le groupe docker existe..."
if ! getent group docker > /dev/null 2>&1; then
    echo "Le groupe docker n'existe pas, création du groupe docker..."
    sudo groupadd docker
    echo "Groupe docker créé."
else
    echo "Le groupe docker existe déjà."
fi

echo "Ajout de l'utilisateur actuel au groupe docker..."
sudo usermod -aG docker $USER
echo "Utilisateur ajouté au groupe docker."

echo "Activation de Docker au démarrage..."
sudo systemctl enable docker
echo "Docker activé au démarrage."

echo "Installation de Docker Compose..."
VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
sudo curl -L "https://github.com/docker/compose/releases/download/$VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "Docker Compose installé."

echo "Installation terminée. Veuillez redémarrer votre session pour que les modifications du groupe docker prennent effet."
