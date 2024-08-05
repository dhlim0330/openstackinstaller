echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh

if [ $# -lt 6 ]
	then
		echo "올바른 구문: $0 <placement-db-password> <mysql-username> <mysql-password> <controller-host-name> <admin-tenant-password> <placement-password>"
		exit 1
fi

echo "MySQL 설정 (Placement)..."
mysql_command="CREATE DATABASE IF NOT EXISTS placement; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$1'; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$1';"
echo "MySQL 커맨드:: "$mysql_command
mysql -u "$2" -p"$3" -e "$mysql_command"

source $(dirname $0)/admin-openrc.sh
echo_and_sleep "Admin OpenRC 소싱 완료"

create-user-service placement $6 placement OpenStackPlacement placement

create-api-endpoints placement http://$4:8778
echo_and_sleep "Placement 서비스 엔드포인트 생성 완료"

echo "Placement 설정..."
crudini --set /etc/placement/placement.conf placement_database connection mysql+pymysql://placement:$1@$4/placement

crudini --set /etc/placement/placement.conf api auth_strategy keystone

configure-keystone-authentication /etc/placement/placement.conf $4 placement $6
crudini --set /etc/placement/placement.conf paste_deploy flavor keystone
crudini --set /etc/placement/placement.conf placement_store stores file,http
crudini --set /etc/placement/placement.conf placement_store default_store file

echo_and_sleep "Placement 서비스 데이터베이스 초기화" 
placement-manage db sync

echo_and_sleep "Placement 서비스 재시작..." 1
service apache2 restart

echo_and_sleep "Placement MySQL-Lite 데이터베이스 삭제" 
rm -f /var/lib/placement/placement.sqlite

print_keystone_service_list