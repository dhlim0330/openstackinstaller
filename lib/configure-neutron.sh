echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh
source $(dirname $0)/admin-openrc.sh

if [ "$1" != "compute" -a "$1" != "networknode" -a "$1" != "controller" ]
	then
		echo "노드 타입 오류: $1"
		echo "올바른 구문: $0 [ controller | compute | networknode ]  <controller-host-name> <rabbitmq-password> <neutron-password> <neutron-db-password> <mysql-username> <mysql-password>"
		exit 1;
fi

if [ "$1" == "controller" ] && [ $# -ne 7 ]
        then
		echo "올바른 구문: $0 controller <controller-host-name> <rabbitmq-password> <neutron-password> <neutron-db-password> <mysql-username> <mysql-password>"
                exit 1;
elif [ "$1" == "compute" ] || [ "$1" == "networknode" ] && [ $# -ne 4 ]
	then
		echo "올바른 구문: $0 [ compute | networknode ] <controller-host-name> <rabbitmq-password> <neutron-password>"
		exit 1;
fi

if [ "$1" == "controller" ]
	then
		echo "MySQL 설정 (Neutron)..."
mysql_command="CREATE DATABASE IF NOT EXISTS neutron; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$5'; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$5';"
		echo "MySQL Command is:: "$mysql_command
		mysql -u "$6" -p"$7" -e "$mysql_command"

		create-user-service neutron $4 neutron OpenStackNetworking network
		
		create-api-endpoints network http://$2:9696
		
		echo_and_sleep "Neutron 엔드포인트 생성 완료, Neutron Conf 파일 수정" 1
		crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:$5@$2/neutron

		echo_and_sleep "Configuring Neutron Conf File" 1
		crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
		crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
		crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
fi

echo_and_sleep "RabbitMQ config changed for Newton" 1
crudini --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:$3@$2

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
configure-keystone-authentication /etc/neutron/neutron.conf $2 neutron $4

crudini --set /etc/neutron/neutron.conf DEFAULT verbose True

if [ "$1" == "networknode" -o "$1" == "controller" ]
	then
		crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
		crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
		crudini --set /etc/neutron/neutron.conf DEFAULT nova_url http://$2:8774/v2.1

		crudini --set /etc/neutron/neutron.conf nova auth_url http://$2:5000/
		crudini --set /etc/neutron/neutron.conf nova auth_type password
		crudini --set /etc/neutron/neutron.conf nova project_domain_name Default
		crudini --set /etc/neutron/neutron.conf nova user_domain_name Default
		crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
		crudini --set /etc/neutron/neutron.conf nova project_name service
		crudini --set /etc/neutron/neutron.conf nova username nova
		crudini --set /etc/neutron/neutron.conf nova password $4

		echo_and_sleep "ML2 ini 파일 수정"
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
		
		echo_and_sleep "openvswitch_agent.ini 파일 수정"
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings $neutron_ovs_bridge_mappings
        mgmt_interface_ip=$(get-ip-address $mgmt_interface)
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $mgmt_interface_ip
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group True
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver openvswitch

		echo_and_sleep "L3 Agent 설정" 1
		crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver openvswitch
		
		echo_and_sleep "DHCP Agent 설정" 1
		crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver openvswitch
		crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
		crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enabled_isolated_metadata True
		
		echo_and_sleep "Metadata Agent 설정" 1
		crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host $1
		crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $3
fi

if [ "$1" == "compute" ]
	then
        echo_and_sleep "openvswitch_agent.ini 파일 수정"
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings $neutron_ovs_bridge_mappings
        mgmt_interface_ip=$(get-ip-address $mgmt_interface)
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $mgmt_interface_ip
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group True
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver openvswitch
fi

if [ "$1" == "compute" -o "$1" == "controller" ]
	then
		echo_and_sleep "Nova conf 파일의 Neutron 항목 설정" 2
		crudini --set /etc/nova/nova.conf neutron url http://$2:9696
		crudini --set /etc/nova/nova.conf neutron auth_url http://$2:5000
		crudini --set /etc/nova/nova.conf neutron auth_type password
		crudini --set /etc/nova/nova.conf neutron project_domain_name default
		crudini --set /etc/nova/nova.conf neutron user_domain_name default
		crudini --set /etc/nova/nova.conf neutron region_name RegionOne
		crudini --set /etc/nova/nova.conf neutron project_name service
		crudini --set /etc/nova/nova.conf neutron username neutron
		crudini --set /etc/nova/nova.conf neutron password $4
		crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
		crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $4

fi
		
if [ "$1" == "controller" ]
	then
		echo_and_sleep "ML2 보안 그룹 설정 완료. Neutron DB 업그레이드..."
		neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
		echo_and_sleep "서비스 재시작..."
		service nova-api restart
		service neutron-server restart
		service neutron-openvswitch-agent restart
		service neutron-l3-agent restart
		service neutron-dhcp-agent restart
		service neutron-metadata-agent restart
		service nova-scheduler restart
		service nova-conductor restart
		print_keystone_service_list
		openstack network agent list
		echo_and_sleep "Neutron Agent 리스트 출력" 1
		rm -f /var/lib/neutron/neutron.sqlite
elif [ "$1" == "compute" ]
	then
		service nova-compute restart
		service neutron-openvswitch-agent restart
elif [ "$1" == "networknode" ]
	then
		service neutron-openvswitch-agent restart
		service neutron-l3-agent restart
		service neutron-dhcp-agent restart
		service neutron-metadata-agent restart
fi