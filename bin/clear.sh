#! /bin/bash -l
#rj name=clear runtime=1

start=`date +%s`


set -x

{

datadir=${base}/processing/${obsnum}
cd ${datadir}

echo "Cleaning up output folder ${datadir}"
rm -f -r ${obsnum}.ms
rm -f ${obsnum}.metafits
rm -f *.zip
rm -f *gpubox*.fits
rm -f *-dirty.fits
end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
