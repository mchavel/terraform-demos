#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo bash -c 'echo Hello from $HOSTNAME.  Welcome to the Cloud! > /var/www/html/index.html'
EOF
