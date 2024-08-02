source $(dirname $0)/config-parameters.sh

function configure-mysql-controller() {
	echo_and_sleep "컨트롤러 노드: MySQL 설정"	
        if [ -d "/etc/mysql/mariadb.conf.d/" ]
	then
                echo_and_sleep "MariaDB Conf 파일 발견" 2
		mysql_conf_file="/etc/mysql/mariadb.conf.d/openstack.cnf"
               	echo_and_sleep "새 DB Conf 파일 생성: $mysql_conf_file"
               	touch $mysql_conf_file
           	crudini --set $mysql_conf_file mysqld bind-address $1
               	echo_and_sleep "바인드 주소 업데이트 완료" 2
               	crudini --set $mysql_conf_file mysqld default-storage-engine innodb
               	crudini --set $mysql_conf_file mysqld collation-server utf8_general_ci
               	crudini --set $mysql_conf_file mysqld character-set-server utf8
               	crudini --set $mysql_conf_file mysqld max_connections 4096
               	echo "innodb_file_per_table" >> $mysql_conf_file
	else
		echo_and_sleep "MariaDB Conf 파일 발견되지 않음" 2
		mysql_conf_file="/etc/mysql/my.cnf"
		sed -i "s/127.0.0.1/$1/g" $mysql_conf_file
                echo_and_sleep "바인드 주소 업데이트 완료" 2
                grep "bind" $mysql_conf_file

                sed -i "/\[mysqld\]/a default-storage-engine = innodb\\
                	innodb_file_per_table\\
                        collation-server = utf8_general_ci\\
                        init-connect = 'SET NAMES utf8'\\
                        character-set-server = utf8\\
                " $mysql_conf_file
        fi
        grep "bind" $mysql_conf_file
        grep "storage-engine" $mysql_conf_file
        echo_and_sleep "기타 MySQL 패러미터 설정 완료, MySQL 재시작" 3

        service mysql restart;
        sleep 2

}

metering_secret="Passw0rd1"

if [ "$1" == "compute" ]
	then
		echo_and_sleep "컴퓨트 노드 설정" 3
		bash $(dirname $0)/configure-forwarding.sh compute

		echo_and_sleep "컴퓨트 노드 Nova 설정" 3
		bash $(dirname $0)/configure-nova.sh compute $controller_host_name $nova_password $rabbitmq_password
		
		echo_and_sleep "컴퓨트 노드 Neutron 설정" 3
		bash $(dirname $0)/configure-neutron.sh compute $controller_host_name $rabbitmq_password $neutron_password
elif [ "$1" == "controller" ] 
	then
		if [ $# -ne 2 ]
		then
			echo "올바른 구문: $0 controller <controller_ip_address>"
			exit 1;
		fi
		configure-mysql-controller $2
		bash $(dirname $0)/mysql-secure-installation.sh $mysql_user $mysql_password
		echo_and_sleep "MySQL 설정 및 Secure Installation 완료" 2

		echo_and_sleep "Rabbit MQ: 패스워드 업데이트: $rabbitmq_password"
		rabbitmqctl add_user $rabbitmq_user $rabbitmq_password
		echo_and_sleep "Rabbit MQ: 유저 추가 완료, 권한 설정 중"
		rabbitmqctl set_permissions $rabbitmq_user ".*" ".*" ".*"
		echo_and_sleep "Rabbit MQ: 권한 설정 완료"
		service rabbitmq-server restart

		echo_and_sleep "memcached 설정"
		sed -i "s/127.0.0.1/$1/g" /etc/memcached.conf
		service memcached restart
		
		echo_and_sleep "KeyStone 설정..."
		bash $(dirname $0)/configure-keystone.sh $keystone_db_password $mysql_user $mysql_password $controller_host_name $admin_tenant_password
		
		echo_and_sleep "Glance 설정..."
		bash $(dirname $0)/configure-glance.sh $glance_db_password $mysql_user $mysql_password $controller_host_name $admin_tenant_password $glance_password

		echo_and_sleep "Placement 설정..."
		bash $(dirname $0)/configure-placement.sh $placement_db_password $mysql_user $mysql_password $controller_host_name $admin_tenant_password $placement_password
		
		echo_and_sleep "Nova 설정..."
		bash $(dirname $0)/configure-nova.sh controller $controller_host_name $nova_password $rabbitmq_password $nova_db_password $mysql_user $mysql_password 
		
		echo_and_sleep "Neutron 설정..."
		source $(dirname $0)/admin_openrc.sh
		bash $(dirname $0)/configure-neutron.sh controller $controller_host_name $rabbitmq_password $neutron_password $neutron_db_password $mysql_user $mysql_password

		echo_and_sleep "컨트롤러 노드 포워딩 설정"
		bash $(dirname $0)/configure-forwarding.sh controller
		
		echo_and_sleep "Horizon-Dashboard 설정"
		bash $(dirname $0)/configure-horizon.sh $controller_host_name

elif [ "$1" == "networknode" ]
	then
		echo_and_sleep "About to configure Network Node"
		bash $(dirname $0)/configure-forwarding.sh networknode

		echo_and_sleep "About to configure Neutron for Network Node" 2
		bash $(dirname $0)/configure-neutron.sh networknode $controller_host_name $rabbitmq_password $neutron_password
else
        echo "올바른 구문 1: $0 controller <controller_ip_address>"
        echo "올바른 구문 2: $0 [ compute | networknode ]"
        exit 1;

fi