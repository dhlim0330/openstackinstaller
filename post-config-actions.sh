echo "실행: $0 $@"
dir_path=$(dirname $0)
node_type=`bash $dir_path/util/detect-nodetype.sh`
echo "노드 타입: $node_type"

if [ "$node_type" == "allinone" ] || [ "$node_type" == "controller" ] 
then
        echo "웹 로그 활성화"
        mkdir /var/www/html/oslogs
        chmod a+rx /var/log/nova
        chmod a+rx /var/log/neutron
        chmod a+rx /var/log/apache2
        chmod a+rx /var/log/keystone
        chmod a+rx /var/log/glance
        chmod a+rx /var/log/cinder
        ln -s /var/log/nova /var/www/html/oslogs/nova
        ln -s /var/log/neutron /var/www/html/oslogs/neutron
        ln -s /var/log/apache2 /var/www/html/oslogs/apache2
        ln -s /var/log/keystone /var/www/html/oslogs/keystone
        ln -s /var/log/glance /var/www/html/oslogs/glance
        ln -s /var/log/cinder /var/www/html/oslogs/cinder
        echo "웹 로그 url: http://<controller_ip>/oslogs"
fi

echo "******************************************"
echo "**       post-config-actions 완료       **"	
echo "******************************************"