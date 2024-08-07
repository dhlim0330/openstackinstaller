dir_path=$(dirname $0)

if [ $# -ne 1 ]
then
    echo "올바른 형식: $0 <controller-ip>"
	exit 1
fi

echo "All-In-One 형식 설치 개시"
sleep 1

bash $dir_path/install.sh allinone
sleep 1
bash $dir_path/configure.sh $1
sleep 1
bash $dir_path/post-config-actions.sh
sleep 1

echo "******************************************"
echo "**          모든 설치 과정 완료           **"	
echo "******************************************"