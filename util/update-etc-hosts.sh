function change-ip-in-etc-hosts() {
	if [ -z "$3" ]
    then
        hosts_file_name="/etc/hosts"
    else
        hosts_file_name=$3
	fi
	echo "호스트 파일: $hosts_file_name"
	grep -w "$1" $hosts_file_name
	if [ $? -eq 0 ] ;
    then
        echo "controller 발견됨 - 삭제"
        sed_command="/ $1/d"
		echo "SED 커맨드:: "$sed_command
        sed -i "$sed_command" $hosts_file_name
	fi
	echo "$2        $1" >> $hosts_file_name
	echo "업데이트 후 $hosts_file_name 내용..."
	grep -w " $1" $hosts_file_name
	sleep 1
}

function get-ip-address() {
    ip_address_val=''
    ip_address_val=`ifconfig $1 | grep 'inet ' | cut -d' ' -f10 | awk '{ print $1}'`
    echo $ip_address_val
}

echo "실행: $0 $@"
echo ""
sleep 2
dir_path=$(dirname $0)

node_type=`bash $(dirname $0)/detect-nodetype.sh`
echo "로컬 호스트 타입: $node_type"

local_ip_address=$(get-ip-address $1)
echo "로컬 호스트 IP: $local_ip_address"

local_host_name=`hostname`
echo "로컬 호스트 이름: $local_host_name"
sleep 1

if [ "$node_type" == "controller" ] || [ "$node_type" == "allinone" ]
then
	if [ $# -eq 2 ]
	then
		echo "컨트롤러 노드 정보를 /etc/hosts 에 추가"
		change-ip-in-etc-hosts $2 $local_ip_address
	else
		echo "올바른 형식: $0 <mgmt_interface> <controller_host_name>"
		exit 1;
	fi
elif [ "$node_type" == "compute" ]
then
	if [ $# -eq 3 ]
	then
		echo "/etc/hosts 의 로컬 노드 IP 주소 업데이트"
		change-ip-in-etc-hosts $local_host_name $local_ip_address
	
		echo "/etc/hosts 의 컨트롤러 노드 IP 주소 업데이트"
		change-ip-in-etc-hosts $2 $3
	else
		echo "올바른 형식: $0 <mgmt-interface-name> <controller-host-name> <controller-ip-address>"
		exit 1;
	fi
else
	echo "노드 타입 오류 $0: $node_type"
	exit 1;
fi