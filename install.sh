function install-neutron-packages-controller() {
	echo "Neutron (컨트롤러 노드) 설치..."
	sleep 1
	apt-get install neutron-server neutron-plugin-ml2 neutron-l3-agent \
  		neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent -y
}

function install-cinder-packages-controller() {
	echo "Cinder (컨트롤러 노드) 설치..."
	sleep 1
	apt-get install tgt cinder-api cinder-scheduler cinder-volume -y
}

function install-common-packages() {
	echo "crudini 설치..."
	apt-get install crudini -y
	sleep 1

	echo "NTP 서버 설치..."
	sleep 1
	apt-get install chrony -y
	service chrony restart
	timedatectl set-timezone Asia/Seoul

	echo "시스템 업데이트..."
	sleep 1
	apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y
	apt-get autoremove -y
	apt-get install python3-openstackclient -y
}


function install-controller-packages() {
	echo "MariaDB 설치..."
	apt-get install mariadb-server python3-pymysql -y

	echo "RabbitMQ 설치..." 
	sleep 1
	apt-get install rabbitmq-server -y
	
	echo "Keystone 설치..."
    #Keystone 자동 시작 방지
    #echo "manual" > /etc/init/keystone.override
	sleep 1
	apt-get install apache2 libapache2-mod-wsgi-py3 memcached python3-memcache keystone -y
	
	echo "Glance 설치..."
	sleep 1
	apt-get install glance -y

	echo "Placement 설치..."
	sleep 1
	apt-get install placement-api -y
	
	echo "Nova (컨트롤러 노드) 설치..."
	sleep 1
	apt-get install nova-api nova-conductor nova-novncproxy nova-scheduler -y

	install-neutron-packages-controller
	
	echo "Horizon 설치..."
	sleep 1
	apt-get install openstack-dashboard -y
	
	install-cinder-packages-controller 

	echo "네트워크 노드 컴포넌트 설치..."
	sleep 1
	install-networknode-packages

	echo "autoremove 진행..."
	sleep 1
	apt-get autoremove -y
}

function install-networknode-packages() {
	echo "Neutron (네트워크 노드) 설치..."
	sleep 1
	apt-get install neutron-server neutron-plugin-ml2 neutron-l3-agent \
  		neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent -y
	apt-get autoremove -y
}

function install-compute-packages() {
	echo "Nova (컴퓨트 노드) 설치..."
	sleep 1
	apt-get install nova-compute sysfsutils -y

	echo "Neutron (컴퓨트 노드) 설치..."
	sleep 1
	apt-get install neutron-openvswitch-agent -y
	
	apt-get autoremove -y
}

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 [ allinone | controller | compute | networknode ] "
    exit 1;
fi

if [ "$1" == "allinone" ]
then
    echo "패키지 설치: All-in-One..."
    sleep 1
    install-common-packages
    install-controller-packages
    install-compute-packages
    install-networknode-packages
elif [ "$1" == "controller" ] || [ "$1" == "compute" ] || [ "$1" == "networknode" ]
then
    install-common-packages
    echo "패키지 설치: "$1
    sleep 1
    install-$1-packages
else
	echo "올바른 형식: $0 [ allinone | controller | compute | networknode ]"
	exit 1;
fi

echo "********************************************"
echo "다음 단계:"
echo "** lib/config-paramters.sh 에서 인터페이스 이름, 패스워드 수정"
echo "** 각 노드에서 다음 커맨드 실행:"
echo "    configure.sh <controller-ip>"
echo "********************************************"