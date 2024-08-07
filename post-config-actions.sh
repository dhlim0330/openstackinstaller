echo "실행: $0 $@"
dir_path=$(dirname $0)
node_type=`bash $dir_path/util/detect-nodetype.sh`
echo "노드 타입: $node_type"

if [ "$node_type" == "allinone" ] || [ "$node_type" == "controller" ] 
then
    echo -n "웹에서 로그를 확인할 수 있게 하시겠습니까? [y/n]: "
    read enable_web_log_view
    if [ "$enable_web_log_view" == "y" ]
    then
        mkdir /var/www/html/oslogs
        chmod a+rx /var/log/nova
        chmod a+rx /var/log/neutron
        chmod a+rx /var/log/apache2
        chmod a+rx /var/log/keystone
        ln -s /var/log/nova /var/www/html/oslogs/nova
        ln -s /var/log/neutron /var/www/html/oslogs/neutron
        ln -s /var/log/apache2 /var/www/html/oslogs/apache2
        ln -s /var/log/keystone /var/www/html/oslogs/keystone
        echo "웹 로그 url: http://<controller_ip>/oslogs"
    fi

    echo -n "기본 네트워크, 서브넷, 라우터를 생성하시겠습니까? [y/n]: "
    read setup_openstack_network
    if [ "$setup_openstack_network" == "y" ]
    then
        source $dir_path/lib/admin_openrc.sh
        echo "외부 네트워크 생성..."
        openstack network create --share --external --provider-physical-network external --provider-network-type flat external
        sleep 1
        echo "외부 네트워크 서브넷 생성..."
        openstack subnet create --network external --allocation-pool start=172.24.4.2,end=172.24.4.254 --dns-nameserver 8.8.8.8 --gateway 172.24.4.1 --subnet-range 172.24.4.0/24 external-subnet
        sleep 1
        echo "내부 네트워크 생성..."
        openstack network create selfservice
        sleep 1
        echo "내부 네트워크 서브넷 생성..."
        openstack subnet create --network selfservice --dns-nameserver 8.8.8.8 --gateway 10.0.0.1 --subnet-range 10.0.0.0/24 selfservice-subnet
        sleep 1
        echo "라우터 생성..."
        openstack router create router
        openstack router set router --external-gateway external
        sleep 1
        echo "라우터 연결..."
        openstack router add subnet router selfservice-subnet
        sleep 1
    fi
else
    echo "컨트롤러 노드에서만 사용 가능"
	exit 1
fi