dir_path=$(dirname $0)

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 [ init | <target-cluster-name>]"
	exit 1
fi

if [ "$1" == "init" ]
then
    echo "클러스터 초기화"
    sleep 1
    bash $dir_path/lib/cluster-init.sh
else
    echo "클러스터 연결 추가: $1"
    sleep 1
    bash $dir_path/lib/cluster-connect.sh $1
fi