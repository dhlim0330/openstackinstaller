source $(dirname $0)/lib/config-parameters.sh

function install-neutron-packages-controller() {
	echo "Neutron (컨트롤러 노드) 설치..."
	sleep 1
	#apt install neutron-server neutron-plugin-ml2 neutron-l3-agent \
  		#neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent -y
	dpkg -i --force-all packages/neutron-controller/*.deb
	dpkg -i --force-all packages/neutron-openvswitch-agent/*.deb
	}

function install-cinder-packages-controller() {
	echo "Cinder (컨트롤러 노드) 설치..."
	sleep 1
	#apt install lvm2 tgt cinder-api cinder-scheduler cinder-volume -y
	dpkg -i --force-all packages/cinder/*.deb
}

function install-common-packages() {
	echo "crudini 설치..."
	#apt install crudini -y
	dpkg -i --force-all packages/crudini/*.deb
	sleep 1

	#echo "NTP 서버 설치..."
	#sleep 1
	#apt install chrony -y
	#service chrony restart
	#timedatectl set-timezone Asia/Seoul

	echo "시스템 업데이트..."
	sleep 1
	#apt update && apt upgrade -y && apt dist-upgrade -y
	dpkg -i --force-all packages/upgrade/*.deb
	apt autoremove -y
	#apt install python3-openstackclient -y
	dpkg -i --force-all packages/python3-openstackclient/*.deb
}


function install-controller-packages() {
	echo "MariaDB 설치..."
	#apt install mariadb-server python3-pymysql -y
	dpkg -i --force-all packages/mariadb/*.deb

	echo "RabbitMQ 설치..." 
	sleep 1
	#apt install rabbitmq-server -y
	dpkg -i --force-all packages/rabbitmq/*.deb
	
	echo "Keystone 설치..."
	sleep 1
	#apt install apache2 libapache2-mod-wsgi-py3 memcached python3-memcache keystone -y
	dpkg -i --force-all packages/keystone/*.deb
	
	echo "Glance 설치..."
	sleep 1
	#apt install glance -y
	dpkg -i --force-all packages/glance/*.deb

	echo "Placement 설치..."
	sleep 1
	#apt install placement-api -y
	dpkg -i --force-all packages/placement-api/*.deb
	
	echo "Nova (컨트롤러 노드) 설치..."
	sleep 1
	#apt install nova-api nova-conductor nova-novncproxy nova-scheduler -y
	dpkg -i --force-all packages/nova-controller/*.deb

	install-neutron-packages-controller
	
	echo "Horizon 설치..."
	sleep 1
	#apt install openstack-dashboard -y
	dpkg -i --force-all packages/openstack-dashboard/*.deb
	
	install-cinder-packages-controller 

	if [ "$install_masakari" == "true" ]
	then
		install-masakari-packages-controller
	fi

	echo "autoremove 진행..."
	sleep 1
	apt autoremove -y
}

function install-compute-packages() {
	echo "Nova (컴퓨트 노드) 설치..."
	sleep 1
	#apt install nova-compute sysfsutils -y
	dpkg -i --force-all packages/nova-compute/*.deb

	echo "Neutron (컴퓨트 노드) 설치..."
	sleep 1
	#apt install neutron-openvswitch-agent -y
	dpkg -i --force-all packages/neutron-openvswitch-agent/*.deb

	if [ "$install_masakari" == "true" ]
	then
		install-masakari-packages-compute
	fi
	
	apt autoremove -y
}

function install-masakari-packages-controller() {
	echo "nfs 서버 설치"
	sleep 1
	dpkg -i --force-all packages/nfs-server/*.deb
	echo "Masakari 설치..."
	sleep 1
	#apt install masakari-engine masakari-api python3-masakariclient -y
	dpkg -i --force-all packages/masakari-controller/*.deb
	dpkg -i --force-all packages/masakari-dashboard/*.deb
	#apt install pcs fence-agents resource-agents -y
	dpkg -i --force-all packages/pacemaker-controller/*.deb

	echo -e "123qwe\n123qwe" | passwd hacluster
}

function install-masakari-packages-compute() {
	echo "nfs 클라이언트 설치"
	sleep 1
	dpkg -i --force-all packages/nfs-common/*.deb
	echo "Masakari 설치..."
	sleep 1
	#apt install masakari-host-monitor masakari-instance-monitor masakari-process-monitor -y
	dpkg -i --force-all packages/masakari-compute/*.deb
	#apt install pcs pacemaker-remote -y
	dpkg -i --force-all packages/pacemaker-compute/*.deb
	systemctl stop pacemaker_remote
	systemctl disable pacemaker_remote

	echo -e "123qwe\n123qwe" | passwd hacluster
}

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 [ allinone | controller | compute ] "
    exit 1;
fi

if [ "$1" == "allinone" ]
then
    echo "패키지 설치: All-in-One..."
    sleep 1
    install-common-packages
    install-controller-packages
    install-compute-packages
elif [ "$1" == "controller" ] || [ "$1" == "compute" ]
then
    install-common-packages
    echo "패키지 설치: "$1
    sleep 1
    install-$1-packages
else
	echo "올바른 형식: $0 [ allinone | controller | compute ]"
	exit 1;
fi

echo "********************************************"
echo "다음 단계:"
echo "** lib/config-paramters.sh 에서 인터페이스 이름, 패스워드 수정"
echo "** 각 노드에서 다음 커맨드 실행:"
echo "    configure.sh <controller-ip>"
echo "********************************************"