controller_host_name="controller"

# NIC 인터페이스 설정
readonly mgmt_interface="eth1"
readonly data_interface="eth0"

# Neutron 관련 설정
readonly neutron_ovs_tenant_network_type="vxlan"
readonly neutron_ovs_bridge_mappings="extnet:br-$data_interface"

readonly mysql_user="root"
readonly mysql_password="Passw0rd1"

readonly rabbitmq_user="openstack"
readonly rabbitmq_password="Passw0rd1"

readonly keystone_db_password="Passw0rd1"

readonly glance_password="Passw0rd1"
readonly glance_db_password="Passw0rd1"

readonly admin_tenant_password="Passw0rd1"

readonly placement_password="Passw0rd1"
readonly placement_db_password="Passw0rd1"

readonly nova_password="Passw0rd1"
readonly nova_db_password="Passw0rd1"

readonly neutron_password="Passw0rd1"
readonly neutron_db_password="Passw0rd1"

readonly cinder_password="Passw0rd1"
readonly cinder_db_password="Passw0rd1"

function echo_and_sleep() {
	if [ -z "$2" ]
		then
			sleep_time=2
		else
			sleep_time=$2
	fi

	if [ -z "$1" ]
		then
			echo_string=""$sleep_time"초 sleep..."
		else
			echo_string=$1
	fi
	echo "$echo_string, "$sleep_time"초 sleep..."
	sleep $sleep_time
}

function print_keystone_service_list() {
	echo_and_sleep "Keystone 서비스 리스트 출력" 2
	openstack service list --long
	echo_and_sleep "OpenStack 카탈로그 리스트 출력" 2
	openstack catalog list
	echo_and_sleep "카탈로그 리스트 출력 완료" 2
}

function configure-keystone-authentication() {
	echo "Called configure-keystone-authentication with paramters: $@"
	sleep 3
	crudini --set $1 keystone_authtoken auth_uri http://$2:5000
	crudini --set $1 keystone_authtoken memcached_servers $2:11211
	crudini --set $1 keystone_authtoken auth_type password
	crudini --set $1 keystone_authtoken project_domain_name default
	crudini --set $1 keystone_authtoken user_domain_name default
	crudini --set $1 keystone_authtoken project_name service
	crudini --set $1 keystone_authtoken username $3
	crudini --set $1 keystone_authtoken password $4
}

function configure-oslo-messaging() {
	echo "Called configure-oslo-messaging with paramters: $@"
	sleep 3
	crudini --set $1 oslo_messaging_rabbit rabbit_host $2
	crudini --set $1 oslo_messaging_rabbit rabbit_userid $3
	crudini --set $1 oslo_messaging_rabbit rabbit_password $4
}

function create-user-service() {
	echo "Called create-user-service with paramters: $@"
	sleep 3
	openstack user create --domain default --password $2 $1
	echo_and_sleep "Created User $1" 2
	openstack role add --project service --user $1 admin
	echo_and_sleep "Created Role $1" 2
	openstack service create --name $3 --description $4 $5
	echo_and_sleep "Created Service $4" 2
}

function create-api-endpoints() {
	echo "Called create-api-endpoints with parameters: $@"
	sleep 5
	openstack endpoint create --region RegionOne $1 public $2
	echo_and_sleep "Created public endpoint" 2
	openstack endpoint create --region RegionOne $1 internal $2
	echo_and_sleep "Created internal endpoint" 2
	openstack endpoint create --region RegionOne $1 admin $2
	echo_and_sleep "Created admin endpoint" 2
}

function get-ip-address() {
        ip_address_val=''
        ip_address_val=`ifconfig $1 | grep 'inet ' | cut -d' ' -f10 | awk '{ print $1}'`
        echo $ip_address_val
}