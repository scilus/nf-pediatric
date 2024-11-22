#!/bin/bash

# Optimized version from Manon Edde by Francois Rheault (April 2020)

# If you run twice this scripts on the same subject, many warning/error will appear.
# This script is not robust to re-run, stopping it midway or if there was error in the Freesurfer execution.

# This command must have been run beforehand and fully completed !
# recon-all -i subj_t1.nii.gz -subjid ${SUBJID} -all -openmp 6

BLUE='\033[0;34m'
LRED='\033[1;31m'
NC='\033[0m'
ColorPrint () { echo -e ${BLUE}${1}${NC}; }

missing=1
if [ ${#} -eq 4 ]; then
    missing=0
fi

if [ ${missing} == 1 ]; then
    echo -e "${LRED}Missing some arguments."
    echo -e "  First argument : Variable SUBJECTS_DIR from Freesurfer when it was launched"
    echo -e "  Second argument : Variable SUBJID from Freesurfer when it was launched"
    echo -e "  Third argument : Number of processes for cortical ribbon operation"
    echo -e "  Fourth argument : Output folder for the cleaned atlas (inside the \${SUBJECTS_DIR}/\${SUBJID}/) ${NC}"
    exit 1
fi

export SUBJECTS_DIR=$(readlink -e ${1})
export SUBJID=${2}
export NBR_PROCESSES=${3}
export OUT_DIR=${4}
export UTILS_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))
export FS_ID_FOLDER=${SUBJECTS_DIR}/${SUBJID}/

# ==================================================================================
echo "Deleting files from the previous run, generate the directory tree structure"
# Delete all files from previous run
find ${FS_ID_FOLDER}/ -type f -name "*.nii.gz" -exec rm -f {} \;
rm -f ${FS_ID_FOLDER}/label/*h.BN_atlas.annot ${FS_ID_FOLDER}/label/*h.HCPMMP1.annot ${FS_ID_FOLDER}/label/*h.Schaefer2018*.annot
rm -f ${FS_ID_FOLDER}/logfile.txt
rm -rf ${FS_ID_FOLDER}/FS_atlas/ ${FS_ID_FOLDER}/BN_atlas/ ${FS_ID_FOLDER}/GL_atlas/ ${FS_ID_FOLDER}/SF_atlas/

# Make tmp folder because of the LUT
mkdir ${FS_ID_FOLDER}/BN_atlas/
mkdir ${FS_ID_FOLDER}/GL_atlas/
mkdir ${FS_ID_FOLDER}/FS_atlas/
mkdir ${FS_ID_FOLDER}/SF_atlas/
mkdir -p ${FS_ID_FOLDER}/${OUT_DIR}/

for i in rh.A9 rh.A12 rh.A1 rh.A1/2 rh.A41 rh.TE1.0 rh.A35 rh.A28 rh.vId rh.V5 lh.A9 lh.A12 lh.A1 lh.A1/2 lh.A41 lh.TE1.0 lh.A35 lh.A28 lh.vId lh.V5; 
    do mkdir -p ${FS_ID_FOLDER}/BN_atlas/${i}/; 
done

# ==================================================================================
# Generate transformation from Freesurfer
echo "Generate Freesurfer transformation file"
tkregister2 --mov ${FS_ID_FOLDER}/mri/brain.mgz --noedit --s ${SUBJID} --regheader --reg ${FS_ID_FOLDER}/BN_atlas/register.dat >> ${FS_ID_FOLDER}/logfile.txt
tkregister2 --mov ${FS_ID_FOLDER}/mri/brain.mgz --noedit --s ${SUBJID} --regheader --reg ${FS_ID_FOLDER}/GL_atlas/register.dat >> ${FS_ID_FOLDER}/logfile.txt
tkregister2 --mov ${FS_ID_FOLDER}/mri/brain.mgz --noedit --s ${SUBJID} --regheader --reg ${FS_ID_FOLDER}/SF_atlas/register.dat >> ${FS_ID_FOLDER}/logfile.txt

# ==================================================================================
# Create the Brainnetomme cortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Brainnetome cortical parcellation from Freesurfer data (slow)${NC}"
for hemi in lh rh; 
    do mris_ca_label -l ${FS_ID_FOLDER}/label/${hemi}.cortex.label ${SUBJID} ${hemi} ${FS_ID_FOLDER}/surf/${hemi}.sphere.reg ${UTILS_DIR}/${hemi}_BN_atlas.gcs ${FS_ID_FOLDER}/label/${hemi}.BN_atlas.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
    mri_annotation2label --annotation BN_atlas --subject ${SUBJID} --hemi ${hemi} --outdir ${FS_ID_FOLDER}/BN_atlas/ >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
done

# ==================================================================================
# Create the Glasser cortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Glasser cortical parcellation from Freesurfer data (slow)${NC}"
# The glasser annot are actually in fsaverage space, so we have to first generate the fsaverage label
mkdir ${FS_ID_FOLDER}/GL_atlas/tmp/
mri_annotation2label --subject fsaverage --hemi lh --outdir ${FS_ID_FOLDER}/GL_atlas/tmp/ --annotation ${UTILS_DIR}/lh.HCPMMP1.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
mri_annotation2label --subject fsaverage --hemi rh --outdir ${FS_ID_FOLDER}/GL_atlas/tmp/ --annotation ${UTILS_DIR}/rh.HCPMMP1.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
rm ${FS_ID_FOLDER}/GL_atlas/tmp/*\?*

# Then do a surface-based registration to move it to the native subject space
for i in ${FS_ID_FOLDER}/GL_atlas/tmp/l*.*.label; do echo mri_label2label --srcsubject fsaverage --srclabel ${i} --trgsubject ${SUBJID} --regmethod surface --hemi lh --trglabel ${FS_ID_FOLDER}/GL_atlas/$(basename ${i}) ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh; done
for i in ${FS_ID_FOLDER}/GL_atlas/tmp/r*.*.label; do echo mri_label2label --srcsubject fsaverage --srclabel ${i} --trgsubject ${SUBJID} --regmethod surface --hemi rh --trglabel ${FS_ID_FOLDER}/GL_atlas/$(basename ${i}) ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh; done
# Slow operation, multiprocessing it !
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm -r ${FS_ID_FOLDER}/cmd.sh ${FS_ID_FOLDER}/GL_atlas/tmp/

# ==================================================================================
# Create the Schaefer cortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Schaefer cortical parcellation from Freesurfer data (slow)${NC}"
for hemi in lh rh; 
    do for size in 100 200 400;
        do mris_ca_label -l ${FS_ID_FOLDER}/label/${hemi}.cortex.label ${SUBJID} ${hemi} ${FS_ID_FOLDER}/surf/${hemi}.sphere.reg ${UTILS_DIR}/schaefer_17_gcs/${hemi}.Schaefer2018_${size}Parcels_17Networks.gcs ${FS_ID_FOLDER}/label/${hemi}.Schaefer2018_${size}Parcels_17Networks_order.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
        mri_annotation2label --annotation Schaefer2018_${size}Parcels_17Networks_order --subject ${SUBJID} --hemi ${hemi} --outdir ${FS_ID_FOLDER}/SF_atlas/${size} >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
    done
done

# ==================================================================================
# Rename the label file with slash in the filename
echo "Renaming label files and cleaning up"
for i in rh.A9 rh.A12 rh.A1/2 rh.A41 rh.TE1.0 rh.A35 rh.A28 rh.vId rh.V5 lh.A9 lh.A12 lh.A1/2 lh.A41 lh.TE1.0 lh.A35 lh.A28 lh.vId lh.V5
    do for j in ${FS_ID_FOLDER}/BN_atlas/${i}/*.label; do mv ${j} ${FS_ID_FOLDER}/BN_atlas/${i//\//\_}_$(basename ${j}); done
done
# Delete the tmp folder
rm -r ${FS_ID_FOLDER}/BN_atlas/*/

# ==================================================================================
# Create the Brainnetomme subcortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Brainnetomme subcortical parcellation from Freesurfer data (slow)${NC}"
mri_ca_label ${FS_ID_FOLDER}/mri/brain.mgz ${FS_ID_FOLDER}/mri/transforms/talairach.m3z ${UTILS_DIR}/subcortex_BN_atlas.gca ${FS_ID_FOLDER}/BN_atlas/BN_atlas_subcortex.nii.gz >> ${FS_ID_FOLDER}/logfile.txt

# ==================================================================================
# Convert the *.label to *.nii.gz, very slow because of the cortical ribbon (filling)
echo -e "${BLUE}Creating the Brainnetome parcellation ROIs by filling up the cortical ribbon (very slow)${NC}"
for i in ${FS_ID_FOLDER}/BN_atlas/lh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi lh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/BN_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
for i in ${FS_ID_FOLDER}/BN_atlas/rh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi rh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/BN_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
# Slow operation, multiprocessing it !
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm ${FS_ID_FOLDER}/cmd.sh

# ==================================================================================
# Convert the *.label to *.nii.gz, very slow because of the cortical ribbon (filling)
echo -e "${BLUE}Creating the Glasser parcellation ROIs by filling up the cortical ribbon (very slow)${NC}"
for i in ${FS_ID_FOLDER}/GL_atlas/lh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi lh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/GL_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done

for i in ${FS_ID_FOLDER}/GL_atlas/rh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi rh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/GL_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
# Slow operation, multiprocessing it !
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm ${FS_ID_FOLDER}/cmd.sh

# ==================================================================================
# Convert the *.label to *.nii.gz, very slow because of the cortical ribbon (filling)
echo -e "${BLUE}Creating the Schaefer parcellation ROIs by filling up the cortical ribbon (very slow)${NC}"
for i in ${FS_ID_FOLDER}/SF_atlas/*/lh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi lh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/SF_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
for i in ${FS_ID_FOLDER}/SF_atlas/*/*rh*.label; 
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi rh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/SF_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
# Slow operation, multiprocessing it !
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm ${FS_ID_FOLDER}/cmd.sh

# ==================================================================================
# Rename and multiply all binary masks so they follow the same convention as split_label_by_ids
echo "Rename the BN cortical ROIs to a simple ids convention"
rm ${FS_ID_FOLDER}/BN_atlas/*Unknown*
/usr/bin/python ${UTILS_DIR}/utils_rename_parcellation.py ${FS_ID_FOLDER}/BN_atlas/*h.*.nii.gz ${UTILS_DIR}/parcellation_names_BN.json ${FS_ID_FOLDER}/BN_atlas/split_rename/
/usr/bin/python ${UTILS_DIR}/utils_rename_parcellation.py ${FS_ID_FOLDER}/GL_atlas/*h.*.nii.gz ${UTILS_DIR}/parcellation_names_GL.json ${FS_ID_FOLDER}/GL_atlas/split_rename/
for size in 100 200 400;
    do mv ${FS_ID_FOLDER}/SF_atlas/${size}/ ${FS_ID_FOLDER}/SF_atlas/${size}_/
    /usr/bin/python ${UTILS_DIR}/utils_rename_parcellation.py ${FS_ID_FOLDER}/SF_atlas/${size}_/*h.*.nii.gz ${UTILS_DIR}/parcellation_names_SF/Schaefer2018_${size}Parcels_17Networks_order_LUT.json ${FS_ID_FOLDER}/SF_atlas/${size}/
    rm ${FS_ID_FOLDER}/SF_atlas/${size}_/ -r
done

# ==================================================================================
echo -e "${BLUE}Rename the BN/GL subcortical ROIs to a simple ids convention${NC}"
# Split subcortical ids and mix them with the cortical
mkdir ${FS_ID_FOLDER}/BN_atlas/subcortical/
scil_split_volume_by_ids.py ${FS_ID_FOLDER}/BN_atlas/BN_atlas_subcortex.nii.gz --out_dir ${FS_ID_FOLDER}/BN_atlas/subcortical/
mv ${FS_ID_FOLDER}/BN_atlas/subcortical/*.nii.gz ${FS_ID_FOLDER}/BN_atlas/split_rename/
rm -r ${FS_ID_FOLDER}/BN_atlas/subcortical/

# ==================================================================================
echo -e "${BLUE}Rename the FS wmparc ROIs to a simple ids convention${NC}"
mri_convert ${FS_ID_FOLDER}/mri/wmparc.mgz ${FS_ID_FOLDER}/mri/wmparc.nii.gz
scil_image_math.py convert ${FS_ID_FOLDER}/mri/wmparc.nii.gz ${FS_ID_FOLDER}/mri/wmparc.nii.gz --data_type uint16 -f
mkdir ${FS_ID_FOLDER}/FS_atlas/split_rename/
scil_split_volume_by_ids.py ${FS_ID_FOLDER}/mri/wmparc.nii.gz --out_dir ${FS_ID_FOLDER}/FS_atlas/split_rename/

# ==================================================================================
echo "Transfert the FS brainstem and cerebellum to BN, cleaning the useless FS ROIs"
# Add the brainstem to BN (247)
for i in ${FS_ID_FOLDER}/FS_atlas/split_rename/16.nii.gz; 
    do base_name=$(basename $i .nii.gz); add_name=$((${base_name}+231)); scil_image_math.py addition ${i} 231 ${FS_ID_FOLDER}/BN_atlas/split_rename/${add_name}.nii.gz --data_type uint16 --exclude_background
done

# Add the cerebellum to BN (248,249)
scil_image_math.py addition ${FS_ID_FOLDER}/FS_atlas/split_rename/8.nii.gz 240 ${FS_ID_FOLDER}/BN_atlas/split_rename/248.nii.gz --data_type uint16 --exclude_background
scil_image_math.py addition ${FS_ID_FOLDER}/FS_atlas/split_rename/47.nii.gz 202 ${FS_ID_FOLDER}/BN_atlas/split_rename/249.nii.gz --data_type uint16 --exclude_background

# Remove the superficial WM and useless ROIs (keep only cortex, nuclei and brainstem)
mkdir ${FS_ID_FOLDER}/FS_atlas/split_rename/tmp/
for i in 8 10 11 12 13 16 17 18 26 28 47 49 50 51 52 53 54 58 60 85 1000 1001 1002 1003 1005 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1016 1017 1018 1019 1020 1021 1022 1023 1024 1025 1026 1027 1028 1029 1030 1031 1032 1033 1034 1035 2000 2001 2002 2003 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030 2031 2032 2033 2034 2035
    do mv ${FS_ID_FOLDER}/FS_atlas/split_rename/${i}.nii.gz ${FS_ID_FOLDER}/FS_atlas/split_rename/tmp/
done
rm ${FS_ID_FOLDER}/FS_atlas/split_rename/*.nii.gz
mv ${FS_ID_FOLDER}/FS_atlas/split_rename/tmp/*.nii.gz ${FS_ID_FOLDER}/FS_atlas/split_rename/
rm -r ${FS_ID_FOLDER}/FS_atlas/split_rename/tmp/

# ==================================================================================
echo "Transfert the FS brainstem and cerebellum and BN subcortical to Glasser"
# Since all BN is contiguous and the  subcortical/brainstem/cerebellum were at the end, simply add them
for i in ${FS_ID_FOLDER}/BN_atlas/split_rename/{211..249}.nii.gz; 
    do base_name=$(basename $i .nii.gz); add_name=$((${base_name}+150)); scil_image_math.py addition ${i} 150 ${FS_ID_FOLDER}/GL_atlas/split_rename/${add_name}.nii.gz --data_type uint16 --exclude_background
done

# ==================================================================================
# Once everything is in the convention of unique IDs, merge everything together and put it back in
# the intial input space
echo -e "${BLUE}Combine the labels into a clean Freesurfer atlas${NC}"
a=''
for i in ${FS_ID_FOLDER}/FS_atlas/split_rename/*.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; scil_image_math.py convert ${i} ${i} --data_type uint16 -f; done
scil_combine_labels.py ${FS_ID_FOLDER}/FS_atlas/atlas_freesurfer.nii.gz ${a}

# ==================================================================================
echo -e "${BLUE}Combine the labels into a clean Brainnetome atlas${NC}"
a=''
for i in ${FS_ID_FOLDER}/BN_atlas/split_rename/*.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; scil_image_math.py convert ${i} ${i} --data_type uint16 -f; done
scil_combine_labels.py ${FS_ID_FOLDER}/BN_atlas/atlas_brainnetome.nii.gz ${a}

# ==================================================================================
echo -e "${BLUE}Combine the labels into a clean Glasser atlas${NC}"
a=''
for i in ${FS_ID_FOLDER}/GL_atlas/split_rename/*.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; scil_image_math.py convert ${i} ${i} --data_type uint16 -f; done
scil_combine_labels.py ${FS_ID_FOLDER}/GL_atlas/atlas_glasser.nii.gz ${a}

# ==================================================================================
echo -e "${BLUE}Combine the labels into a clean Schaefer atlas${NC}"
for size in 100 200 400;
    do a=''
    for i in ${FS_ID_FOLDER}/SF_atlas/${size}/*.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; scil_image_math.py convert ${i} ${i} --data_type uint16 -f; done
    for i in ${FS_ID_FOLDER}/FS_atlas/split_rename/{8,16,47}.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; done
    for i in ${FS_ID_FOLDER}/BN_atlas/split_rename/{211..246}.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; done
    scil_combine_labels.py ${FS_ID_FOLDER}/SF_atlas/atlas_schaefer_${size}.nii.gz ${a}
done

# ==================================================================================
# Since Freesurfer is all in 1x1x1mm and a 256x256x256 array, our atlases must be resampled/reshaped
echo -e "${BLUE}Reshape as the original input and convert the final atlases into uint16${NC}"
mri_convert ${FS_ID_FOLDER}/mri/rawavg.mgz ${FS_ID_FOLDER}/mri/rawavg.nii.gz
scil_reshape_to_reference.py ${FS_ID_FOLDER}/BN_atlas/atlas_brainnetome.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/atlas_brainnetome.nii.gz --interpolation nearest
scil_reshape_to_reference.py ${FS_ID_FOLDER}/FS_atlas/atlas_freesurfer.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/atlas_freesurfer.nii.gz --interpolation nearest
scil_reshape_to_reference.py ${FS_ID_FOLDER}/GL_atlas/atlas_glasser.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/atlas_glasser.nii.gz --interpolation nearest
for size in 100 200 400;
    do scil_reshape_to_reference.py ${FS_ID_FOLDER}/SF_atlas/atlas_schaefer_${size}.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/atlas_schaefer_${size}.nii.gz --interpolation nearest
done
# ==================================================================================
# Safer for most script, thats our label data type
echo "Finished creating the atlas by dilating the label"
scil_image_math.py convert ${FS_ID_FOLDER}/atlas_freesurfer.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_freesurfer_v5.nii.gz --data_type uint16 -f
scil_image_math.py convert ${FS_ID_FOLDER}/atlas_brainnetome.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_v5.nii.gz --data_type uint16 -f
scil_image_math.py convert ${FS_ID_FOLDER}/atlas_glasser.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_glasser_v5.nii.gz --data_type uint16 -f
for size in 100 200 400;
    do scil_image_math.py convert ${FS_ID_FOLDER}/atlas_schaefer_${size}.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_schaefer_${size}_v5.nii.gz --data_type uint16 -f
done
rm ${FS_ID_FOLDER}/atlas_*.nii.gz
cp ${UTILS_DIR}/atlas_*_v5_*.* ${FS_ID_FOLDER}/${OUT_DIR}/

# Dilating the atlas
mri_convert ${FS_ID_FOLDER}/mri/brainmask.mgz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
scil_image_math.py lower_threshold ${FS_ID_FOLDER}/mri/brain_mask.nii.gz 0.001 ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --data_type uint8 -f
scil_image_math.py dilation ${FS_ID_FOLDER}/mri/brain_mask.nii.gz 1 ${FS_ID_FOLDER}/mri/brain_mask.nii.gz -f
scil_reshape_to_reference.py ${FS_ID_FOLDER}/mri/brain_mask.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --interpolation nearest -f
scil_image_math.py convert ${FS_ID_FOLDER}/mri/brain_mask.nii.gz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --data_type uint8 -f

scil_dilate_labels.py ${FS_ID_FOLDER}/${OUT_DIR}/atlas_glasser_v5.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_glasser_v5_dilate.nii.gz --distance 2 --labels_to_dilate {1..360} {397..399} --mask ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
scil_dilate_labels.py ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_v5.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_v5_dilate.nii.gz --distance 2 --labels_to_dilate {1..210} {247..249} --mask ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
scil_dilate_labels.py ${FS_ID_FOLDER}/${OUT_DIR}/atlas_freesurfer_v5.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_freesurfer_v5_dilate.nii.gz --distance 2 --labels_to_dilate {1001..1035} {2001..2035} 8 16 47 --mask ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
for size in 100 200 400;
    do scil_dilate_labels.py ${FS_ID_FOLDER}/${OUT_DIR}/atlas_schaefer_${size}_v5.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_schaefer_${size}_v5_dilate.nii.gz --distance 2 --labels_to_dilate 8 16 47 {1000..2999} --mask ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
done

echo "Finished creating the atlas"
# rm -rf ${FS_ID_FOLDER}/FS_atlas/ ${FS_ID_FOLDER}/BN_atlas/ ${FS_ID_FOLDER}/GL_atlas/
