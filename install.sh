source $(dirname $0)/lib/config-parameters.sh

function install-neutron-packages-controller() {
	echo "Neutron (컨트롤러 노드) 설치..."
	sleep 1
	apt install neutron-server neutron-plugin-ml2 neutron-l3-agent \
  		neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent -y
}

function install-cinder-packages-controller() {
	echo "Cinder (컨트롤러 노드) 설치..."
	sleep 1
	apt install lvm2 tgt cinder-api cinder-scheduler cinder-volume -y
}

function install-common-packages() {
	echo "crudini 설치..."
	apt install crudini -y
	sleep 1

	echo "NTP 서버 설치..."
	sleep 1
	apt install chrony -y
	service chrony restart
	timedatectl set-timezone Asia/Seoul

	echo "시스템 업데이트..."
	sleep 1
	apt update && apt upgrade -y && apt dist-upgrade -y
	apt autoremove -y
	apt install python3-openstackclient -y
}


function install-controller-packages() {
	echo "MariaDB 설치..."
	apt install mariadb-server python3-pymysql -y

	echo "RabbitMQ 설치..." 
	sleep 1
	apt install rabbitmq-server -y
	
	echo "Keystone 설치..."
	sleep 1
	apt install apache2 libapache2-mod-wsgi-py3 memcached python3-memcache keystone -y
	
	echo "Glance 설치..."
	sleep 1
	apt install glance -y

	echo "Placement 설치..."
	sleep 1
	apt install placement-api -y
	
	echo "Nova (컨트롤러 노드) 설치..."
	sleep 1
	apt install nova-api nova-conductor nova-novncproxy nova-scheduler -y

	install-neutron-packages-controller
	
	echo "Horizon 설치..."
	sleep 1
	apt install openstack-dashboard -y
	
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
	apt install nova-compute sysfsutils -y

	echo "Neutron (컴퓨트 노드) 설치..."
	sleep 1
	apt install neutron-openvswitch-agent -y

	if [ "$install_masakari" == "true" ]
	then
		install-masakari-packages-compute
	fi
	
	apt autoremove -y
}

function install-masakari-packages-controller() {
	echo "Masakari 설치..."
	sleep 1
	apt install masakari-engine masakari-api python3-masakariclient -y
	apt install pcs fence-agents resource-agents -y

	echo -e "123qwe\n123qwe" | passwd hacluster
}

function install-masakari-packages-compute() {
	echo "Masakari 설치..."
	sleep 1
	apt install masakari-host-monitor masakari-instance-monitor masakari-process-monitor -y
	apt install pcs pacemaker pacemaker-remote -y

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