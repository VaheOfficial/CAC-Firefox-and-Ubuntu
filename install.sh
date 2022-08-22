echo "what is the administrator username"
read adminName
echo "what is the administrator password"
read -s adminPass
su $adminName <<EOSU
$adminPass
echo $adminPass | sudo -S apt-get install git
sudo apt-get install Build-essential
sudo apt --fix-broken install
sudo apt-get install flex
sudo apt-get install libudev1
sudo apt-get install libudev-dev
sudo apt-get install libsystemd-dev
git clone https://github.com/VaheOfficial/CAC-Firefox-and-Ubuntu.git
cd CAC-Firefox-and-Ubuntu
sudo chmod +x addcerts-firefox.sh
sudo chmod +x install-cac-firefox.sh
sudo chmod +x ubuntu.sh
sudo tar -xvjf pcsc-lite-1.9.8.tar.bz2
sudo tar -xvjf ccid-1.5.0.tar.bz2
sudo tar -xvjf libusb-1.0.26.tar.bz2
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
cd libusb-1.0.26
sudo ./configure
make
make install
cd ..
sudo ./ubuntu.sh
sudo ./install-cac-firefox.sh
sudo ./addcerts-firefox.sh
EOSU
