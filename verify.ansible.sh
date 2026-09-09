echo Retrieving public dns name of the terraform constructed EC2 host with HTML app deployed
echo Ouput of echo '$?' means:
echo   O = YES, success
echo   1 = Computer says NO
export MY_EC2=$(terraform output -json | jq -r .ec2_public_dns_name.value)
curl http://$MY_EC2/ 2>&1 | grep 'Hello ME!' > /dev/null && echo YES
echo $?
