#!/bin/bash

if [[ $EUID -eq 0 ]]; then
  echo "This script doesn't work properly if it used with root user." 1>&2
  exit 1
fi

echo "*************************************************"
echo "This script will set a LAMP dev environment."
echo "It comes with no warranty at all and has been tested only twice on Ubuntu 14.04"
echo "It should work on all ubuntu variants and maybe on debian"
echo "Use it at your own risk."
echo "*************************************************"
read -p "Press [Enter] to continue or Ctrl + C to exit..."

# Install packages
echo $'\n=== Installing LAMP packages ==='
read -p "Do you want to install apache2 + PHP + MySQL packages? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Installing Apache2 + PHP + MySQL"
  sudo apt-get install -y apache2 php5-fpm php5-mysql php5-apcu apache2-mpm-event mysql-server php5-cli curl php5-gd libapache2-mod-php5
fi

echo $'\n\n=== Apache2 FQDN ==='
echo "Apache2 will complain about the FQDN not defined"
echo "Here you can define the default ServerName"
read -p "Do you want to configure apache2 ServerName? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Configuring Apache2 ServerName file"
  # Configuring ServerName
  echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf
  sudo a2enconf servername
fi

echo $'\n\n=== Apache2 Mods ==='
read -p "Do you want to enable apache2 mods? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "Enter the modules you want to enable (if you leave it empty, it will enable rewrite, actions and alias)"
  read -p "Module list (separate with spaces): " modulelist
  if [ "${modulelist}" == "" ]; then
    echo ""
    echo "Enabling default modules"
    sudo a2enmod rewrite actions alias
    sudo service apache2 restart
  else
    echo ""
    echo "* Enabling $modulelist"
    sudo a2enmod $modulelist    
    sudo service apache2 restart
  fi
fi


echo $'\n\n=== User permission ==='
echo "if you add your user to the www-data group, it will be easier to"
echo "edit files in /var/www."
read -p "Do you want to add your user to www-data group? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Adding $USER to www-data group"
  # Adding user to www-data group
  sudo usermod -a -G www-data $USER
fi

echo ""
echo $'\n\n=== Local domain setup & virtualhost ==='
echo "Here you can setup a local domain (like mydev.local)"
echo "and configure an Apache2 virtualhost that points to it."
echo " - It adds 1 line in /etc/hosts"
echo " - It creates a directory in /var/www"
echo " - It creates an apache config file in /etc/apache2/sites-available"
echo " - It enables the site with a2ensite"
echo "You can define as many as you want, but be sure their names are unique."
while :
do
  echo ""
  read -p "Do you want to setup a new local domain? (y/n)" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter the local domain (e.g. drupal.local):" localdomain
    if [ "${localdomain}" == "" ]; then
        echo ""
        echo "Error: empty local domain"
    else
      echo ""
      echo "* Modifying /etc/hosts"
      cat /etc/hosts | head -n +1 > /tmp/hosts.tmp # We remove the first line
      echo "127.0.0.1	$localdomain" >> /tmp/hosts.tmp # We add our line
      cat /etc/hosts | tail -n +2 >> /tmp/hosts.tmp # We add the rest of the lines
      sudo mv /tmp/hosts.tmp /etc/hosts # We replace the original file

      # We get local folder (e.g. local domain is 
      localfolder=$(echo $localdomain| cut -d'.' -f 1)
      echo "* Creating /var/www/$localfolder and setting right permissions"
      sudo mkdir /var/www/$localfolder
      # Definicion de los permisos
      sudo chown -R www-data:www-data /var/www/$localfolder
      sudo chmod 770 /var/www/$localfolder

      # Instalación de los archivos de configuración de apache
      echo "* Configuring apache"
      if [ ! -f ./default.local.conf ]; then
        echo ""
        echo "Error! file default.local.conf NOT FOUND !"
      else
        sudo cp ./default.local.conf /tmp/$localdomain.conf
        
        # Editind conf file
        sudo sed -i "s/LOCALDOMAIN/$localdomain/g" /tmp/$localdomain.conf
        sudo sed -i "s/LOCALFOLDER/$localfolder/g" /tmp/$localdomain.conf
        # Setting apache2 conf file
        sudo mv /tmp/$localdomain.conf /etc/apache2/sites-available/
        sudo a2ensite $localdomain.conf
        sudo service apache2 restart
      fi

      # Creando Links en el escritorio
      echo ""
      read -p "Do you want to add a link to /var/www/$localfolder on your desktop? (y/n)" -n 1 -r
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
        echo ""
        echo "* Adding link"
        desktop_dir=$(xdg-user-dir DESKTOP)
        ln -s /var/www/$localfolder $desktop_dir/$localfolder
      fi
    fi
  else
    break
  fi
done

# Drush install
echo $'\n\n=== Drush ==='
read -p "Do you want to install Drush? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Installing Drush"
  cd ~
  curl -sS https://getcomposer.org/installer | php
  sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $HOME/.bashrc
  source $HOME/.bashrc
  php composer.phar global require drush/drush:6.*
fi

# Instalación del servidor email
echo $'\n\n=== Postfix ==='
read -p "Do you want to install Postfix (mail server)? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Installing Postfix (mail server needed to send email through PHP)"
  echo "On the next screen chose 'Internet Website' and leave the name by default (or configure it as you want)"
  read -p "Press [Enter] to continue..."
  sudo apt-get install -y postfix
  # Añadido como relay del servidor smtp de la UPV
  echo ""
  echo "You can define a relayhost to send your emails through another smtp server."
  echo "It must be like [smtp.example.com]:port (e.g. \"[smtp.upv.es]:25\")"
  echo "Leave it empty if you don't want to define any."
  read -p "Relayhost :" relayhost
  if [ "${relayhost}" == "" ]; then
    echo ""
    echo "No relayhost defined"
  else
    echo ""
    echo "* Setting $relayhost"
    sudo postconf -e 'relayhost=$relayhost'
  fi
fi

# Instalación de GIT
echo $'\n\n=== Git ==='
read -p "Do you want to install git? (y/n)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "* Installing git"
  sudo apt-get install -y git
  echo ""
  echo "* Configuring git"
  git config --global color.ui true
  git config --global color.status auto
  git config --global color.branch auto 
  git config --global core.editor nano
  git config --global push.default simple

  echo "Git: enter your name: "
  read nombre
  git config --global user.name "$nombre"
  echo "Git: enter your email address: "
  read email
  git config --global user.email "$email"
fi

if [ ! -f ~/.ssh/id_rsa.pub ]; then
  echo $'\n\n=== SSH Key ==='
  read -p "Do you want to create your SSH key (useful if you will use remote repository like github)? (y/n)" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo ""
    echo "Leave all the default options if you don't know what they mean"
    ssh-keygen -t rsa -C "$email"
    echo "Your SSH key is: (useful for gitlab, github... :-)"
    echo "----------- key start --------------------"
    cat ~/.ssh/id_rsa.pub
    echo "----------- key end ----------------------"
  fi
else
  echo $'\n\n=== SSH Key ==='
  echo "You already have a SSH key. Here it is (useful for gitlab, github... :-)"
  echo "----------- key start --------------------"
  cat ~/.ssh/id_rsa.pub
  echo "----------- key end ----------------------"
fi
echo ""
echo "*** Done !! ***"
echo ""
