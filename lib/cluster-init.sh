source $(dirname $0)/config-parameters.sh

echo_and_sleep "클러스터 호스트 인증"
pcs host auth $controller_host_name -u hacluster -p $pcs_password

echo_and_sleep "클러스터 생성"
pcs cluster setup --start openstack-hacluster controller --force
pcs cluster enable --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
#pcs property set start-failure-is-fatal=false

pcs node attribute $controller_host_name node_role=controller

echo_and_sleep "클러스터 리소스 생성"
pcs resource create HA_VIP ocf:heartbeat:IPaddr ip=$pcs_vip_address cidr_netmask=24 nic=$mgmt_interface op monitor interval=30s
pcs constraint location  HA_VIP rule resource-discovery=exclusive score=0 node_role eq controller --force
pcs resource create lb-haproxy systemd:haproxy
pcs resource clone lb-haproxy
pcs constraint location lb-haproxy-clone rule resource-discovery=exclusive score=0 node_role eq controller --force
pcs constraint colocation add lb-haproxy-clone with HA_VIP 
pcs constraint order start HA_VIP then lb-haproxy-clone kind=Optional

pcs property set stonith-enabled=true

source $(dirname $0)/admin-openrc.sh
openstack segment create --description "HA segment" ha-segment auto compute