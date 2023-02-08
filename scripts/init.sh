#!/bin/bash
sudo apt update
sudo apt install nginx docker.io git -y

#Allow incoming traffic to Nginx
sudo ufw enable
sudo ufw allow 'Nginx Full'
    
# Clone git repo
git clone https://github.com/Naphee25/automation-challenge-test.git
sudo cp -r https://github.com/Naphee25/automation-challenge-test.git /var/www/html
sudo chown -R $USER:$USER /var/www/html
    
# Configure nginx server
sudo echo 'server { listen 80; server_name ${azurerm_public_ip.public_ip.ip_address}; root /var/www/html; index index.html index.htm; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/sites-available/default
    
# Start nginx server
sudo systemctl restart nginx

# Install Dependencies
sudo apt install certbot python3-certbot-nginx -y

# Secure the website with Let's Encrypt
sudo certbot --nginx --redirect -d $ip_address

sudo zip -r lib_letsencrypt.zip /var/lib/letsencrypt/
sudo zip -r etc_letsencrypt.zip /etc/letsencrypt/

# Build the Docker image
#echo 'FROM nginx\nCOPY /var/www/html /home/azureuser/nginx/html\nEXPOSE 80\nEXPOSE 443' > Dockerfile

echo "FROM nginx:latest
# Copy default configuration files
COPY default.conf /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html

# Install necessary packages
RUN apt-get update
RUN apt-get install apt-utils
RUN apt-get install zip -y
RUN apt-get install unzip

# Copy LetsEncrypt files
COPY lib_letsencrypt.zip etc_letsencrypt.zip /tmp/
RUN unzip -qqo /tmp/etc_letsencrypt.zip -d /tmp/
RUN unzip -qqo /tmp/lib_letsencrypt.zip -d /tmp/
RUN cp /tmp/etc/letsencrypt /etc/ -r
RUN cp /tmp/var/tib/tetsencrypt /var/lib/ -r

# Expose ports
EXPOSE 80
EXPOSE 443

# Start nginx
CMD [\"nginx\", \"daemon off;\"]" > Dockerfile


docker build -t nginx .

# Start the Docker container
docker run -d --name nginx_cont -p 80:80 -p 443:443 nginx