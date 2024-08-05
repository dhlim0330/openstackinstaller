echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ "$1" != "controller" ] && [ "$1" != "compute" ]
	then
		echo "올바른 구문: $0 [ controller | compute ] <controller-host-name> <nova-password> <rabbitmq-password> <nova-db-password> <mysql-username> <mysql-password>"
		exit 1;
fi

if [ "$1" == "controller" ] && [ $# -ne 7 ]
	then
		echo "올바른 구문: $0 controller <controller-host-name> <nova-password> <rabbitmq-password> <nova-db-password> <mysql-username> <mysql-password>"
		exit 1;
fi
		
if [ "$1" == "compute" ] && [ $# -ne 4 ]
	then
		echo "올바른 구문: $0 compute <controller-host-name> <nova-password> <rabbitmq-password>"
		exit 1;
fi
		
source $(dirname $0)/admin-openrc.sh

if [ "$1" == "controller" ]
	then
		echo "MySQL 설정: Nova API..."
		mysql_command="CREATE DATABASE IF NOT EXISTS nova_api; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$5'; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$5';"
		echo "MySQL 커맨드:: "$mysql_command
		mysql -u "$6" -p"$7" -e "$mysql_command"
		
		echo "MySQL 설정: Nova..."
		mysql_command="CREATE DATABASE IF NOT EXISTS nova; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$5'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$5';"
		echo "MySQL 커맨드:: "$mysql_command
		mysql -u "$6" -p"$7" -e "$mysql_command"
		
		echo_and_sleep "MySQL 설정: Nova Cells..." 2
		mysql_command="CREATE DATABASE IF NOT EXISTS nova_cell0; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$5'; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$5';"
		echo "MySQL 커맨드:: "$mysql_command 
		mysql -u "$6" -p"$7" -e "$mysql_command"

		create-user-service nova $3 nova OpenStackCompute compute
		
		create-api-endpoints compute http://$2:8774/v2.1
		echo_and_sleep "Nova 엔드포인트 생성 완료" 1
		
		crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:$5@$2/nova_api
		crudini --set /etc/nova/nova.conf database connection mysql+pymysql://nova:$5@$2/nova
		echo_and_sleep "Nova DB 연결 완료" 1

fi

echo_and_sleep "Nova 설정 파일 업데이트" 1
crudini --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:$4@$2
crudini --set /etc/nova/nova.conf api auth_strategy keystone
configure-keystone-authentication /etc/nova/nova.conf $2 nova $3

mgmt_interface_ip=$(get-ip-address $mgmt_interface)
echo "관리 인터페이스 IP: $mgmt_interface_ip"
sleep 2
crudini --set /etc/nova/nova.conf DEFAULT my_ip $mgmt_interface_ip
crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf vnc server_proxyclient_address $mgmt_interface_ip

crudini --set /etc/nova/nova.conf placement os_region_name RegionOne
crudini --set /etc/nova/nova.conf placement project_domain_name Default
crudini --set /etc/nova/nova.conf placement project_name service
crudini --set /etc/nova/nova.conf placement auth_type password
crudini --set /etc/nova/nova.conf placement user_domain_name Default
crudini --set /etc/nova/nova.conf placement auth_url http://$2:5000/v3
crudini --set /etc/nova/nova.conf placement username placement
crudini --set /etc/nova/nova.conf placement password $4

if [ "$1" == "controller" ]
	then
		crudini --set /etc/nova/nova.conf vnc server_listen $mgmt_interface_ip
elif [ "$1" == "compute" ]
	then
		controller_ip=`getent hosts $2 | awk '{ print $1 }'`
		echo_and_sleep "컨트롤러 노드 IP: $controller_ip" 1
		crudini --set /etc/nova/nova.conf vnc enabled True
		crudini --set /etc/nova/nova.conf vnc server_listen 0.0.0.0
		crudini --set /etc/nova/nova.conf vnc novncproxy_base_url http://$controller_ip:6080/vnc_auto.html

		crudini --set /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 10
fi

crudini --set /etc/nova/nova.conf glance api_servers http://$2:9292
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
echo_and_sleep "Nova 설정 파일 업데이트 완료" 1

if [ "$1" == "controller" ]
	then
		echo_and_sleep "Nova 데이터베이스 초기화" 1
		nova-manage api_db sync
		echo_and_sleep "Nova Cells 매핑" 1
		nova-manage cell_v2 map_cell0
		echo_and_sleep "Cell 생성" 1
		nova-manage cell_v2 create_cell --name=cell1 --verbose
		nova-manage db sync
		echo_and_sleep "Nova 서비스 재시작" 1
		service nova-api restart
		service nova-scheduler restart
		service nova-conductor restart
		service nova-novncproxy restart
elif [ "$1" == "compute" ]
	then
		echo "Nova 서비스 재시작"
		service nova-compute restart
fi

echo_and_sleep "Nova MySQL-Lite 데이터베이스 삭제" 1
rm -f /var/lib/nova/nova.sqlite

if [ "$1" == "controller" ]
	then
		print_keystone_service_list
		nova service-list
		echo_and_sleep "Nova Cells 리스트 출력" 1
		nova-manage cell_v2 list_cells
		echo_and_sleep "Nova 서비스 리스트 확인"
fi