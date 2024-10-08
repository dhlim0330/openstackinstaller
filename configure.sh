dir_path=$(dirname $0)
node_type=`bash $dir_path/util/detect-nodetype.sh`
echo "노드 타입: $node_type"
echo "config-parameters 참조..."
source $dir_path/lib/config-parameters.sh
echo "관리 인터페이스: "$mgmt_interface
echo "데이터 인터페이스: "$data_interface
echo "컨트롤러 호스트 이름: "$controller_host_name

sleep 1

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 <controller-ip>"
	exit 1
fi

if [ "$node_type" == "allinone" ] || [ "$node_type" == "controller" ] 
then
	echo "/etc/hosts 업데이트 (컨트롤러 노드)"
	sleep 1
	bash $dir_path/util/update-etc-hosts.sh $mgmt_interface $controller_host_name
else
	echo "/etc/hosts 업데이트 (비 컨트롤러 노드)"
	sleep 1
	bash $dir_path/util/update-etc-hosts.sh $mgmt_interface $controller_host_name $1
fi

if [ "$node_type" == "allinone" ]
then
	echo "패키지 설정: All-in-one"
	sleep 1
	bash $dir_path/lib/configure-packages.sh controller $1
	bash $dir_path/lib/configure-packages.sh compute 
	nova-manage cell_v2 discover_hosts
elif [ "$node_type" == "compute" ]
then
	echo "패키지 설정: "$node_type
	sleep 1
	bash $dir_path/lib/configure-packages.sh $node_type 
elif [ "$node_type" == "controller" ]
then
	echo "패키지 설정: controller"
	sleep 1
	bash $dir_path/lib/configure-packages.sh controller $1
else
	echo "노드 타입 오류 $0: $node_type"
	exit 1;
fi

echo "******************************************"
echo "**               설정 완료               **"	
echo "** 추가 설정: post-config-actions.sh 실행 **"
echo "******************************************"