echo "what is the administrator username"
read adminName
echo "what is the administrator password"
read -s adminPass
su $adminName <<EOSU
$adminPass
echo $adminPass |sudo apt-get -y update
sudo -S apt-get install -y git
sudo apt-get install -y Build-essential
sudo apt --fix-broken -y install
sudo apt-get install -y flex
sudo apt-get install -y libudev1
sudo apt-get install -y libudev-dev
sudo apt-get install -y libsystemd-dev
sudo apt-get install -y python2.7
sudo apt-get install -y libnss3-tools
sudo apt-get install -y upgrade 
git clone https://github.com/VaheOfficial/CAC-Firefox-and-Ubuntu.git
cd CAC-Firefox-and-Ubuntu
sudo chmod +x addcerts-firefox.sh
sudo chmod +x install-cac-firefox.sh
sudo chmod +x ubuntu.sh
sudo tar -xvjf pcsc-lite-1.9.8.tar.bz2
sudo tar -xvjf ccid-1.5.0.tar.bz2
sudo tar -xvjf libusb-1.0.26.tar.bz2
cd libusb-1.0.26
sudo ./configure
make
make install
cd ..
cd pcsc-lite-1.9.8
sudo ./configure
make
make install
cd ..
cd ccid-1.5.0
sudo ./configure
make
make install
cd ..
sudo ./ubuntu.sh
./addcerts-firefox.sh
echo "In vmware horizon enter https://afrcdesktops.us.af.mil"
echo "Open Firefox and navigate to security devices in settings, load a new device with the name CAC Module and as a directory enter /home/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
EOSU

