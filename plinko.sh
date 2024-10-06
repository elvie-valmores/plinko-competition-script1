#!/bin/bash
# Made by Elvie for the Horse Plinko Cyber Challenge, Fall 2024 - Mast Box

# Lock the root account
passwd -l root

# Remove all SSH keys from all authorized_keys files
rm -f /root/.ssh/authorized_keys
rm -f /home/*/.ssh/authorized_keys

# SSH hardening
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
# SSH whitelist - only allow hkeating and plinktern
echo "AllowUsers hkeating plinktern" >> /etc/ssh/sshd_config

# Additional SSH security settings
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config

# Install necessary packages
apt install ufw -y

# Set firewall rules for necessary services on Mast box
# Reset UFW rules to default (deny all incoming, allow all outgoing)
ufw reset

# Set default policies
ufw default deny incoming  # Deny all incoming traffic by default
ufw default allow outgoing  # Allow all outgoing traffic by default

# Allow necessary ports
ufw allow OpenSSH       # Allow SSH access (port 22)
ufw allow mysql         # Allow MySQL (port 3306)

# Enable UFW firewall
ufw enable

# Remove nopasswdlogon group to prevent passwordless logins
echo "Removing nopasswdlogon group"
sed -i -e '/nopasswdlogin/d' /etc/group

# Set correct permissions on sensitive files
chmod 644 /etc/passwd

# Backup all MySQL databases
mkdir -p /backup  # Ensure backup directory exists
mysqldump -u root --all-databases > /backup/db.sql

# Run MySQL secure installation to further harden MySQL (interactive steps automated)
mysql_secure_installation <<EOF

y
n
y
y
y
EOF

# Ensure hkeating user has MySQL access and privileges to 'my_wiki' database
mysql -u root -pMyNewPass -e "
  GRANT ALL PRIVILEGES ON my_wiki.* TO 'hkeating'@'localhost' IDENTIFIED BY 'MyNewPass';
  FLUSH PRIVILEGES;
"

# Ensure hkeating can view the user table in 'my_wiki' database
mysql -u hkeating -pMyNewPass -e "
  SELECT * FROM my_wiki.user;
"

# MySQL hardening
mysql -u root -pMyNewPass -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -pMyNewPass -e "DROP DATABASE IF EXISTS test;"
mysql -u root -pMyNewPass -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';"
mysql -u root -pMyNewPass -e "FLUSH PRIVILEGES;"

# Lock down MySQL configuration
echo "bind-address = 127.0.0.1" >> /etc/mysql/mysql.conf.d/mysqld.cnf  # Localhost only
echo "skip-networking" >> /etc/mysql/mysql.conf.d/mysqld.cnf  # Disable networking

# Restart MySQL to apply changes
service mysql restart

# Update the system and install useful monitoring tools
apt update -y
apt install fail2ban -y
apt install tmux -y
apt install curl -y
apt install whowatch -y

# Download pspy for process monitoring
wget https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy64
chmod +x pspy64

# Change passwords for all non-system users (IDs >= 999)
for user in $( sed 's/:.*//' /etc/passwd);
do
  if [[ $(id -u $user) -ge 999 && "$user" != "nobody" ]]
  then
    (echo "PASSWORD!"; echo "PASSWORD!") | passwd "$user"
  fi
done

# Check for password-related inconsistencies
pwck

# Lock down critical configuration files to prevent changes by attackers
chattr +i /etc/mysql/mysql.conf.d/mysqld.cnf
chattr +i /etc/ssh/sshd_config