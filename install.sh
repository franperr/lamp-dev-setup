#!/bin/bash

# Instalacion de los paquetes de los servidores y bases de datos
echo "*** INSTALANDO Apache2 + PHP + MySQL ***"
sudo apt-get install -y apache2 php5-fpm php5-mysql php5-apcu apache2-mpm-event mysql-server php5-cli curl php5-gd libapache2-mod-php5
# Configuring ServerName
echo "*** CONFIGURANDO Apache2 + Hosts file ***"
echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf
sudo a2enconf servername
sudo a2enmod rewrite actions alias fastcgi

# Anyadimos el usuario actual al grupo www-data
sudo usermod -a -G www-data $USER

# Modificacion del archivo hosts
cat /etc/hosts | head -n +1 > /tmp/hosts.tmp # Sacamos la primera linea
echo "127.0.0.1   drupal.local" >> /tmp/hosts.tmp # Anyadimos las lineas que queremos
echo "127.0.0.1   drupal-dev.local" >> /tmp/hosts.tmp
cat /etc/hosts | tail -n +2 >> /tmp/hosts.tmp # Anyadimos las otras lineas del archivo original
sudo mv /tmp/hosts.tmp /etc/hosts # Reemplazamos el archivo original

# Creación de las carpetas en /var/www
sudo mkdir /var/www/drupal
sudo mkdir /var/www/drupal-dev

# Definicion de los permisos
sudo chown -R www-data:www-data /var/www/*
sudo chmod 775 $(find /var/www -type d)
sudo chmod 665 $(find /var/www -type f)

# Instalación de los archivos de configuración de apache
sudo cp ./drupal* /etc/apache2/sites-available/
sudo a2ensite drupal.local.conf drupal-dev.local.conf
sudo service apache2 restart

# Creando Links en el escritorio
desktop_dir=$(xdg-user-dir DESKTOP)
ln -s /var/www/drupal $desktop_dir/drupal
ln -s /var/www/drupal-dev $desktop_dir/drupal-dev

# Instalación de drush
echo "*** INSTALANDO Drush ***"
cd ~
curl -sS https://getcomposer.org/installer | php
sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc
source $HOME/.bashrc
php composer.phar global require drush/drush:6.*

# Instalación del servidor email
echo "*** INSTALANDO Postfix (servidor email para mandar correo con PHP y Drupal) ***"
echo "A continuación elija la opción 'Sitio Internet' y deja el nombre por defecto"
read -p "Pulsa [Enter] para continuar..."
sudo apt-get install -y postfix
# Añadido como relay del servidor smtp de la UPV
sudo postconf -e 'relayhost=[smtp.upv.es]:25'

# Instalación de GIT
echo "*** INSTALANDO Git ***"
sudo apt-get install -y git
git config --global color.ui true
git config --global color.status auto
git config --global color.branch auto 
git config --global core.editor nano
git config --global push.default simple

echo "Cual es su nombre ?"
read nombre
git config --global user.name "$nombre"
echo "Cual es su email ?"
read email
git config --global user.email "$email"

echo "*** Generando la clave SSH ***"
read -p "Generamos la clave? (s/n) - Si ya tiene una, no hace falta generar una de nuevo" -n 1 -r

if [[ $REPLY =~ ^[Ss]$ ]]
then
  echo ""
  echo "Deja todos las opciones por defecto - [Enter] en cada pregunta"
  ssh-keygen -t rsa -C "$email"
fi

echo "*** Terminado !! ***"
echo "Ya puede borrar la carpeta 'setup_drupal'"
echo "http://drupal.local corresponde a /var/www/drupal"
echo "http://drupal-dev.local corresponde a /var/www/drupal-dev"
echo "Los links han sido creados en el escritorio"
echo ""
echo "Copia la siguiente clave en la interfaz de GitLab para poder utilizar git:"
echo "----------- Inicio de la clave --------------------"
cat ~/.ssh/id_rsa.pub
echo "----------- Fin de la clave --------------------"

echo "Una vez listo, reiniciamos el ordenador para terminar"
read -p "Pulsa [Enter] para reiniciar..."
sudo shutdown -r now
