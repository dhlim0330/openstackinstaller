source $(dirname $0)/config-parameters.sh

if [ $# -lt 1 ]
then
	echo "올바른 구문: $0 [ compute | networknode | controller ]"
	exit 1;
fi

if [ "$1" == "networknode" ] || [ "$1" == "controller" ] 
then
	sh -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
	sleep 1
    ovs-vsctl add-br br-$data_interface
    ip addr add $neutron_ovs_bridge_address dev br-$data_interface
    ip link set dev br-$data_interface up
fi

if [ "$1" == "networknode" ] || [ "$1" == "compute" ] || [ "$1" == "controller" ] 
then
	sh -c 'echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf'
	sleep 1
	sh -c 'echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf'
	sleep 1
	echo "sysctl.conf 설정 완료, 변경 사항 적용"
	sysctl -p
else
	echo "올바른 구문: $0 [ compute | networknode | controller ]"
	exit 1;
fi