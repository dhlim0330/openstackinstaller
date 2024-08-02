if [ "$controller_host_name" == "" ]
then
	echo "컨트롤러 호스트 이름 환경 변수가 비어 있음. 인자 확인 중."
	if [ "$1" == "" ]
	then
		echo "컨트롤러 호스트 이름 환경 변수가 비어 있음. 기본 컨트롤러 이름(controller) 사용."
		final_controller_host_name="controller"
	else
		final_controller_host_name=$1
	fi	
else
	final_controller_host_name=$controller_host_name
fi

echo "확정된 컨트롤러 이름: "$final_controller_host_name
	
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=Passw0rd1
export OS_AUTH_URL=http://$final_controller_host_name:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2