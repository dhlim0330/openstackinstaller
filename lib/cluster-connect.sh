source $(dirname $0)/config-parameters.sh

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 <target-cluster-name>"
	exit 1
fi

echo_and_sleep "컴퓨트 노드 탐색"
nova-manage cell_v2 discover_hosts

pcs property set stonith-enabled=false

echo_and_sleep "클러스터 호스트 인증"
pcs host auth $1 -u hacluster -p $pcs_password

echo_and_sleep "클러스터 연결 추가: $1"
pcs cluster node add-remote $1
pcs node attribute $1 node_role=compute
pcs resource unclone lb-haproxy
pcs resource clone lb-haproxy

echo_and_sleep "stonith 리소스 생성"
pcs property set stonith-enabled=true
pcs stonith create ipmi-fence-$1 fence_ipmilan lanplus=true pcmk_host_list=$1 pcmk_host_check=static-list pcmk_off_action=off pcmk_reboot_action=off ipaddr=$1 ipport=15205 login=root passwd=123qwe power_wait=4 op monitor interval=10s

source $(dirname $0)/admin-openrc.sh
echo_and_sleep "세그먼트에 컴퓨트 호스트 추가"
openstack segment host create $1 compute ssh ha-segment