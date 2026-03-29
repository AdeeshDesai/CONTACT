# CONTACT: CONtact-aware TACTile Learning for Robotic Disassembly

[Paper](https://arxiv.org/abs/2603.08560) | [Website (coming soon)]()

CONTACT is a simulation benchmark for investigating the role of tactile sensing in robotic disassembly. It provides five rigid-body disassembly tasks with progressively increasing geometric constraints and contact complexity, implemented in IsaacGym with TacSL-based tactile rendering. Policies are trained using Diffusion Policy with multimodal visuotactile observations.

This codebase is built upon [ManiFeel](https://github.com/purdue-mars/manifeel).

---

## Simulation Tasks

| Task | Name | Description |
|------|------|-------------|
| **S1** | Vertical Pull, Loose Socket | Simple extraction with generous clearance |
| **S2** | Vertical Pull, Tight Socket | Reduced tolerance requiring friction-aware force control |
| **S3** | Loose Plug with Lid | Multi-stage task: disengage lid constraint, then extract |
| **S4** | Vertical Pull, Flat Barb | Asymmetric resistance through flat barb structure |
| **S5** | Vertical Pull, Spike Barb | Spike-shaped barb requiring careful collision avoidance |

Three sensing configurations are evaluated per task:
- **Vision Only** — front + wrist RGB cameras
- **Vision + TacRGB** — cameras + tactile RGB deformation images
- **Vision + TacFF** — cameras + tactile force-field (shear + normal force grid)

---

## 1. Installation

### 1.1 Create Workspace

Create a workspace directory and clone this repository:

```bash
mkdir contact_ws && cd contact_ws
git clone https://github.com/AdeeshDesai/CONTACT.git
```

### 1.2 Download IsaacGym

Download the TacSL-specific IsaacGym binary from [here](https://drive.google.com/file/d/13dFRF9EXpzIWaJF2Z6f7BsuPUGQkPE8v/view?usp=sharing) and extract it into the workspace:

```bash
# From contact_ws/
tar -xvzf IsaacGym_Preview_TacSL_Package.tar.gz
```

### 1.3 Run Installation Script

```bash
cd CONTACT
bash install.sh
```

The script will:
- Create a Python 3.8 conda environment named `contact`
- Install IsaacGym TacSL
- Clone and install [manifeel-isaacgymenvs](https://github.com/purdue-mars/manifeel-isaacgymenvs) (IsaacGymEnvs + TacSL sensors)
- Clone and install [Diffusion Policy](https://github.com/real-stanford/diffusion_policy)
- Install CONTACT and all dependencies

After installation, your workspace should look like:
```
contact_ws/
├── CONTACT/                          # This repository
├── manifeel-isaacgymenvs/            # IsaacGymEnvs + TacSL (cloned by install.sh)
├── IsaacGym_Preview_TacSL_Package/   # IsaacGym binary (downloaded manually)
└── diffusion_policy/                 # Diffusion Policy (cloned by install.sh)
```

---

## 2. Download Dataset

Download the CONTACT demonstration datasets from [Google Drive (link coming soon)]() and place them inside `CONTACT/data/`:

```
CONTACT/
└── data/
    ├── loose_plug/
    ├── tight_plug/
    ├── lidded_loose/
    ├── barbed_flat/
    └── barbed_spike/
```

Each dataset contains 50 teleoperated demonstrations with front camera, wrist camera, tactile RGB, tactile force-field, and end-effector state observations recorded at 10 Hz.

---

## 3. Setup Apptainer for Training

We provide an Apptainer container for reproducible environments across clusters and workstations.

### 3.1 Build the Container

```bash
apptainer build contact.sif contact.def
```

### 3.2 Verify the Setup

```bash
apptainer exec --nv contact.sif bash
source ~/.bashrc
conda activate contact
export LD_LIBRARY_PATH=${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}
python -c "from isaacgym import gymtorch"
exit
```

If `gymtorch` imports without errors, the setup is complete.

---

## 4. Training on Cluster with Slurm

### 4.1 Task Configuration Reference

| Task | IsaacGym Config | Dataset Path |
|------|-----------------|--------------|
| S1 (Loose) | `isaacgym_config_looseplug.yaml` | `data/loose_plug` |
| S2 (Tight) | `isaacgym_config_tightplug.yaml` | `data/tight_plug` |
| S3 (Lidded) | `isaacgym_config_liddedloose.yaml` | `data/lidded_loose` |
| S4 (Barbed Flat) | `isaacgym_config_barbed_flat.yaml` | `data/barbed_flat` |
| S5 (Barbed Spike) | `isaacgym_config_barbed_spike.yaml` | `data/barbed_spike` |

### 4.2 Creating the Slurm Submission Script

Create a file named `job_submit.sh`:

```bash
touch job_submit.sh
```

Paste the following script into it:

> **Important:**
> Before using the job script below, update the following fields:
>
> - Replace `[user]` with your cluster username
> - Ensure `CONTAINER_FILE` points to your `contact.sif` file
>   ```
>   CONTAINER_FILE=/path/to/cluster/[user]/contact.sif
>   ```
> - Confirm the `cd` command points to your `CONTACT` repository path
>   ```
>   cd /path/to/cluster/[user]/contact_ws/CONTACT
>   ```

```bash
#!/bin/bash

SEED=42
NUM_DEMOS=50
NUM_EPOCH=500
DATASET_PATH=data/barbed_flat
ISAACGYM_CONFIG="isaacgym_config_barbed_flat.yaml"
ENV="barbed_flat"
LOG_NAME="dp_barbed_flat_vision"
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly
INPUT_TYPE="vision"
EXP_NAME="${INPUT_TYPE}_${ENV}_${NUM_DEMOS}"

JOB_NAME="${EXP_NAME}_${SEED}"

CONTAINER_FILE=/path/to/cluster/[user]/contact.sif

cat <<EOT > job_script_${JOB_NAME}.sh
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --account=shey
#SBATCH --gres=gpu:1
#SBATCH --partition=a30
#SBATCH --mem=120G
#SBATCH --qos=normal
#SBATCH --cpus-per-task=8
#SBATCH --time=4:00:00

# Run the commands inside the Apptainer container
apptainer exec --nv ${CONTAINER_FILE} bash -c "
    source ~/.bashrc
    conda activate contact
    export LD_LIBRARY_PATH=\${CONDA_PREFIX}/lib:\${LD_LIBRARY_PATH}
    cd /path/to/cluster/[user]/contact_ws/CONTACT
    python train.py \
        --config-name=train_diffusion_workspace_disassembly.yaml \
        task=${TASK_NAME} \
        exp_name=${EXP_NAME} \
        dataset_path=${DATASET_PATH} \
        isaacgym_cfg_name=${ISAACGYM_CONFIG} \
        training.seed=${SEED} \
        training.num_epochs=${NUM_EPOCH} \
        task.dataset.max_train_episodes=${NUM_DEMOS} \
        hydra.run.dir=data/outputs/${EXP_NAME}/${SEED} \
        logging.project=${LOG_NAME}
"
EOT

# Infinite loop to monitor and resubmit the job
while true; do
    JOB_ID=$(squeue --name=$JOB_NAME --noheader --format=%A)

    if [ -z "$JOB_ID" ]; then
        echo "Job $JOB_NAME is not running. Resubmitting..."
        sbatch job_script_${JOB_NAME}.sh
        sleep 10
    else
        echo "Job $JOB_NAME is still running (Job ID: $JOB_ID)."
    fi

    sleep 30
done
```

---

### 4.3 Submitting the Training Job

Grant run permission and submit:

```bash
chmod +x job_submit.sh
./job_submit.sh
```

Slurm will schedule the job. Logs appear in the `logs/` directory. Success rates and rollout videos are logged to W&B.

---

### 4.4 Running Vision + TacRGB Policy

To train the Vision + TacRGB policy, modify the following fields in your `job_submit.sh`:

```bash
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly
INPUT_TYPE="vistac"
```

Then submit with `./job_submit.sh`.

---

### 4.5 Running Vision + TacFF Policy

To train the Vision + TacFF policy, modify the following fields in your `job_submit.sh`:

```bash
TASK_NAME=vision_tacff_disassembly
INPUT_TYPE="tacff"
```

Then submit with `./job_submit.sh`.

---

### 4.6 Running Other Tasks

To switch tasks, update `DATASET_PATH`, `ISAACGYM_CONFIG`, `ENV`, and `LOG_NAME` in your `job_submit.sh`. For example, to run Task S1 (Loose Plug):

```bash
DATASET_PATH=data/loose_plug
ISAACGYM_CONFIG="isaacgym_config_looseplug.yaml"
ENV="loose_plug"
LOG_NAME="dp_loose_plug_vision"
```

> **Important:**
> Among the parameters in `job_submit.sh`, the most critical ones to update when switching tasks or sensing modalities are:
> `DATASET_PATH`, `ISAACGYM_CONFIG`, and `TASK_NAME`.
> Other fields primarily affect file naming and experiment logging.
>
> You can freely adjust `SEED`, `NUM_DEMOS`, and `NUM_EPOCH` to control the random seed, number of demonstrations, and total training epochs.

---

## 5. Training Locally

For local machines (PC/workstation), use `scripts/run_local.sh`:

```bash
chmod +x scripts/run_local.sh
```

### 5.1 Running Vision-Only Policy

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly \
INPUT_TYPE=vision \
ENV_TAG=barbed_flat \
LOG_NAME=bf_vision \
bash scripts/run_local.sh
```

### 5.2 Running Vision + TacRGB Policy

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly \
INPUT_TYPE=vistac \
ENV_TAG=barbed_flat \
LOG_NAME=bf_vistac \
bash scripts/run_local.sh
```

### 5.3 Running Vision + TacFF Policy

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vision_tacff_disassembly \
INPUT_TYPE=tacff \
ENV_TAG=barbed_flat \
LOG_NAME=bf_tacff \
bash scripts/run_local.sh
```

### 5.4 Running Other Tasks

Override `DATASET_PATH`, `ISAACGYM_CONFIG`, `ENV_TAG`, and `LOG_NAME` for other tasks (see Section 4.1 for the configuration reference).

You can also adjust training hyperparameters:

```bash
SEED=44 \
NUM_DEMOS=50 \
NUM_EPOCH=500 \
DATASET_PATH=data/loose_plug \
ISAACGYM_CONFIG=isaacgym_config_looseplug.yaml \
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly \
INPUT_TYPE=vision \
ENV_TAG=loose_plug \
LOG_NAME=lp_vision \
bash scripts/run_local.sh
```

---

## 6. Evaluation

Success rates are computed as the average over the final 10 training epochs, each evaluated in 50 environment initializations. Results are averaged over 3 seeds (42, 43, 44), yielding 1500 rollouts per task.

A rollout is deemed successful if the target component is fully extracted and lifted above a predefined height threshold.

---

## Acknowledgments

This codebase is built upon [ManiFeel](https://github.com/purdue-mars/manifeel). We thank the ManiFeel authors for their open-source visuotactile simulation and policy learning framework.

---

## Citation

If you use CONTACT in your research, please cite:

```bibtex
@article{saka2025contact,
  title={CONTACT: CONtact-aware TACTile Learning for Robotic Disassembly},
  author={Saka, Yosuke and Hu, Jyun-Chi and Desai, Adeesh and Zhang, Zhiyuan and Zhang, Bihao and Luu, Quan Khanh and Prince, Md Rakibul Islam and Zheng, Minghui and She, Yu},
  journal={arXiv preprint arXiv:2603.08560},
  year={2025}
}
```
