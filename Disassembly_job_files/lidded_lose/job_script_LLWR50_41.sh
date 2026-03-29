#!/bin/bash
#SBATCH --job-name=LLWR50_41
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
MEM_PID=


# Run the commands inside the Apptainer container
apptainer exec --nv /scratch/gilbreth/desai274/CONTACT/apptainer/tvb.sif bash -c "
    source ~/.bashrc
    conda activate tacsl
    cd /scratch/gilbreth/desai274/CONTACT
    python train.py         --config-name=train_diffusion_workspace_disassembly.yaml         task=vistac_pih_vision_tactile_onecam_disassembly         exp_name=LLWR50         dataset_path=/scratch/gilbreth/desai274/CONTACT/data/lidded_loose_2         isaacgym_cfg_name=isaacgym_config_liddedloose.yaml         training.seed=41         training.num_epochs=500         task.dataset.max_train_episodes=50         hydra.run.dir=data/outputs/LLWR50/41_2         logging.project=liddedloose_41_v2 
"

kill -s INT 

