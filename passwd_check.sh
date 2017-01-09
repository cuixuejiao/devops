#!/bin/bash
#
# Perform a eMail notification 
# about expired OpenLDAP password with ppolicy

## LDAP Info
LDAP_HOST="ldap://xxx:389"
LDAP_ROOTDN="cn=admin,dc=xxx,dc=com"
LDAP_ROOTPW="xxxx"
LDAP_PPOLICYDN="cn=default,ou=policies,dc=xxx,dc=com"
USER_NAME=uid
USER_MAIL=mail
USER_SEARCHBASE="ou=users,dc=xxx,dc=com"
USER_SEARCHFILTER="(&(uid=*)(objectClass=inetOrgPerson))"

## Mail Info
MAIL_FORM="xxx@xxx.com"
MAIL_PASS='xxx'
MAIL_SERVER="smtp.xxx.com"
MAIL_SUBJECT="【温馨提醒】您的 ldap 账号即将过期，请按邮件内容及时修改，谢谢"
MAIL_BODY="""
userName 您好,\n
     您的 GIT/SVN 密码将会在 expireTime 过期（有效期为三个月）。\n
     我们深表歉意，但是请您务必尽快修改密码，否则您的账号在密码过期后将会被锁定，无法正常访问 GIT、SVN。\n
     密码修改链接：http://xxx/changepwd.html \n
     \n
     密码修改后，请使用新密码访问 GERRIT、JENKINS、SVN。\n
     使用 SVN 客户端还需清除客户端密码缓存，操作方式请参考：xxx \n
     \n
     感谢您的配合，祝您工作愉快~O(∩_∩)O~\n
     有疑问请咨询：xxx\n
"""

## Variables
bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"

num_users=0
num_expired_users=0
num_warning_users=0
ldap_param="-H ${LDAP_HOST} -x -D ${LDAP_ROOTDN} -w ${LDAP_ROOTPW} -LLL"

## get password age info
#/usr/bin/ldapsearch ${ldap_param} -s base -b ${LDAP_PPOLICYDN} pwdMaxAge pwdExpireWarning > ${bash_dir}/ppolicy_info
#pwdMaxAge=`grep -w "pwdMaxAge:" ${bash_dir}/ppolicy_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//"`
#pwdExpireWarning=`grep -w "pwdExpireWarning:" ${bash_dir}/ppolicy_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//"`
pwdMaxAge="3 months"
pwdExpireWarning="15 days"
currentTime=`date +%Y%m%d`
echo "currentTime:${currentTime}"

## Check every user's pwdChangedTime attribute 
/usr/bin/ldapsearch ${ldap_param} -s one -b ${USER_SEARCHBASE} ${USER_SEARCHFILTER} dn \
                    | sed '/^$/d' | cut -d : -f 2 | sort -n > ${bash_dir}/result_file
while read dnString
do
    num_users=`expr ${num_users} + 1`
    
    # get user cn, name, email, pwdChangedTime and createTimestamp info
    /usr/bin/ldapsearch ${ldap_param} -s base -b ${dnString} \
                        ${USER_CN} ${USER_NAME} ${USER_MAIL} pwdChangedTime createTimestamp \
                        > ${bash_dir}/user_info
    userName=`grep -w "${USER_NAME}:" ${bash_dir}/user_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//"`
    userMail=`grep -w "${USER_MAIL}:" ${bash_dir}/user_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//"`
    pwdChangedTime=`grep -w "pwdChangedTime:" ${bash_dir}/user_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//" | cut -c 1-8`
    createTimestamp=`grep -w "createTimestamp:" ${bash_dir}/user_info | cut -d : -f 2 | sed "s/^ *//;s/ *$//" | cut -c 1-8`
    createTime=`date +%Y%m%d -d ${createTimestamp}`

    # figure expireTime
    if [ ! "${pwdChangedTime}" ]; then
        # if pwdChangedTime attribute does not exists, use createTimestamp
        expireTime=`date +%Y%m%d -d "${createTimestamp} + ${pwdMaxAge}"`
    else
        expireTime=`date +%Y%m%d -d "${pwdChangedTime} + ${pwdMaxAge}"`
    fi
    # figure expired users
    diffTime=`date +%Y%m%d -d "${expireTime} - ${pwdExpireWarning}"`
    if [ ${currentTime} -lt ${diffTime} ]; then
        #echo "!!!!! Password for ${userName} is fine, warning date: ${diffTime}"
        continue
    elif [ ${currentTime} -lt ${expireTime} ]; then
        # mail to expiring users
        #echo "!!!!! Password for ${userName} will be expired soon, expire date: ${expireTime}"
        num_warning_users=`expr ${num_warning_users} + 1`
        echo -e ${MAIL_BODY} > mailmsg
        sed -i 's/userName/'${userName}'/g' mailmsg
        sed -i 's/expireTime/'`date +%Y-%m-%d -d ${expireTime}`'/g' mailmsg
        /usr/bin/sendemail -s ${MAIL_SERVER} -xu ${MAIL_FORM} -xp ${MAIL_PASS} \
                           -f ${MAIL_FORM} -t ${userMail} \
                           -u ${MAIL_SUBJECT} -o message-charset=utf-8 -o message-file=mailmsg
        sleep 60
    elif [ ${currentTime} -eq ${expireTime} ]; then
        # mail to expiring users last time
        #echo "!!!!! Password for ${userName} will be expired tomorrow!"
        num_warning_users=`expr ${num_warning_users} + 1`
        echo -e ${MAIL_BODY} > mailmsg
        sed -i 's/userName/'${userName}'/g' mailmsg
        sed -i 's/expireTime/'明天'/g' mailmsg
        /usr/bin/sendemail -s ${MAIL_SERVER} -xu ${MAIL_FORM} -xp ${MAIL_PASS} \
                           -f ${MAIL_FORM} -t ${userMail} \
                           -u ${MAIL_SUBJECT_2} -o message-charset=utf-8 -o message-file=mailmsg
        sleep 60
    else
        #echo "!!!!! Password has expired for ${userName}, expire date: ${expireTime}"
        num_expired_users=`expr ${num_expired_users} + 1`
        mailmsg="!!!!! Password has expired for ${userName}"
        /usr/bin/sendemail -s ${MAIL_SERVER} -xu ${MAIL_FORM} -xp ${MAIL_PASS} \
                           -f ${MAIL_FORM} -t admin@youcompany.com \
                           -u ${mailmsg} -m "lock lock lock"
        sleep 60
    fi
done < ${bash_dir}/result_file
rm ${bash_dir}/result_file
rm ${bash_dir}/user_info
#rm ${bash_dir}/ppolicy_info

# Print statistics on STDOUT
echo "--- Statistics ---" >> Result
echo "Users checked: ${num_users}" >> Result
echo "Account expired: ${num_expired_users}" >> Result
echo "Account in warning: ${num_warning_users}" >> Result
echo "end of `date`" >> Result

exit 0
