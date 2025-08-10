# Outils Système

## 🛡️ Sécurité Système

### UFW (Uncomplicated Firewall)

#### Configuration actuelle
```bash
Status: active
Default: deny (incoming), allow (outgoing)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere  
443/tcp                    ALLOW       Anywhere
6443/tcp                   ALLOW       Anywhere  # K3s API
22/tcp (v6)                ALLOW       Anywhere (v6)
80/tcp (v6)                ALLOW       Anywhere (v6)
443/tcp (v6)               ALLOW       Anywhere (v6)
6443/tcp (v6)              ALLOW       Anywhere (v6)
```

#### Commandes utiles
```bash
# Status du firewall
sudo ufw status verbose

# Ouvrir un port
sudo ufw allow 8080/tcp

# Fermer un port  
sudo ufw delete allow 8080/tcp

# Activer/désactiver
sudo ufw enable
sudo ufw disable

# Reset complet
sudo ufw --force reset

# Logs
sudo tail -f /var/log/ufw.log
```

#### Règles avancées
```bash
# Limiter les connexions SSH (rate limiting)
sudo ufw limit ssh

# Autoriser depuis une IP spécifique
sudo ufw allow from 192.168.1.100

# Autoriser un port depuis un subnet
sudo ufw allow from 10.0.0.0/8 to any port 3306

# Bloquer une IP
sudo ufw deny from 1.2.3.4
```

### fail2ban

#### Configuration
```yaml
Service: fail2ban
Status: active  
Config: /etc/fail2ban/jail.local
Logs: /var/log/fail2ban.log
```

#### Configuration personnalisée
```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 600        # 10 minutes
findtime = 600       # Fenêtre de 10 minutes
maxretry = 5         # 5 échecs max
backend = auto
destemail = admin@gotravelyzer.com
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3         # Plus strict pour SSH
bantime = 1800       # 30 minutes

[nginx-http-auth]
enabled = false
port = http,https
logpath = /var/log/nginx/error.log

[traefik-auth]
enabled = false  
port = http,https
logpath = /var/log/traefik/access.log
```

#### Commandes utiles
```bash
# Status général
sudo fail2ban-client status

# Status d'une jail spécifique
sudo fail2ban-client status sshd

# Débannir une IP
sudo fail2ban-client set sshd unbanip 1.2.3.4

# Bannir manuellement
sudo fail2ban-client set sshd banip 1.2.3.4

# Recharger la configuration
sudo fail2ban-client reload

# Logs
sudo tail -f /var/log/fail2ban.log
```

#### Monitoring fail2ban
```bash
# IPs actuellement bannies
sudo fail2ban-client banned

# Statistiques
sudo fail2ban-client status sshd

# Intégration avec Prometheus (optionnel)
# fail2ban_exporter disponible sur GitHub
```

### SSH Configuration

#### Configuration sécurisée
```yaml
# /etc/ssh/sshd_config (extrait)
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
```

#### Gestion des clés SSH
```bash
# Lister les clés autorisées
cat ~/.ssh/authorized_keys

# Ajouter une nouvelle clé
echo "ssh-rsa AAAAB3..." >> ~/.ssh/authorized_keys

# Permissions correctes
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Test de connexion
ssh -T git@github.com
```

## 🔄 Mises à jour système

### unattended-upgrades

#### Configuration
```yaml
Service: unattended-upgrades
Config: /etc/apt/apt.conf.d/50unattended-upgrades
Status: enabled
Reboot: disabled (par défaut)
```

#### Configuration personnalisée
```bash
# /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
    "docker*";
    "kubernetes*";
    "k3s*";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "admin@gotravelyzer.com";
```

#### Commandes utiles
```bash
# Lancer les mises à jour maintenant
sudo unattended-upgrade --debug

# Status des mises à jour
cat /var/log/unattended-upgrades/unattended-upgrades.log

# Configuration actuelle
sudo unattended-upgrade --dry-run --debug
```

### Updates manuelles
```bash
# Mise à jour des packages
sudo apt update
sudo apt upgrade -y

# Mise à jour complète (avec noyau)
sudo apt update  
sudo apt full-upgrade -y

# Nettoyage
sudo apt autoremove -y
sudo apt autoclean

# Packages nécessitant redémarrage
cat /var/run/reboot-required.pkgs
```

## 📊 Monitoring système

### htop/top améliorés
```bash
# Installation d'outils de monitoring
sudo apt install -y htop iotop nethogs ncdu

# htop : processus interactif
htop

# iotop : I/O par processus  
sudo iotop

# nethogs : utilisation réseau par processus
sudo nethogs

# ncdu : utilisation disque
ncdu /
```

### Commandes de monitoring
```bash
# CPU
cat /proc/cpuinfo
lscpu
top -p 1

# Mémoire
free -h
cat /proc/meminfo

# Disque
df -h
du -sh /*
lsblk

# Réseau
ip addr show
ss -tuln
netstat -i

# Processus
ps aux
pstree
systemctl list-units --failed
```

### Logs système
```bash
# Logs systèmes centralisés
journalctl -f

# Logs par service
journalctl -u k3s -f
journalctl -u ssh -f
journalctl -u ufw -f

# Logs par timeframe
journalctl --since "1 hour ago"
journalctl --since "2025-01-01" --until "2025-01-02"

# Logs avec priorité
journalctl -p err
journalctl -p warning
```

## 🔧 Outils développeur

### Git configuration
```bash
# Configuration globale
git config --global user.name "Nathan Bardi"
git config --global user.email "devw.nbardi@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor vim

# Aliases utiles  
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
```

### Outils CLI installés
```bash
# Vérifier les versions
curl --version
wget --version
git --version
vim --version
jq --version

# Outils Kubernetes
kubectl version --client
helm version
flux version

# Outils de sécurité
sops --version
age --version

# Outils de développement
docker --version || echo "Docker non installé"
node --version || echo "Node.js non installé"
```

## 📦 Gestion des packages

### APT configuration
```bash
# Sources de packages
cat /etc/apt/sources.list

# Repositories additionnels
ls /etc/apt/sources.list.d/

# Cache APT
apt policy
apt list --upgradable
apt list --installed | grep kubernetes
```

### Snap packages (si utilisé)
```bash
# Lister les snaps installés
snap list

# Informations sur un snap
snap info kubectl

# Mise à jour des snaps
sudo snap refresh
```

## 🔍 Diagnostics système

### Hardware
```bash
# Informations CPU
lscpu
cat /proc/cpuinfo | grep "model name" | head -1

# Informations mémoire
free -h
dmidecode -t memory

# Informations disque
lsblk -f
fdisk -l

# Informations réseau
lspci | grep -i network
ip link show
```

### Performance
```bash
# Load average
uptime
cat /proc/loadavg

# I/O Wait
iostat -x 1

# Mémoire détaillée
cat /proc/meminfo | head -10

# Processus consommateurs
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
```

### Température et santé
```bash
# Température CPU (si sensors installé)
sensors || echo "Installer: sudo apt install lm-sensors"

# Santé des disques
sudo smartctl -a /dev/sda || echo "Installer: sudo apt install smartmontools"

# Uptime
uptime
cat /proc/uptime
```

## 🚨 Alerting système

### Monitoring basique avec cron
```bash
# Script de monitoring simple
cat > /home/ubuntu/monitor.sh <<'EOF'
#!/bin/bash
# Monitoring basique

# CPU usage
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU > 80" | bc -l) )); then
    echo "High CPU: $CPU%" | logger -t MONITOR
fi

# Memory usage  
MEM=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
if (( $(echo "$MEM > 80" | bc -l) )); then
    echo "High Memory: $MEM%" | logger -t MONITOR
fi

# Disk usage
DISK=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
if [ $DISK -gt 80 ]; then
    echo "High Disk: $DISK%" | logger -t MONITOR
fi
EOF

chmod +x /home/ubuntu/monitor.sh

# Crontab pour exécution toutes les 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/monitor.sh") | crontab -
```

### Intégration avec Prometheus
```bash
# Node Exporter déjà installé avec kube-prometheus-stack
kubectl get pods -n monitoring | grep node-exporter

# Métriques système exposées sur :9100/metrics
curl http://localhost:9100/metrics | grep node_cpu
```

## 🔐 Sécurité avancée

### Audit des permissions
```bash
# Fichiers avec SUID bit
find / -perm -4000 -type f 2>/dev/null

# Fichiers world-writable
find / -type f -perm -002 2>/dev/null

# Processus avec privilèges
ps aux | grep -E "(root|sudo)"
```

### Analyse des connexions
```bash
# Connexions réseau actives
ss -tuln

# Historique des connexions SSH
grep "Accepted" /var/log/auth.log | tail -10

# Tentatives d'intrusion
grep "Failed password" /var/log/auth.log | tail -10
```

## 📚 Scripts utiles

### Backup système
```bash
#!/bin/bash
# backup-system.sh

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup configuration importante
tar -czf "$BACKUP_DIR/system-config-$DATE.tar.gz" \
    /etc/ssh/sshd_config \
    /etc/ufw/ \
    /etc/fail2ban/ \
    ~/.kube/config \
    ~/age.agekey

echo "Backup completed: $BACKUP_DIR/system-config-$DATE.tar.gz"
```

### Health check complet
```bash
#!/bin/bash
# health-check.sh

echo "=== System Health Check ==="
echo "Date: $(date)"
echo

echo "=== Uptime ==="
uptime

echo "=== CPU & Memory ==="  
free -h
echo "Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"

echo "=== Disk Usage ==="
df -h | grep -v tmpfs

echo "=== K3s Status ==="
systemctl is-active k3s || echo "K3s not running!"

echo "=== Network ==="
ss -tuln | wc -l
echo "Active connections"

echo "=== Security ==="
sudo ufw status | head -5
echo "fail2ban status: $(systemctl is-active fail2ban)"

echo "=== Updates ==="
apt list --upgradable 2>/dev/null | wc -l
echo "packages can be upgraded"
```

## 🔗 Resources

- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [fail2ban Manual](https://www.fail2ban.org/wiki/index.php/Manual)
- [SSH Security Best Practices](https://www.ssh.com/academy/ssh/sshd_config)