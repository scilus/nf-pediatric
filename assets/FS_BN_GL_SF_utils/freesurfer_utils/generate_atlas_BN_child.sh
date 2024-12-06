#!/bin/bash

# Version to compute the Brainnetome atlas for children adapted from generate_atlas_FS_BN_GL_SF_v5.sh made by
# Francois Rheault et Manon Edde.

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

# Make tmp folder because of the LUT
mkdir ${FS_ID_FOLDER}/BN_child_atlas/
mkdir ${FS_ID_FOLDER}/FS_atlas/
mkdir -p ${FS_ID_FOLDER}/${OUT_DIR}/

# ==================================================================================
# Generate transformation from Freesurfer
echo "Generate Freesurfer transformation file"
tkregister2 --mov ${FS_ID_FOLDER}/mri/brain.mgz --noedit --s ${SUBJID} --regheader --reg ${FS_ID_FOLDER}/BN_child_atlas/register.dat >> ${FS_ID_FOLDER}/logfile.txt

# ==================================================================================
# Create the Brainnetomme Child cortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Brainnetome Child cortical parcellation from Freesurfer data (slow)${NC}"
# Compared to the adult version, the BN Child atlas comes in fsaverage space in an annotation format.
mkdir ${FS_ID_FOLDER}/BN_child_atlas/tmp/
mri_annotation2label --subject fsaverage --hemi lh --outdir ${FS_ID_FOLDER}/BN_child_atlas/tmp/ --annotation ${UTILS_DIR}/lh.BN_child_fsaverage.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
mri_annotation2label --subject fsaverage --hemi rh --outdir ${FS_ID_FOLDER}/BN_child_atlas/tmp/ --annotation ${UTILS_DIR}/rh.BN_child_fsaverage.annot >> ${FS_ID_FOLDER}/logfile.txt &>> ${FS_ID_FOLDER}/logfile.txt
rm ${FS_ID_FOLDER}/BN_child_atlas/tmp/*\?*

# Then do a surface-based registration to move it to the subject space.
for i in ${FS_ID_FOLDER}/BN_child_atlas/tmp/l*.*.label;
    do echo mri_label2label --srcsubject fsaverage --srclabel ${i} --trgsubject ${SUBJID} --regmethod surface --hemi lh --trglabel ${FS_ID_FOLDER}/BN_child_atlas/$(basename ${i}) ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh; done
for i in ${FS_ID_FOLDER}/BN_child_atlas/tmp/r*.*.label;
    do echo mri_label2label --srcsubject fsaverage --srclabel ${i} --trgsubject ${SUBJID} --regmethod surface --hemi rh --trglabel ${FS_ID_FOLDER}/BN_child_atlas/$(basename ${i}) ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh; done
# Slow operation, multiprocessing it!
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm -r ${FS_ID_FOLDER}/cmd.sh ${FS_ID_FOLDER}/BN_child_atlas/tmp/

# Merge it into a single .annot file for statistics (the LUT file has to be copied in the tmp folder each time, since freesurfer is modifying it).
cp ${UTILS_DIR}/atlas_brainnetome_child_v1_LUT.txt ${FS_ID_FOLDER}/tmp/
mris_label2annot --s ${SUBJID} --h lh --ctab ${FS_ID_FOLDER}/tmp/atlas_brainnetome_child_v1_LUT.txt --a BN_Child --ldir ${FS_ID_FOLDER}/BN_child_atlas/
mris_anatomical_stats -mgz -cortex ${FS_ID_FOLDER}/label/lh.cortex.label -f ${FS_ID_FOLDER}/${OUT_DIR}/lh.BN_Child.stats -b -a ${FS_ID_FOLDER}/label/lh.BN_Child.annot -c ${FS_ID_FOLDER}/tmp/atlas_brainnetome_child_v1_LUT.txt ${SUBJID} lh white
cp ${UTILS_DIR}/atlas_brainnetome_child_v1_LUT.txt ${FS_ID_FOLDER}/tmp/
mris_label2annot --s ${SUBJID} --h rh --ctab ${FS_ID_FOLDER}/tmp/atlas_brainnetome_child_v1_LUT.txt --a BN_Child --ldir ${FS_ID_FOLDER}/BN_child_atlas/
mris_anatomical_stats -mgz -cortex ${FS_ID_FOLDER}/label/rh.cortex.label -f ${FS_ID_FOLDER}/${OUT_DIR}/rh.BN_Child.stats -b -a ${FS_ID_FOLDER}/label/rh.BN_Child.annot -c ${FS_ID_FOLDER}/tmp/atlas_brainnetome_child_v1_LUT.txt ${SUBJID} rh white

# ==================================================================================
# Create the Brainnetomme subcortical parcellation from Freesurfer data
echo -e "${BLUE}Create the Brainnetomme subcortical parcellation (adult is identical to child version) from Freesurfer data (slow)${NC}"
mri_ca_label ${FS_ID_FOLDER}/mri/brain.mgz ${FS_ID_FOLDER}/mri/transforms/talairach.m3z ${UTILS_DIR}/subcortex_BN_atlas.gca ${FS_ID_FOLDER}/BN_child_atlas/BN_atlas_subcortex.nii.gz >> ${FS_ID_FOLDER}/logfile.txt

# ==================================================================================
# Convert the *.label to *.nii.gz, very slow because of the cortical ribbon (filling)
echo -e "${BLUE}Creating the Brainnetome Child parcellation ROIs by filling up the cortical ribbon (very slow)${NC}"
for i in ${FS_ID_FOLDER}/BN_child_atlas/lh*.label;
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi lh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/BN_child_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
for i in ${FS_ID_FOLDER}/BN_child_atlas/rh*.label;
    do echo mri_label2vol --label ${i} --temp ${FS_ID_FOLDER}/mri/brain.mgz --o ${i/.label/.nii.gz} --subject ${SUBJID} --hemi rh --proj frac 0 1 .1 --fillthresh .3 --reg ${FS_ID_FOLDER}/BN_child_atlas/register.dat --fill-ribbon ' >> '${FS_ID_FOLDER}'/logfile.txt' >> ${FS_ID_FOLDER}/cmd.sh
done
# Slow operation, multiprocessing it !
parallel --will-cite -P ${NBR_PROCESSES} < ${FS_ID_FOLDER}/cmd.sh; rm ${FS_ID_FOLDER}/cmd.sh

# ==================================================================================
# Rename and multiply all binary masks so they follow the same convention as split_label_by_ids
echo "Rename the BN Child cortical ROIs to a simple ids convention"
python3 ${UTILS_DIR}/utils_rename_parcellation.py ${FS_ID_FOLDER}/BN_child_atlas/*h.*.nii.gz ${UTILS_DIR}/parcellation_names_BN_child.json ${FS_ID_FOLDER}/BN_child_atlas/split_rename/

# ==================================================================================
echo -e "${BLUE}Rename the BN subcortical ROIs to a simple ids convention${NC}"
# Split subcortical ids and mix them with the cortical
mkdir ${FS_ID_FOLDER}/BN_child_atlas/subcortical/
scil_split_volume_by_ids.py ${FS_ID_FOLDER}/BN_child_atlas/BN_atlas_subcortex.nii.gz --out_dir ${FS_ID_FOLDER}/BN_child_atlas/subcortical/
for i in ${FS_ID_FOLDER}/BN_child_atlas/subcortical/*.nii.gz;
    do base_name=$(basename $i .nii.gz); add_name=$((${base_name}-22));
    scil_image_math.py --data_type uint16 --exclude_background subtraction ${i} 22 ${FS_ID_FOLDER}/BN_child_atlas/split_rename/${add_name}.nii.gz
done
rm -r ${FS_ID_FOLDER}/BN_child_atlas/subcortical/

# ==================================================================================
echo -e "${BLUE}Rename the FS wmparc ROIs to a simple ids convention${NC}"
mri_convert ${FS_ID_FOLDER}/mri/wmparc.mgz ${FS_ID_FOLDER}/mri/wmparc.nii.gz
scil_image_math.py convert ${FS_ID_FOLDER}/mri/wmparc.nii.gz ${FS_ID_FOLDER}/mri/wmparc.nii.gz --data_type uint16 -f
mkdir ${FS_ID_FOLDER}/FS_atlas/split_rename/
scil_split_volume_by_ids.py ${FS_ID_FOLDER}/mri/wmparc.nii.gz --out_dir ${FS_ID_FOLDER}/FS_atlas/split_rename/

# ==================================================================================
echo "Transfert the FS brainstem and cerebellum to BN Child"
# Add the brainstem to BN (225)
for i in ${FS_ID_FOLDER}/FS_atlas/split_rename/16.nii.gz;
    do base_name=$(basename $i .nii.gz); add_name=$((${base_name}+209)); scil_image_math.py --data_type uint16 --exclude_background addition ${i} 209 ${FS_ID_FOLDER}/BN_child_atlas/split_rename/${add_name}.nii.gz
done

# Add the cerebellum to BN (226,227)
scil_image_math.py --data_type uint16 --exclude_background addition ${FS_ID_FOLDER}/FS_atlas/split_rename/8.nii.gz 218 ${FS_ID_FOLDER}/BN_child_atlas/split_rename/226.nii.gz
scil_image_math.py --data_type uint16 --exclude_background addition ${FS_ID_FOLDER}/FS_atlas/split_rename/47.nii.gz 180 ${FS_ID_FOLDER}/BN_child_atlas/split_rename/227.nii.gz

# ==================================================================================
echo -e "${BLUE}Combine the labels into a clean Brainnetome atlas${NC}"
a=''
for i in ${FS_ID_FOLDER}/BN_child_atlas/split_rename/*.nii.gz; do a="${a} --volume_ids ${i} $(basename ${i} .nii.gz)"; scil_image_math.py convert ${i} ${i} --data_type uint16 -f; done
scil_combine_labels.py ${FS_ID_FOLDER}/BN_child_atlas/atlas_brainnetome_child.nii.gz ${a}

# ==================================================================================
# Since Freesurfer is all in 1x1x1mm and a 256x256x256 array, our atlases must be resampled/reshaped
echo -e "${BLUE}Reshape as the original input and convert the final atlases into uint16${NC}"
mri_convert ${FS_ID_FOLDER}/mri/rawavg.mgz ${FS_ID_FOLDER}/mri/rawavg.nii.gz
scil_reshape_to_reference.py ${FS_ID_FOLDER}/BN_child_atlas/atlas_brainnetome_child.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/atlas_brainnetome_child.nii.gz --interpolation nearest

# ==================================================================================
# Safer for most script, thats our label data type
echo -e "${BLUE}Finished creating the atlas by dilating the label${NC}"
scil_image_math.py convert ${FS_ID_FOLDER}/atlas_brainnetome_child.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_child_v1.nii.gz --data_type uint16 -f
rm ${FS_ID_FOLDER}/atlas_*.nii.gz
cp ${UTILS_DIR}/atlas_brainnetome_child_v1_*.* ${FS_ID_FOLDER}/${OUT_DIR}/

# Compute statistics on subcortical regions.
mri_segstats --seg ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_child_v1.nii.gz --ctab ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_child_v1_LUT.txt --excludeid 0 \
    --o ${FS_ID_FOLDER}/${OUT_DIR}/BN_Child_subcortical.stats --pv ${FS_ID_FOLDER}/mri/norm.mgz \
    --id 189 190 191 192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207 208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223 224 225 226 227

# Dilating the atlas
mri_convert ${FS_ID_FOLDER}/mri/brainmask.mgz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz
scil_image_math.py lower_threshold ${FS_ID_FOLDER}/mri/brain_mask.nii.gz 0.001 ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --data_type uint8 -f
scil_image_math.py dilation ${FS_ID_FOLDER}/mri/brain_mask.nii.gz 1 ${FS_ID_FOLDER}/mri/brain_mask.nii.gz -f
scil_reshape_to_reference.py ${FS_ID_FOLDER}/mri/brain_mask.nii.gz ${FS_ID_FOLDER}/mri/rawavg.nii.gz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --interpolation nearest -f
scil_image_math.py convert ${FS_ID_FOLDER}/mri/brain_mask.nii.gz ${FS_ID_FOLDER}/mri/brain_mask.nii.gz --data_type uint8 -f

scil_dilate_labels.py ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_child_v1.nii.gz ${FS_ID_FOLDER}/${OUT_DIR}/atlas_brainnetome_child_v1_dilated.nii.gz --distance 2 --labels_to_dilate {1..188} {225..227} --mask ${FS_ID_FOLDER}/mri/brain_mask.nii.gz

echo -e "${BLUE}Finished creating the atlas.${NC}"
