controller_host_name="controller"

# NIC 인터페이스 설정
readonly mgmt_interface="eth1"
readonly data_interface="eth0"

# Neutron 관련 설정
readonly neutron_ovs_tenant_network_type="vxlan"
readonly neutron_ovs_bridge_mappings="extnet:br-ex"
readonly neutron_ovs_bridge_address="172.16.5.27/24"

readonly default_password="123qwe"

readonly mysql_user="root"
readonly mysql_password="123qwe"

readonly rabbitmq_user="openstack"
readonly rabbitmq_password="123qwe"

readonly keystone_db_password="123qwe"

readonly glance_password="123qwe"
readonly glance_db_password="123qwe"

readonly admin_tenant_password="123qwe"

readonly placement_password="123qwe"
readonly placement_db_password="123qwe"

readonly nova_password="123qwe"
readonly nova_db_password="123qwe"

readonly neutron_password="123qwe"
readonly neutron_db_password="123qwe"

readonly cinder_password="123qwe"
readonly cinder_db_password="123qwe"
readonly cinder_vg_name="ubuntu-vg"

function echo_and_sleep() {
	if [ -z "$2" ]
	then
		sleep_time=1
	else
		sleep_time=$2
	fi

	if [ -z "$1" ]
	then
		echo_string=""
	else
		echo_string=$1
	fi
	echo "$echo_string..."
	sleep $sleep_time
}

function print_keystone_service_list() {
	echo_and_sleep "Keystone 서비스 리스트 출력" 1
	openstack service list --long
	echo_and_sleep "OpenStack 카탈로그 리스트 출력" 1
	openstack catalog list
}

function configure-keystone-authentication() {
	echo "configure-keystone-authentication 호출, 패러미터: $@"
	sleep 3
	crudini --set $1 keystone_authtoken www_authenticate_uri http://$2:5000
	crudini --set $1 keystone_authtoken auth_url http://$2:5000
	crudini --set $1 keystone_authtoken memcached_servers $2:11211
	crudini --set $1 keystone_authtoken auth_type password
	crudini --set $1 keystone_authtoken project_domain_name Default
	crudini --set $1 keystone_authtoken user_domain_name Default
	crudini --set $1 keystone_authtoken project_name service
	crudini --set $1 keystone_authtoken username $3
	crudini --set $1 keystone_authtoken password $4
}

function configure-oslo-messaging() {
	echo "configure-oslo-messaging 호출, 패러미터: $@"
	sleep 1
	crudini --set $1 oslo_messaging_rabbit rabbit_host $2
	crudini --set $1 oslo_messaging_rabbit rabbit_userid $3
	crudini --set $1 oslo_messaging_rabbit rabbit_password $4
}

function create-user-service() {
	echo "create-user-service 호출, 패러미터: $@"
	sleep 1
	openstack user create --domain default --password $2 $1
	echo_and_sleep "User $1 생성" 1
	openstack role add --project service --user $1 admin
	echo_and_sleep "Role $1 생성" 1
	openstack service create --name $3 --description $4 $5
	echo_and_sleep "Service $4 생성" 1
}

function create-api-endpoints() {
	echo "create-api-endpoints 패러미터: $@"
	sleep 1
	echo_and_sleep "public 엔드포인트 생성" 1
	openstack endpoint create --region RegionOne $1 public $2
	echo_and_sleep "internal 엔드포인트 생성" 1
	openstack endpoint create --region RegionOne $1 internal $2
	echo_and_sleep "admin 엔드포인트 생성" 1
	openstack endpoint create --region RegionOne $1 admin $2
}

function get-ip-address() {
	ip_address_val=''
	ip_address_val=`ifconfig $1 | grep 'inet ' | cut -d' ' -f10 | awk '{ print $1}'`
	echo $ip_address_val
}