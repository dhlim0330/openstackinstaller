echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 5 ]
then
	echo "올바른 구문: $0 <controller-host-name> <placement-db-password> <mysql-username> <mysql-password> <placement-password>"
	exit 1
fi

echo_and_sleep "MySQL 설정 (Placement)"
mysql_command="CREATE DATABASE IF NOT EXISTS placement; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$2'; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$2';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$3" -p"$4" -e "$mysql_command"

echo_and_sleep "source admin-openrc.sh"
source $(dirname $0)/admin-openrc.sh

create-user-service placement $5 placement OpenStackPlacement placement

echo_and_sleep "Placement 서비스 엔드포인트 생성"
create-api-endpoints placement http://$1:8778

echo_and_sleep "Placement 설정"
crudini --set /etc/placement/placement.conf placement_database connection mysql+pymysql://placement:$2@$1/placement

crudini --set /etc/placement/placement.conf api auth_strategy keystone

configure-keystone-authentication /etc/placement/placement.conf $1 placement $5
crudini --set /etc/placement/placement.conf paste_deploy flavor keystone
crudini --set /etc/placement/placement.conf placement_store stores file,http
crudini --set /etc/placement/placement.conf placement_store default_store file

echo_and_sleep "Placement 서비스 DB 업그레이드" 
placement-manage db sync

echo_and_sleep "Placement 서비스 재시작" 1
service apache2 restart

echo_and_sleep "Placement MySQL-Lite DB 삭제" 
rm -f /var/lib/placement/placement.sqlite

print_keystone_service_list