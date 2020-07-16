#!/bin/bash

usage()
{
echo "autoSubmitJobs.sh [-c calibration] [-o obsnum] [-a account] [-f channels] [-s timeSteps] [-t target wget] [-q calibration obs] [-u calibration wget] [-m calibration model]
        -c calibration          : path to calibration solution
        -m calibration model    : the calibration model
        -a account              : pawsey Account to use
        -q calibration obs      : the obs id for calibration
        -u calibration wget     : the wget link for calibration obs
        -f channels             : the number of channels in ms, default=768
        -s timeSteps            : the number of timeSteps in ms, default=56
        -t target wget          : the asvo wget link for target obs
        -o obsnum               : the obsid" 1>&2;
exit 1;
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


while getopts 'c:o:a:f:s:t:q:u:m:' OPTION
do
    case "$OPTION" in
        m)
            calibration_model=${OPTARG}
            ;;
        u)
            calibration_asvo=${OPTARG}
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
            target_asvo=${OPTARG}
            ;;
        
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid is empty then just pring help
if [[ -z ${obsnum} ]]
then
    usage
fi

base=/p8/mcc_icrar/MWA-SSA/code/DUG-MWA-SSA-Pipeline/
queue=test
dl_queue=bud3

## run asvo for target obs ##
jobidasvo=$(rjs ${base}/bin/asvo.sh queue=${dl_queue} name=asvo_${obsnum} schema=base:${base}+obsnum=${obsnum} logdir=${base}/logs 2>/dev/null)
echo "Submitted ASVO job for target obs as ${jobidasvo}"

## check if calibration sol exists
if [[ -e "${calibrationPath}" ]]
then
    echo "Calibration solution exists"
else
    echo "Calibration solution does NOT exist"

    ## asvo for calibration
    jobidasvo=$(rjs ${base}/bin/calibrate.sh queue=${dl_queue} name=asvo_${calibration_obs} dep=${jobidasvo} schema=base:${base}+obsnum=${calibration_obs} logdir=${base}/logs 2>/dev/null)
    echo "Submitted ASVO job for calibration obs obs as ${jobidasvo}"

    ## calibration job for calibration
    jobidasvo=$(rjs ${base}/bin/calibrate.sh queue=${queue} name=calibrate_${calibration_obs} dep=${jobidasvo} schema=base:${base}+obsnum:${calibration_obs} logdir=${base}/logs 2>/dev/null)
    echo "Submitted calibration job as ${jobidasvo}"
fi

## run cotter ##
echo "Running:"
echo "  rjs ${base}/bin/cotter.sh queue=${queue} name=cotter_${obsnum} dep=${jobidasvo} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs"
job1=$(rjs ${base}/bin/cotter.sh queue=${queue} name=cotter_${obsnum} dep=${jobidasvo} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs 2>/dev/null)

echo "Submitted cotter job as ${job1}"

# wsclean has some multithreading, so run 8 processes per node
pernode=8
rounded=$((((${timeSteps}/${pernode})+1)*${pernode}))
echo "Running:"
echo "  rjs ${base}/bin/hrimage.sh queue=${queue} name=hrimage_${obsnum} schema=base:${base}+obsnum:${obsnum}+channels:${channels}+pernode:${pernode}+ts:0-${rounded}[${pernode}]+maxTimeStep:${timeSteps} logdir=${base}/logs dep=${job1}"
job2=$(rjs ${base}/bin/hrimage.sh queue=${queue} name=hrimage_${obsnum} schema=base:${base}+obsnum:${obsnum}+channels:${channels}+pernode:${pernode}+ts:0-${rounded}[${pernode}]+maxTimeStep:${timeSteps} logdir=${base}/logs dep=${job1} 2>/dev/null)

echo "Submitted hrimage job as ${job2}"

# RFISeeker is single-threaded Python, so run 64 per node
pernode=64
rounded=$((((${timeSteps}/${pernode})+1)*${pernode}))
echo "Running:"
echo "  rjs ${base}/bin/rfiseeker.sh queue=${queue} name=rfiseeker_${obsnum} schema=base:${base}+obsnum:${obsnum}+channels:${channels}+pernode:${pernode}+ts:0-${rounded}[${pernode}]+maxTimeStep:${timeSteps} logdir=${base}/logs dep=${job2}"
job3=$(rjs ${base}/bin/rfiseeker.sh queue=${queue} name=rfiseeker_${obsnum} schema=base:${base}+obsnum:${obsnum}+channels:${channels}+pernode:${pernode}+ts:0-${rounded}[${pernode}]+maxTimeStep:${timeSteps} logdir=${base}/logs dep=${job2} 2>/dev/null)

echo "Submitted RFISeeker job as ${job3}"

job4=$(rjs ${base}/bin/clear.sh queue=${queue} name=clear_${obsnum} schema=base:${base}+obsnum:${obsnum} logdir=${base}/logs dep=${job3} 2>/dev/null)

echo "Submitted clear job as ${job4}"
