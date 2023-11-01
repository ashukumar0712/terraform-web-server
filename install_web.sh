sudo apt-get update -y
sudo apt-get upgragde -y 
sudo apt-get install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
sudo echo "<html><body><h2>Hello World</h2></body></html>" > /var/www/html/index.html
