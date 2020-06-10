#!/bin/bash

usage()
{
echo "autoSubmitJobs.sh [-c calibration] [-o obsnum] [-a account] [-f channels] [-s timeSteps]
        -c calibration          : path to calibration solution
        -a account              : pawsey Account to use
        -f channels             : the number of channels in ms, default=768
        -s timeSteps            : the number of timeSteps in ms, default=56
        -o obsnum               : the obsid" 1>&2;
exit 1;
}

calibrationPath=
account="mwasci"
channels=768
timeSteps=55
obsnum=

while getopts 'c:o:a:f:s:' OPTION
do
    case "$OPTION" in
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
queue=icrar,idle
echo "Running:"
echo "  rjs ${base}/bin/cotter.sh queue=${queue} name=cotter_${obsnum} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs"
job1=$(rjs ${base}/bin/cotter.sh queue=${queue} name=cotter_${obsnum} schema=base:${base}+obsnum:${obsnum}+calibrationSolution:${calibrationPath} logdir=${base}/logs 2>/dev/null)

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



