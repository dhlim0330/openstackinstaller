echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 6 ]
	then
		echo "올바른 구문: $0 <glance-db-password> <mysql-username> <mysql-password> <controller-host-name> <admin-tenant-password> <glance-password>"
		exit 1
fi

echo "MySQL 설정 (Glance)..."
mysql_command="CREATE DATABASE IF NOT EXISTS glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$1'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$1';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$2" -p"$3" -e "$mysql_command"

source $(dirname $0)/admin_openrc.sh
echo_and_sleep "Admin OpenRC 소싱 완료"

create-user-service glance $6 glance OpenStackImage image

create-api-endpoints image http://$4:9292
echo_and_sleep "Glance 서비스 엔드포인트 생성 완료"

echo "Glance 설정..."
crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:$1@$4/glance

configure-keystone-authentication /etc/glance/glance-api.conf $4 glance $6
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store stores file,http
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images

crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:$1@$4/glance

configure-keystone-authentication /etc/glance/glance-registry.conf $4 glance $6
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

echo_and_sleep "Image 서비스 데이터베이스 초기화" 
glance-manage db_sync

echo_and_sleep "Glance 서비스 재시작..." 3
service glance-registry restart
service glance-api restart

echo_and_sleep "Glance MySQL-Lite 데이터베이스 삭제" 
rm -f /var/lib/glance/glance.sqlite

print_keystone_service_list