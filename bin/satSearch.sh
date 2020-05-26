#! /bin/bash -l
#SBATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=4:00:00
#SBATCH --ntasks=12
#SBATCH --mem=20GB
#SBATCH -J satSearch
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

start=`date +%s`

module load python/3.6.3

set -x

{

obsnum=OBSNUM
base=BASE
datadir=${base}processing/${obsnum}
cd ${datadir}

## clear up files

for ((i=0;i<10;i++));
do
    rm *${i}-dirty.fits
done

## run sat search and run dep jobs

satSearch.py --obs ${obsnum} --t1 1 --t2 55 --user ${spaceTrackUser} --passwd ${spaceTrackPassword} --debug=true

Tvar=$(<t.txt)
array=(`echo $Tvar | sed 's/ /\n/g'`)

## submit high angular resolution jobs

cd ${base}
channels=768
job_array=""
for q in "${array[@]}";
do

    # submit job for timestep 
    script="${base}queue/args_hrimage_${obsnum}.sh"
    cat ${base}bin/arg_hrimage.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                -e "s:BASE:${base}:g"\
                                -e "s:CHANNELS:${channels}:g"\
                                -e "s:TIMESTEP:${timeStep}:g" > ${script}
    output="${base}queue/logs/args_hrimage_${obsnum}.o%A"
    error="${base}queue/logs/args_hrimage_${obsnum}.e%A"
    sub="sbatch --begin=now+15 --output=${output} --error=${error} -A pawsey0345 ${script} "
    jobid=($(${sub}))
    jobid=${jobid1[3]}

    # rename the err/output files as we now know the jobid
    error=`echo ${error} | sed "s/%A/${jobid}/"`
    output=`echo ${output} | sed "s/%A/${jobid}/"`
    job_array=${job_array}:${jobid}
 
done

echo "the dependent job arrray is " ${job_array:1}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
