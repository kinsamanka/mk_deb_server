#!/bin/bash -e

#
# Usage: 
#    manual_upload.sh -i <import dir> -d <debian suite> \
#        -u <sftp username> -k <sftp identity key> \
#        -p <sftp port> <sftp host>
#
# The default arguments are:
#
#     username:   travis
#     sftp port:  9022
#
# The sftp identity key is stored at keys/access_key
#
# Note that all the files under the <import dir>
# will be uploaded to the sftp server
#

while [[ $# > 1 ]]
do
    key="$1"

    case $key in
        -i|--import)
            DIR="$2"
            shift
        ;;
        -k|--sshkey)
            KEY="$2"
            shift
        ;;
        -d|--distribution)
            DIST="$2"
            shift
        ;;
        -u|--user)
            SFTP_USER="$2"
            shift
        ;;
        -p|--port)
            PORT="$2"
            shift
        ;;
    esac
    shift
done

if [ -z "${1}" ]; then
    echo sftp host argument missing!
    exit 1
fi

if [ -z "${DIST}" ]; then
    echo Debian distribution missing! Use -d/--distribution argument
    exit 1
fi

if [ -z "${DIR}" ]; then
    echo No import directory specified! Use -i/--import argument
    exit 1
fi

if [ ! -d "${DIR}" ]; then
    echo Import directory ${DIR} does not exists!
    exit 1
fi

x=$(find $DIR -mindepth 1 -print -quit -name '*.dsc' -o -name '*.deb')
if [ -z "${x}" ]; then
    echo The import directory ${DIR} does not contain any debian packages!
    exit 1
fi

if [ ! -z "${KEY}" -a ! -f "${KEY}" ]; then
    echo Identity file ${KEY} does not exists!
    exit 1
fi

# test sftp connection
cat >${DIR}/sftp_cmds <<EOF
bye
EOF

SFTP_ARGS="-b ${DIR}/sftp_cmds -o StrictHostKeyChecking=no -oBatchMode=no"
if [ ! -z "${PORT}" ]; then
    SFTP_ARGS+=" -P ${PORT}"
else
    SFTP_ARGS+=" -P 9022"
fi

if [ ! -z "${KEY}" ]; then
    SFTP_ARGS+=" -i ${KEY}"
fi
 
if [ ! -z "${SFTP_USER}" ]; then
    SFTP_ARGS+=" ${SFTP_USER}@${1}"
else
    SFTP_ARGS+=" travis@${1}"
fi

connect_sftp() {
    err=0
    sftp ${SFTP_ARGS} || err=$?

    if [ $err -ne 0 ]; then
        rm -f ${DIR}/{sftp_cmds,IMPORT*}
        echo Error connecting with sftp. Exit code: ${err}
        exit 1
    fi
}

# check connection
connect_sftp

rm -f ${DIR}/sftp_cmds
# tar payload
tar czf ${DIR}/IMPORT.1.tgz -C ${DIR} . 2>/dev/null || true

if [ ! -f ${DIR}/IMPORT.1.tgz ]; then
    echo Error creating ${DIR}/IMPORT.1.tgz file!
    exit 1
fi

# create status file
cat >${DIR}/IMPORT <<EOF
CMD=run_tests
EOF

cat >${DIR}/IMPORT.1 <<EOF
TAG=${DIST}-xxx
EOF

# create result file
touch ${DIR}/IMPORT_passed
touch ${DIR}/IMPORT.1_passed

cat >${DIR}/sftp_cmds <<EOF
cd shared/incoming
put ${DIR}/IMPORT.1.tgz
cd ../info
put ${DIR}/IMPORT
put ${DIR}/IMPORT_passed
! sleep 2
put ${DIR}/IMPORT.1
put ${DIR}/IMPORT.1_passed
bye
EOF

# upload
connect_sftp

# cleanup
rm -f ${DIR}/{sftp_cmds,IMPORT*}
