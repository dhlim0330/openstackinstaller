echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 6 ]
then
	echo "올바른 구문: $0 <controller-host-name> <rabbitmq-password> <cinder-password> <cinder-db-password> <mysql-username> <mysql-password>"
	exit 1
fi

echo_and_sleep "MySQL 설정 (Cinder)"
mysql_command="CREATE DATABASE IF NOT EXISTS cinder; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$4'; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$4';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$5" -p"$6" -e "$mysql_command"

echo_and_sleep "source admin-openrc.sh"
source $(dirname $0)/admin-openrc.sh

create-user-service cinder $3 cinder OpenStackVolume volumev3

echo_and_sleep "Cinder 서비스 엔드포인트 생성"
create-api-endpoints volumev3 http://$1:8776/v3/%\(project_id\)s

echo_and_sleep "Cinder 설정"
crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://openstack:$2@$1
crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:$4@$1/cinder
configure-keystone-authentication /etc/cinder/cinder.conf $1 cinder $3
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp


crudini --set /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set /etc/cinder/cinder.conf lvm volume_group cinder-volumes
crudini --set /etc/cinder/cinder.conf lvm target_protocol iscsi
crudini --set /etc/cinder/cinder.conf lvm target_helper tgtadm

echo_and_sleep "Cinder 서비스 DB 초기화" 
cinder-manage db sync

echo_and_sleep "Cinder 서비스 재시작" 1
service cinder-scheduler restart
service nova-api restart

echo_and_sleep "Cinder MySQL-Lite DB 삭제" 
rm -f /var/lib/cinder/cinder.sqlite

print_keystone_service_list