echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh
if [ $# -lt 5 ]
then
    echo "올바른 구문: $0 <controller-host-name> <keystone-db-password> <mysql-username> <mysql-password> <admin-tenant-password>"
    exit 1
fi
echo "MySQL 설정 중 (Keystone)..."
mysql_command="CREATE DATABASE IF NOT EXISTS keystone; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$2'; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$2';"
echo "MySQL DB 커맨드: "$mysql_command 
sleep 3
mysql -u "$3" -p"$4" -e "$mysql_command"

echo_and_sleep "Keystone Conf 설정" 1
crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:$2@$1/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet
grep "mysql" /etc/keystone/keystone.conf

echo_and_sleep "Keystone DB Sync 실행" 1
keystone-manage db_sync
echo_and_sleep "Fernet 설정" 1
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

echo_and_sleep "Keystone 부트스트랩" 1
keystone-manage bootstrap --bootstrap-password $5 \
  --bootstrap-admin-url http://$1:5000/v3/ \
  --bootstrap-internal-url http://$1:5000/v3/ \
  --bootstrap-public-url http://$1:5000/v3/ \
  --bootstrap-region-id RegionOne
  
echo_and_sleep "Keystone 부트스트랩 완료" 1
grep -q '^ServerName' /etc/apache2/apache2.conf && sed 's/^ServerName.*/ServerName controller/' -i /etc/apache2/apache2.conf || echo "ServerName controller" >> /etc/apache2/apache2.conf 

echo_and_sleep "Apache 서비스 재시작" 1
service apache2 restart

echo "KeyStone MySQL-Lite DB 삭제..."
rm -f /var/lib/keystone/keystone.db

echo_and_sleep "환경 변수 설정" 1
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$5
export OS_AUTH_URL=http://$1:5000/v3
export OS_IDENTITY_API_VERSION=3

echo_and_sleep "서비스 프로젝트 생성" 1
openstack project create --domain default --description "Service Project" service

echo_and_sleep "Demo 테넌트 및 역할 생성" 1
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password password demo
openstack role create user
openstack role add --project demo --user demo user

echo_and_sleep "Keystone 서비스 재시작" 1
source $(dirname $0)/admin-openrc.sh
echo_and_sleep "source admin-openrc.sh"
print_keystone_service_list