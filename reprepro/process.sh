#!/bin/bash -e

import_debs() {
    # get distribution
    dist=$(grep TAG ${INFO_DIR}/${1})
    dist=${dist##*=}
    dist=${dist%-*}

    tar xf ${INCOMING_DIR}/${1}.tgz -C ${TEMP_DIR}

    # check if this is xenomai/rt-preempt armhf
    if ls ${TEMP_DIR}/*rt-preempt*armhf*deb >/dev/null 2>&1 ||
       ls ${TEMP_DIR}/*xenomai*armhf*deb >/dev/null 2>&1; 
    then
        # delete duplicate files
        rm -f ${TEMP_DIR}/machinekit-dev_*deb
        rm -f ${TEMP_DIR}/machinekit_*deb
    fi
    
    reprepro --confdir ${CONF_DIR} \
        includedeb ${dist} ${TEMP_DIR}/*deb
        
    reprepro --confdir ${CONF_DIR} \
        includedsc ${dist} ${TEMP_DIR}/*dsc 2>/dev/null|| true

    rm -f ${TEMP_DIR}/*
    rm -f ${INCOMING_DIR}/${1}.tgz
    rm -f ${INFO_DIR}/${1}*
}

if [ "$#" -eq 0 ]; then
    echo 'no status file specified'
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo 'only one status file may be specified'
    exit 1
fi

if [[ $1 == *"_failed" ]]; then
    base=${1%_failed}
    # check if this is the run_tests that failed
    if grep --quiet run_tests ${INFO_DIR}/${base}; then
        touch ${FAIL_DIR}/${base%.*}
    fi
    # delete failed files
    rm -f ${INFO_DIR}/${base}*
    rm -f ${INCOMING_DIR}/${base}*
    echo "$base failed"
    # remove queued files
    jobs="$(cd ${QUEUE_DIR}; ls ${base%.*}* 2>/dev/null )"
    if [ ! -z "${jobs}" ]; then
        for a in ${jobs}; do
            rm -f ${QUEUE_DIR}/${a}
            rm -f ${INCOMING_DIR}/${a}.tgz
            rm -f ${INFO_DIR}/${a}*
        done
    fi
    exit 0
fi

if [[ $1 != *"_passed" ]]; then
    echo 'wrong status file specified'
    exit 1
fi

base=${1%_passed}

# check if the run_tests had passed
if grep --quiet run_tests ${INFO_DIR}/${base}; then
    touch ${PASS_DIR}/${base%.*}
    rm -f ${INFO_DIR}/${base}*
    echo "$base passed"
    # process queued files
    jobs="$(cd ${QUEUE_DIR}; ls ${base%.*}* 2>/dev/null )"
    if [ ! -z "${jobs}" ]; then
        for a in ${jobs}; do
            rm -f ${QUEUE_DIR}/${a}
            import_debs ${a}
        done
    fi
    exit 0
fi

# else this is not a run_tests job

# check if the run_test has failed or passed
fail="$(cd ${FAIL_DIR}; ls ${base%.*}* 2>/dev/null )" || true
pass="$(cd ${PASS_DIR}; ls ${base%.*}* 2>/dev/null )" || true

if [ ! -z "${fail}" ]; then
    # delete failed files
    rm -f ${INFO_DIR}/${base}*
    rm -f ${INCOMING_DIR}/${base}*
elif [ ! -z "${pass}" ]; then
    import_debs ${base}
else    # else queue up the job
    touch ${QUEUE_DIR}/${base}
    rm -f ${INFO_DIR}/${1}
fi

