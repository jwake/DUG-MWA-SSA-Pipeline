#!/bin/bash

usage()
{
echo "autoSubmitJobs.sh [-c calibration] [-o obsnum] [-a account] [-f channels] [-s timeSteps] [-t target wget] [-q calibration obs] [-u calibration wget] [-m calibration model] [-k]
        -c calibration          : path to calibration solution
        -m calibration model    : the calibration model
        -a account              : pawsey Account to use
        -q calibration obs      : the obs id for calibration
        -u calibration wget     : the wget link for calibration obs
        -f channels             : the number of channels in ms, default=768
        -s timeSteps            : the number of timeSteps in ms, default=56
        -t target wget          : the asvo wget link for target obs
        -o obsnum               : the obsid
        -p                      : skip result copy
        -k                      : skip cleanup" 1>&2;
exit 1;
}
join_by() { local IFS="$1"; shift; echo "$*"; }

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

calibrationPath=
account="mwasci"
channels=768
timeSteps=55
obsnum=
calibration_obs=
calibration_asvo=
calibration_model=
target_asvo=
skip_result_copy=0
skip_cleanup=0

RJS=/d/sw/Insight/latest/scripts/rjs
while getopts 'c:o:a:f:s:t:q:u:m:kp' OPTION
do
    case "$OPTION" in
        m)
            calibration_model=${OPTARG}
            ;;
        u)
            calibration_asvo=$(rawurlencode "${OPTARG}")
            ;;
        q)
            calibration_obs=${OPTARG}
            ;;
        f)
            channels=${OPTARG}
            ;;
        s)
            timeSteps=${OPTARG}
            ;;
        c)
            calibrationPath=${OPTARG}
            ;;
        o)
            obsnum=${OPTARG}     
            ;;
        a)
            account=${OPTARG}
            ;;
        t)
            target_asvo=$(rawurlencode "${OPTARG}")
            ;;
        p)
            skip_result_copy=1
            ;;
        k)
            skip_cleanup=1
            ;;
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid is empty then just print help
if [[ -z ${obsnum} ]]
then
    usage
fi

source /p9/mcc_icrar/sw/env.sh

base=/p9/mcc_icrar/MWA-SSA/code/DUG-MWA-SSA-Pipeline
mkdir -p ${base}/logs
mkdir -p ${base}/jobs
echo $* >> ${base}/logs/runs.log
queue=icrar
dl_queue=icrar_copy

rm -f ${base}/bin/*.schema

if [[ ! -z "${calibration_obs}" ]]; then
    calibrationPath=${calibrationPath}/${calibration_obs}.bin
fi

jobid_asvo_tgt=
jobid_cal=
dep=
## run asvo for target obs, if it doesn't exist already ##
if [[ ! -e "${base}/processing/${obsnum}/${obsnum}.ms" && ! $(compgen -G "${base}/processing/${obsnum}/*gpubox*" > /dev/null) ]]
then
    # Make sure there isn't a job already running
    current=$(squeue -u `whoami` -h -o %j -n "asvo_${obsnum}" 2>/dev/null)
    if [[ ! -z "${current}" ]]
    then
        echo "Skipping ASVO job for ${obsnum} as one is already running with job ID ${current}"
        jobidasvo=${current}
        dep="dep=${jobidasvo}"
    else
        echo "Running: "
        
        cp ${base}/bin/asvo.sh ${base}/jobs/asvo_target_${obsnum}.sh
        echo "  ${RJS} ${base}/jobs/asvo_target_${obsnum}.sh queue=${dl_queue} name=asvo_tgt_${obsnum} schema=base:${base}+obsnum:${obsnum}+link:${target_asvo} logdir=${base}/logs"
        jobid_asvo_tgt=$(${RJS} ${base}/jobs/asvo_target_${obsnum}.sh queue=${dl_queue} name=asvo_tgt_${obsnum} schema=base:${base}+obsnum:${obsnum}+link:${target_asvo} logdir=${base}/logs 2>/dev/null)
        dep="dep=${jobid_asvo_tgt}"
        echo "Submitted ASVO job for target obs as ${jobid_asvo_tgt}"
    fi
else
    echo "Skipped ASVO job for ${obsnum} as the data already exists"
fi

## check if calibration sol exists
if [[ -e "${calibrationPath}" ]]
then
    echo "Calibration solution exists"
else
    echo "Calibration solution does NOT exist"

    if [[ -z "${calibration_obs}" || -z "${calibration_model}" ]]
    then
        echo "Must specify a calibration observation and model if no calibration solution exists."
        exit
    fi

    ## asvo for calibration, if necessary
    if [[ ! -e "${base}/processing/${calibration_obs}/${calibration_obs}.ms" ]]
    then
        current=$(squeue -u `whoami` -h -o %j -n "asvo_${calibration_obs}" 2>/dev/null)
        if [[ ! -z "${current}" ]]
        then
            echo "Skipping ASVO job for calibration obs ${calibration_obs} as one is already running with job ID ${current}"
            jobidasvo=${current}
            dep="dep=${jobidasvo}"
        elif [[ $(compgen -G "${base}/processing/${calibration_obs}/*gpubox*" > /dev/null) ]]
        then
            echo "Skipping ASVO job for calibration obs ${calibration_obs} as the GPUBOX FITS files already exist"
        else
            echo "Running: "
            cp ${base}/bin/asvo.sh ${base}/jobs/asvo_calibration_${obsnum}.sh
            echo "  ${RJS} ${base}/jobs/asvo_calibration_${obsnum}.sh queue=${dl_queue} name=asvo_cal_${calibration_obs} schema=base:${base}+obsnum:${obsnum}+link:${calibration_asvo} logdir=${base}/logs"
            cp ${base}/bin/asvo.sh ${base}/bin/asvo_calibration.sh
            jobidasvo=$(${RJS} ${base}/jobs/asvo_calibration_${obsnum}.sh queue=${dl_queue} name=asvo_cal_${calibration_obs} schema=base:${base}+obsnum:${calibration_obs}+link:${calibration_asvo} logdir=${base}/logs 2>/dev/null)
            dep="dep=${jobidasvo}"
            echo "Submitted ASVO job for calibration obs ${calibration_obs} as ${jobidasvo}"
        fi

    else
        echo "Skipped ASVO job for calibration obs ${calibration_obs} as ${base}processing/${obsnum}/${obsnum}.ms exists"
    fi

    ## calibration job for calibration
    echo "Running:"
    cp ${base}/bin/calibrate.sh ${base}/jobs/calibrate_${obsnum}.sh
    echo "  ${RJS} ${base}/jobs/calibrate_${obsnum}.sh queue=${queue} name=calibrate_${calibration_obs} $dep schema=base:${base}+obsnum:${calibration_obs}+calibrationModel:${calibration_model} logdir=${base}/logs"
    jobid_cal=$(${RJS} ${base}/jobs/calibrate_${obsnum}.sh queue=${queue} name=calibrate_${calibration_obs} $dep schema=base:${base}+obsnum:${calibration_obs}+calibrationModel:${calibration_model} logdir=${base}/logs 2>/dev/null)
    echo "Submitted calibration job as ${jobid_cal}"
fi

dep="dep=$(join_by , ${jobid_asvo_tgt} ${jobid_cal})"

## run cotter ##
if [[ -e "${base}/processing/${obsnum}/.cotter_complete" ]]
then
    echo "Cotter already completed successfully, skipping"
else
    echo "Running:"
    cp ${base}/bin/cotter.sh ${base}/jobs/cotter_${obsnum}.sh
    echo "  ${RJS} ${base}/jobs/cotter_${obsnum}.sh queue=${queue} name=cotter_${obsnum} ${dep} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs"
    job1=$(${RJS} ${base}/jobs/cotter_${obsnum}.sh queue=${queue} name=cotter_${obsnum} ${dep} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs 2>/dev/null)

    echo "Submitted cotter job as ${job1}"
    dep="dep=${job1}"
fi

# wsclean has some multithreading, so run at most 8 processes per node, capped by required RAM
# allow this much ram per wsclean at minimum
ram_per_job=25
# no more than this many per node
pernode=8
# allocate at most this much ram per node
max_ram_per_node=100
# maximum node concurrency for this job
max_nodes=16

cpu_cap=$((64/$pernode))
ram_cap=$(($max_ram_per_node/$ram_per_job))
pernode=$(dc -e "[$cpu_cap]sM ${ram_cap}d ${cpu_cap}<Mp")
# 'cpus' here includes hardware threads
# we treat the phis as 64-core, so a few cores will be left over for the OS.
cpus=$((4*64/${pernode}))
ram=$((${max_ram_per_node}/${pernode}))
maxtasks=$((${max_nodes}*${pernode}))
multi_rjs=rjs_multi
echo "Running:"
cp ${base}/bin/hrimage_multi.sh ${base}/jobs/hrimage_${obsnum}.sh
mkschema wsclean_ram:${ram}+wsclean_cpus:${cpus}+base:${base}+obsnum:${obsnum}+channels:${channels}+ts:1-$((${timeSteps}-1))+maxTimeStep:${timeSteps} > ${base}/jobs/hrimage_${obsnum}.schema
echo "  ${multi_rjs} ${base}/jobs/hrimage_${obsnum}.sh queue=${queue} name=hrimage_${obsnum} schema=${base}/jobs/hrimage_${obsnum}.schema logdir=${base}/logs cpus=${cpus} mem=${ram}G maxtasks=${maxtasks} ${dep}"

job2=$(${multi_rjs} ${base}/jobs/hrimage_${obsnum}.sh queue=${queue} name=hrimage_${obsnum} schema=${base}/jobs/hrimage_${obsnum}.schema logdir=${base}/logs cpus=${cpus} mem=${ram}G maxtasks=${maxtasks} ${dep} 2>/dev/null)

echo "Submitted hrimage job as ${job2}"

# RFISeeker is single-threaded Python, so run more per node
echo "Running:"
cp ${base}/bin/rfiseeker_multi.sh ${base}/jobs/rfiseeker_${obsnum}.sh
mkschema base:${base}+obsnum:${obsnum}+channels:${channels}+ts:0-${timeSteps} > ${base}/jobs/rfiseeker_${obsnum}.schema
echo "  ${multi_rjs} ${base}/jobs/rfiseeker_${obsnum}.sh queue=${queue} name=rfiseeker_${obsnum} schema=${base}/jobs/rfiseeker_${obsnum}.schema logdir=${base}/logs dep=${job2}"
job3=$(${multi_rjs} ${base}/jobs/rfiseeker_${obsnum}.sh queue=${queue} name=rfiseeker_${obsnum} schema=${base}/jobs/rfiseeker_${obsnum}.schema logdir=${base}/logs dep=${job2} 2>/dev/null)

echo "Submitted RFISeeker job as ${job3}"

cp ${base}/bin/combine_copy_results.sh ${base}/jobs/combine_copy_results_${obsnum}.sh
job4=$(${multi_rjs} ${base}/jobs/combine_copy_results_${obsnum}.sh queue=${dl_queue} name=combine_copy_results_${obsnum} schema=base:${base}+obsnum:${obsnum}+skip_result_copy:${skip_result_copy} logdir=${base}/logs dep=${job3} 2>/dev/null)
echo "Submitted results combine + copy job as ${job4}"

if [[ ${skip_cleanup} -eq 0 ]]; then
    cp ${base}/bin/clear.sh ${base}/jobs/clear_${obsnum}.sh
    job5=$(${multi_rjs} ${base}/jobs/clear_${obsnum}.sh queue=${queue} name=clear_${obsnum} schema=base:${base}+obsnum:${obsnum} logdir=${base}/logs dep=${job4} 2>/dev/null)

    echo "Submitted clear job as ${job5}"
fi

