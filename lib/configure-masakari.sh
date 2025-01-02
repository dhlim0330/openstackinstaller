echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ "$1" != "controller" ] && [ "$1" != "compute" ]
then
	echo "올바른 구문 1: $0 controller <controller-host-name> <masakari-password> <rabbitmq-password> <masakari-db-password> <mysql-username> <mysql-password>"
	echo "올바른 구문 2: $0 compute <controller-host-name> <masakari-password> <rabbitmq-password>"
	exit 1;
fi

if [ "$1" == "controller" ] && [ $# -ne 7 ]
then
	echo "올바른 구문: $0 controller <controller-host-name> <masakari-password> <rabbitmq-password> <masakari-db-password> <mysql-username> <mysql-password>"
	exit 1;
fi
		
if [ "$1" == "compute" ] && [ $# -ne 4 ]
then
	echo "올바른 구문: $0 compute <controller-host-name> <masakari-password> <rabbitmq-password>"
	exit 1;
fi
		
source $(dirname $0)/admin-openrc.sh

if [ "$1" == "controller" ]
then
	echo_and_sleep "MySQL 설정: Masakari"
	mysql_command="CREATE DATABASE IF NOT EXISTS masakari; GRANT ALL PRIVILEGES ON masakari.* TO 'masakari'@'localhost' IDENTIFIED BY '$5'; GRANT ALL PRIVILEGES ON masakari.* TO 'masakari'@'%' IDENTIFIED BY '$5';"
	echo "MySQL 커맨드:: "$mysql_command
	mysql -u "$6" -p"$7" -e "$mysql_command"

	create-user-service masakari $3 masakari OpenStackHA instance-ha
    openstack role add --user masakari --project service service
	
	echo_and_sleep "Masakari 엔드포인트 생성" 1
	create-api-endpoints instance-ha http://$2:15868/v1/%\(tenant_id\)s
	
	echo_and_sleep "Masakari DB 연결" 1
	crudini --set /etc/masakari/masakari.conf database connection mysql+pymysql://masakari:$5@$2/masakari

    echo_and_sleep "Masakari Conf 설정" 1
    crudini --set /etc/masakari/masakari.conf DEFAULT transport_url rabbit://openstack:$4@$2
    crudini --set /etc/masakari/masakari.conf DEFAULT graceful_shutdown_timeout 5 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_privileged_user_tenant service  
    crudini --set /etc/masakari/masakari.conf DEFAULT os_privileged_user_name nova 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_privileged_user_password 123qwe 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_privileged_user_auth_url http://controller:5000 
    crudini --set /etc/masakari/masakari.conf DEFAULT use_syslog false 
    crudini --set /etc/masakari/masakari.conf DEFAULT debug false 
    crudini --set /etc/masakari/masakari.conf DEFAULT masakari_api_workers 2 
    crudini --set /etc/masakari/masakari.conf DEFAULT log_file /var/log/masakari/masakari-api.log 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_region_name RegionOne 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_user_domain_name default 
    crudini --set /etc/masakari/masakari.conf DEFAULT os_project_domain_name default 
    crudini --set /etc/masakari/masakari.conf DEFAULT wait_period_after_service_update 10

    configure-keystone-authentication /etc/masakari/masakari.conf $2 masakari $3
    crudini --set /etc/masakari/masakari.conf keystone_authtoken service_token_roles service
    crudini --set /etc/masakari/masakari.conf keystone_authtoken service_token_roles_required True

    crudini --set /etc/masakari/masakari.conf instance_failure process_all_instances true 
    crudini --set /etc/masakari/masakari.conf oslo_messaging_amqp ssl false 
    crudini --set /etc/masakari/masakari.conf oslo_messaging_notification driver log 
    crudini --set /etc/masakari/masakari.conf oslo_messaging_rabbit ssl false 
    crudini --set /etc/masakari/masakari.conf oslo_middleware enable_proxy_headers_parsing true 

    crudini --set /etc/masakari/masakari.conf taskflow connection mysql+pymysql://masakari:$5@$2/masakari

    mkdir -pv /etc/masakari 
    mkdir -pv /var/log/masakari
    touch /var/log/masakari/masakari-api.log
    chown masakari:masakari -Rv /var/log/masakari 
    chown masakari:masakari -Rv /etc/masakari

    
	echo_and_sleep "DB 업그레이드" 1
	masakari-manage db sync
	echo_and_sleep "Masakari 서비스 재시작" 1
	service masakari-engine restart
    systemctl restart apache2

    #cp lib/settings/masakari-api.service /lib/systemd/system/
	#systemctl enable masakari-api
    #systemctl start masakari-api
    #systemctl restart apache2

	echo_and_sleep "Masakari 대시보드 설치" 1
    cd lib/settings/masakari-dashboard
    python3 setup.py install 
    cd -
    cp lib/settings/masakari-dashboard/masakaridashboard/local/enabled/_50_masakaridashboard.py /usr/share/openstack-dashboard/openstack_dashboard/enabled/ 
    cp lib/settings/masakari-dashboard/masakaridashboard/local/local_settings.d/_50_masakari.py /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/ 
    cp lib/settings/masakari-dashboard/masakaridashboard/conf/masakari_policy.yaml /usr/share/openstack-dashboard/openstack_dashboard/conf/ 
    cd /usr/share/openstack-dashboard 
    yes yes | python3 /usr/share/openstack-dashboard/manage.py collectstatic 
    python3 /usr/share/openstack-dashboard/manage.py compress 
    systemctl restart apache2 

elif [ "$1" == "compute" ]
then
	controller_ip=`getent hosts $2 | awk '{ print $1 }'`
	echo_and_sleep "컨트롤러 노드 IP: $controller_ip" 1
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api region RegionOne 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api www_authenticate_uri http://controller:5000 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api auth_url http://controller:5000 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api service_type instance-ha 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api user_domain_id default 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api project_name service 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api project_domain_name Default 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api api_interface internal 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api username masakari 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf api password 123qwe 

    crudini --set /etc/masakarimonitors/masakarimonitors.conf host monitoring_driver default 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host monitoring_interval 60 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host disable_ipmi_check True 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host ipmi_timeout 5 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host ipmi_retry_max 3 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host ipmi_retry_interval 10 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host restrict_to_remotes True 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host stonith_wait 30 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host tcpdump_timeout 5 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host corosync_multicast_interfaces $mgmt_interface 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host corosync_multicast_ports 5405 
    crudini --set /etc/masakarimonitors/masakarimonitors.conf host pacemaker_node_type remote 

    echo_and_sleep "process.yaml 를 /etc/masakarimonitors/ 로 복사하는 중" 2
    cp $(dirname $0)/settings/process.yaml /etc/masakarimonitors/

    echo "Masakari 서비스 재시작"
	service masakari-host-monitor restart
    service masakari-instance-monitor restart
    service masakari-process-monitor restart
fi