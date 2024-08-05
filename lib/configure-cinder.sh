echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 6 ]
then
	echo "올바른 구문: $0 <controller-host-name> <rabbitmq-password> <cinder-password> <cinder-db-password> <mysql-username> <mysql-password>"
	exit 1
fi

echo "MySQL 설정 (Cinder)..."
mysql_command="CREATE DATABASE IF NOT EXISTS cinder; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$4'; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$4';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$5" -p"$6" -e "$mysql_command"

source $(dirname $0)/admin-openrc.sh
echo_and_sleep "Admin OpenRC 소싱 완료"

create-user-service cinder $3 cinder OpenStackVolume volume

create-api-endpoints volume http://$1:8776/v3/%\(project_id\)s
echo_and_sleep "Cinder 서비스 엔드포인트 생성 완료"

echo "Cinder 설정..."
crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://openstack:$2@$1
crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:$4@$1/cinder
configure-keystone-authentication /etc/cinder/cinder.conf $1 cinder $3
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp

echo_and_sleep "Cinder 서비스 데이터베이스 초기화" 
cinder-manage db sync

echo_and_sleep "Cinder 서비스 재시작..." 1
service cinder-scheduler restart
service nova-api restart

echo_and_sleep "Cinder MySQL-Lite 데이터베이스 삭제" 
rm -f /var/lib/cinder/cinder.sqlite

print_keystone_service_list