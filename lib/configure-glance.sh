echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 6 ]
then
	echo "올바른 구문: $0 <controller-host-name> <glance-db-password> <mysql-username> <mysql-password> <admin-tenant-password> <glance-password>"
	exit 1
fi

echo_and_sleep "MySQL 설정 (Glance)"
mysql_command="CREATE DATABASE IF NOT EXISTS glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$2'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$2';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$3" -p"$4" -e "$mysql_command"

echo_and_sleep "source admin-openrc.sh"
source $(dirname $0)/admin-openrc.sh

create-user-service glance $6 glance OpenStackImage image

echo_and_sleep "Glance 서비스 엔드포인트 생성"
create-api-endpoints image http://$1:9292

echo_and_sleep "Glance 설정"
crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:$2@$1/glance

configure-keystone-authentication /etc/glance/glance-api.conf $1 glance $6
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store stores file,http
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images

crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:$2@$1/glance

configure-keystone-authentication /etc/glance/glance-registry.conf $1 glance $6
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

echo_and_sleep "Image 서비스 DB 업그레이드" 
glance-manage db_sync

echo_and_sleep "Glance 서비스 재시작" 1
service glance-api restart

echo_and_sleep "Glance MySQL-Lite DB 삭제" 
rm -f /var/lib/glance/glance.sqlite

print_keystone_service_list