#/bin/bash
clear
echo "Do you want to install required dependencies?  (Select no if you have done this before) [y/n]"
read DOSETUP

if [[ $DOSETUP =~ "y" ]] ; then
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
  sudo apt-get install -y nano htop git curl
  sudo apt-get install unzip

  cd /var
  sudo touch swap.img
  sudo chmod 600 swap.img
  sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=4000
  sudo mkswap /var/swap.img
  sudo swapon /var/swap.img
  sudo free
  sudo echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  cd
  mkdir -p ~/bin
  echo 'export PATH=~/bin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
fi
  
echo "Do you want to compile Daemon (please choose no if you did it before)? [y/n]"
read DOSETUPTWO

if [[ $DOSETUPTWO =~ "y" ]] ; then

  quantisnet-cli stop > /dev/null 2>&1
  
  wget https://github.com/QuantisDev/QuantisNet-Core/releases/download/v2.2.0/quantisnetcore-2.2.0-x86_64-linux-gnu.tar.gz
  tar -xvzf quantisnetcore-2.2.0-x86_64-linux-gnu.tar.gz
	
  mv quantisnetcore-2.2.0/bin/quantisnet* /usr/local/bin
  mv quantisnetcore-2.2.0/bin/test_quantisnet /usr/local/bin
  mv quantisnetcore-2.2.0/include/quantis* /usr/local/include
  mv quantisnetcore-2.2.0/lib/libquantis* /usr/local/lib
  mv quantisnetcore-2.2.0/share/man/man1 /usr/local/share/man/
  rm -r quantisnetcore-2.2.0
  rm quantisnetcore-2.2.0-x86_64-linux-gnu.tar.gz
chmod +x /usr/local/bin/quantisnet*
fi

echo ""
echo "Configuring IP - Please Wait......."

declare -a NODE_IPS
for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
do
  NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
done

if [ ${#NODE_IPS[@]} -gt 1 ]
  then
    echo -e "More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
    INDEX=0
    for ip in "${NODE_IPS[@]}"
    do
      echo ${INDEX} $ip
      let INDEX=${INDEX}+1
    done
    read -e choose_ip
    IP=${NODE_IPS[$choose_ip]}
else
  IP=${NODE_IPS[0]}
fi

echo "IP Done"
echo ""
echo "Enter masternode private key for node $ALIAS , Go To your Windows Wallet Tools > Debug Console , Type masternode genkey"
read PRIVKEY

CONF_DIR=~/.quantisnetcore/
CONF_FILE=quantisnet.conf
SENT_CONF=sentinel.conf
PORT=9801

mkdir -p $CONF_DIR
echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` > $CONF_DIR/$CONF_FILE
echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> $CONF_DIR/$CONF_FILE
echo "rpcallowip=127.0.0.1" >> $CONF_DIR/$CONF_FILE
echo "rpcport=9797" >> $CONF_DIR/$CONF_FILE
echo "listen=1" >> $CONF_DIR/$CONF_FILE
echo "server=1" >> $CONF_DIR/$CONF_FILE
echo "daemon=1" >> $CONF_DIR/$CONF_FILE
echo "logtimestamps=1" >> $CONF_DIR/$CONF_FILE
echo "masternode=1" >> $CONF_DIR/$CONF_FILE
echo "port=$PORT" >> $CONF_DIR/$CONF_FILE
echo "masternodeaddr=$IP:$PORT" >> $CONF_DIR/$CONF_FILE
echo "masternodeprivkey=$PRIVKEY" >> $CONF_DIR/$CONF_FILE

echo "Do you want to install sentinel?  (Required for rewards and governance) [y/n]"
read DOSETUPTHREE

function conf_set_value() {
	# <$1 = conf_file> | <$2 = key> | <$3 = value> | [$4 = force_create]
	#[[ $(grep -ws "^$2" "$1" | cut -d "=" -f1) == "$2" ]] && sed -i "/^$2=/s/=.*/=$3/" "$1" || ([[ "$4" == "1" ]] && echo -e "$2=$3" >> $1)
	local key_line=$(grep -ws "^$2" "$1")
	[[ "$(echo $key_line | cut -d '=' -f1)" =~ "$2" ]] && sed -i "/^$2/c $(echo $key_line | grep -oP '^[\s\S]{0,}=[\s]{0,}')$3" $1 || $([[ "$4" == "1" ]] && echo -e "$2=$3" >> $1)
}
function conf_get_value() {
	# <$1 = conf_file> | <$2 = key> | [$3 = limit]
	[[ "$3" == "0" ]] && grep -ws "^$2" "$1" | cut -d "=" -f2 || grep -ws "^$2" "$1" | cut -d "=" -f2 | head $([[ ! $3 ]] && echo "-1" || echo "-$3")
}

if [[ $DOSETUPTHREE =~ "y" ]] ; then
  cd $CONF_DIR
  sudo apt-get update
  sudo apt-get -y install python-virtualenv
  sudo apt-get -y install virtualenv
  user="$(whoami)"
  git clone https://github.com/QuantisDev/sentinel && cd sentinel
  sudo virtualenv ./venv
  sudo ./venv/bin/pip install -r requirements.txt
  srcdir="$(pwd)"
  $(conf_set_value $CONF_DIR/sentinel/sentinel.conf "quantisnet_conf"           "${CONF_DIR}quantisnet.conf" 1)
  
  #write out current crontab
  crontab -l > mycron
  #echo new cron into cron file
  echo "* * * * * cd ${srcdir} && sudo ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> mycron
  #install new cron file
  crontab mycron
  rm mycron

fi

echo ""
echo "##########################"
echo "YOUR IP = $IP:$PORT"
echo "YOUR PRIVKEY = $PRIVKEY"
echo "##########################" 
echo ""
killall -9 quantisnetd
sleep 20
quantisnetd -daemon
