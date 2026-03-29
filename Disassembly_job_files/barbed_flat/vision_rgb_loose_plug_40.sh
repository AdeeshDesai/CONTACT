#!/bin/bash

SEED=40

NUM_DEMOS=50
NUM_EPOCH=500
DATASET_PATH=/scratch/gilbreth/desai274/CONTACT/data/loose_plug_2
ISAACGYM_CONFIG="isaacgym_config_looseplug.yaml"
ENV="WR"
VERSION=2
LOG_NAME="looseplug_${SEED}_v${VERSION}"
TASK_NAME=vistac_pih_vision_tactile_onecam
INPUT_TYPE="LP"
EXP_NAME="${INPUT_TYPE}${ENV}${NUM_DEMOS}"  

JOB_NAME="${EXP_NAME}_${SEED}" # The name of the Slurm job to monitor 

CONTAINER_FILE=/scratch/gilbreth/desai274/Projects/tvb.sif

cat <<EOT > job_script_${JOB_NAME}.sh
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --account=shey
#SBATCH --gres=gpu:1
#SBATCH --partition=a10
#SBATCH --mem=120G
#SBATCH --qos=standby
#SBATCH --cpus-per-task=8
#SBATCH --time=4:00:00


module load monitor

monitor cpu memory >cpu-memory.log &
MEM_PID=$!


# Run the commands inside the Apptainer container
apptainer exec --nv ${CONTAINER_FILE} bash -c "
    source ~/.bashrc
    conda activate contact
    cd /scratch/gilbreth/desai274/CONTACT
    python train.py \
        --config-name=train_diffusion_workspace.yaml \
        task=${TASK_NAME} \
        exp_name=${EXP_NAME} \
        dataset_path=${DATASET_PATH} \
        isaacgym_cfg_name=${ISAACGYM_CONFIG} \
        training.seed=${SEED} \
        training.num_epochs=${NUM_EPOCH} \
        task.dataset.max_train_episodes=${NUM_DEMOS} \
        hydra.run.dir=data/outputs/${EXP_NAME}/${SEED}_${VERSION} \
        logging.project=${LOG_NAME} \

"

kill -s INT $MEM_PID

EOT

# Infinite loop to monitor and resubmit the job
while true; do
    # Check if the job is currently running
    JOB_ID=$(squeue --name=$JOB_NAME --noheader --format=%A)

    if [ -z "$JOB_ID" ]; then
        # If no job with the specified name is running, resubmit the job
        echo "Job $JOB_NAME is not running. Resubmitting..."
        # Submit the dynamically created script
        sbatch job_script_${JOB_NAME}.sh

        # Wait a few seconds to avoid rapid resubmission
        sleep 10
    else
        # Output a message indicating the job is still running
        echo "Job $JOB_NAME is still running (Job ID: $JOB_ID)."
    fi

    # Wait for a specified interval before checking the job status again
    sleep 30
done