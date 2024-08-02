echo "실행: $0 $@"
source $(dirname $0)/config-parameters.sh
if [ $# -lt 1 ]
        then
                echo "올바른 구문: $0 <cotroller-host-name>"
                exit 1
fi
echo_and_sleep "local_settings.py 를 /etc/openstack-dashboard 로 복사하는 중" 2
cp $(dirname $0)/local_settings.py /etc/openstack-dashboard/

sed -e "/^OPENSTACK_HOST =.*$/s/^.*$/OPENSTACK_HOST = \""$1"\"/" -i /etc/openstack-dashboard/local_settings.py
sed -e "/^'LOCATION.*$/s/^.*$/'LOCATION': \'"$1:1121"\'/" -i /etc/openstack-dashboard/local_settings.py
grep "OPENSTACK_HOST" /etc/openstack-dashboard/local_settings.py
grep "LOCATION" /etc/openstack-dashboard/local_settings.py
echo_and_sleep "apache2 재시작 중" 1
service apache2 reload
echo_and_sleep "apache2 재시작 완료" 1