# CONTACT: CONtact-aware TACTile Learning for Robotic Disassembly

[Paper](https://arxiv.org/abs/2603.08560) | [Website (coming soon)]()

CONTACT is a simulation benchmark for investigating the role of tactile sensing in robotic disassembly. It provides five rigid-body disassembly tasks with progressively increasing geometric constraints and contact complexity, implemented in IsaacGym with TacSL-based tactile rendering. Policies are trained using Diffusion Policy with multimodal visuotactile observations.

This codebase is built upon [ManiFeel](https://github.com/purdue-mars/manifeel).

---

## 1. Installation

CONTACT provides an automated installation script that handles all setup steps.

### Prerequisites

Create a workspace directory and download the TacSL specific Isaac Gym binary from [here](https://drive.google.com/file/d/13dFRF9EXpzIWaJF2Z6f7BsuPUGQkPE8v/view?usp=sharing):

```bash
mkdir contact_ws && cd contact_ws
tar -xvzf IsaacGym_Preview_TacSL_Package.tar.gz
```

### Automated Installation

Clone the CONTACT repository and run the installation script:

```bash
git clone https://github.com/AdeeshDesai/CONTACT.git
cd CONTACT
bash install.sh
```

The installation script will:
- Check for conda/mamba, and install Miniforge3 if not found
- Create a Python 3.8 environment named `contact`
- Install IsaacGym TacSL
- Clone and install manifeel-isaacgymenvs (TacSL fork)
- Clone and install Diffusion Policy
- Install CONTACT and all dependencies

After installation, the workspace should look like:
```
contact_ws/
├── CONTACT/                          # This repository
├── manifeel-isaacgymenvs/            # IsaacGymEnvs + TacSL (cloned by install.sh)
├── IsaacGym_Preview_TacSL_Package/   # IsaacGym binary (downloaded manually)
└── diffusion_policy/                 # Diffusion Policy (cloned by install.sh)
```
---

## 2. Download CONTACT dataset

Download and unzip the CONTACT dataset for your target task from [here](https://drive.google.com/drive/folders/1FqhPtE4S8JfbGgZU9uFjm-rjhGslpqEy?usp=sharing) and place it inside the `CONTACT/data` directory of the `CONTACT` repository. If the `data` directory does not exist, please create it.

---

## 3. Setup Apptainer for Training

To ensure a consistent and reproducible environment across clusters, workstations, and local PCs, we provide an Apptainer-based setup for CONTACT. System configurations and dependency versions may vary across machines, which can lead to compatibility issues.

Apptainer allows CONTACT to run inside a controlled Ubuntu-based container with all required dependencies pre-defined, simplifying setup and improving portability.

Please follow the steps below to configure the containerized training environment.

---

The repository includes Apptainer definition file `contact.def`. From the root directory of the repository, build the Apptainer image (`contact.sif`):

```bash
apptainer build contact.sif contact.def
```

You can then try running the container with:

```bash
apptainer exec --nv contact.sif bash
```

This will drop you into a bash shell inside the CONTACT compatible Ubuntu-based Apptainer environment.

Then, run the following commands inside the Apptainer environment to verify that everything is working correctly:

```bash
source ~/.bashrc
conda activate contact
export LD_LIBRARY_PATH=${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}
python -c "from isaacgym import gymtorch"
```
If the `gymtorch` library builds and imports correctly (that is, no errors appear), you can exit the Apptainer environment:

```bash
exit
```

---

## 4. CONTACT Run on Cluster with Slurm

Once the CONTACT environment and Apptainer container have been correctly set up, you can run training for any CONTACT task.
As an example, this section shows how to train a **vision-only Diffusion Policy** for the **Barbed Flat (S4)** disassembly task. Make sure that the CONTACT demo dataset for Barbed Flat has already been downloaded and placed in `CONTACT/data/barbed_flat`:

---

### 4.1 Creating the Slurm Submission Script

To run CONTACT training on the cluster, you need a Slurm job script.
Create a file named `job_submit.sh`:

```bash
touch job_submit.sh
```

Paste the following script into it:

> **Important:**
> Before using the job script below, update the following fields:
>
> - Search for `[user]` in the script file and replace `[user]` with your own cluster username.
> - Ensure that `CONTAINER_FILE` correctly points to where you stored your `contact.sif` file
>   ```
>   CONTAINER_FILE=/path/to/cluster/[user]/contact.sif
>   ```
> - Confirm that the `cd` command correctly points to your `CONTACT` repository path, matching the actual location of your `CONTACT` repo on the cluster.
>   ```
>   cd /path/to/cluster/[user]/CONTACT
>   ```


```bash
#!/bin/bash

SEED=42

NUM_DEMOS=50
NUM_EPOCH=500
DATASET_PATH=data/barbed_flat
ISAACGYM_CONFIG="isaacgym_config_barbed_flat.yaml"
ENV="barbed_flat"
LOG_NAME="dp_barbed_flat"
TASK_NAME=vision_disassembly
INPUT_TYPE="vision"
EXP_NAME="${INPUT_TYPE}_${ENV}_${NUM_DEMOS}"

JOB_NAME="${EXP_NAME}_${SEED}" # The name of the Slurm job to monitor

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
    cd /path/to/cluster/[user]/CONTACT
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
        logging.project=${LOG_NAME} \
"
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
```

---

### 4.2 Submitting the Training Job

Once the script is ready, grant the run permission

```bash
chmod +x job_submit.sh
```

then, submit it using:

```bash
./job_submit.sh
```

Slurm will schedule your job, and logs will appear in the `logs/` directory.

If everything runs correctly, you will see the success rate and selected simulation rollouts logged to your W&B account.

---

### 4.3 Running Vision + TacRGB Policy

To run the vision+tacRGB policy for the Barbed Flat task, create a new copy of the bash script file `job_submit.sh` and/or modify the following two fields in your `job_submit.sh` script:

```bash
TASK_NAME=vistac_disassembly
INPUT_TYPE="vistac"
```

After updating, submit the script file:

```bash
./job_submit.sh
```

---

### 4.4 Running Vision + TacFF Policy

To run the vision+tacFF (tactile force-field) policy for the Barbed Flat task, create a new copy of the bash script file `job_submit.sh` and/or modify the following two fields in your `job_submit.sh` script:

```bash
TASK_NAME=visff_disassembly
INPUT_TYPE="tacff"
```

After updating, submit the script file:

```bash
./job_submit.sh
```

### 4.5 Run Other CONTACT Tasks

You can run any CONTACT task by preparing the dataset and updating your `job_submit.sh` script.

First, download and unzip the demo dataset for your target task from the [CONTACT dataset link](https://drive.google.com/drive/folders/1FqhPtE4S8JfbGgZU9uFjm-rjhGslpqEy?usp=sharing), then place the extracted folder inside the `CONTACT/data` directory.

Next, create a new copy of `job_submit.sh` or modify your existing one by updating the following fields:

| Task | `DATASET_PATH` | `ISAACGYM_CONFIG` |
|------|-----------------|-------------------|
| S1 (Loose) | `data/loose_plug` | `isaacgym_config_looseplug.yaml` |
| S2 (Tight) | `data/tight_plug` | `isaacgym_config_tightplug.yaml` |
| S3 (Lidded) | `data/lidded_loose` | `isaacgym_config_liddedloose.yaml` |
| S4 (Barbed Flat) | `data/barbed_flat` | `isaacgym_config_barbed_flat.yaml` |
| S5 (Barbed Spike) | `data/barbed_spike` | `isaacgym_config_barbed_spike.yaml` |

For example, to run Task S1 (Loose Plug):

```bash
DATASET_PATH=data/loose_plug
ISAACGYM_CONFIG="isaacgym_config_looseplug.yaml"
ENV="loose_plug"
LOG_NAME="dp_loose_plug"
TASK_NAME=vision_disassembly
INPUT_TYPE="vision"
```

> **Note:**
> You can modify `TASK_NAME` and `INPUT_TYPE` to match the sensing configuration you want to test
> (vision-only, vision+tacRGB, or vision+tacFF).
> The valid task names for each modality are:
> - `TASK_NAME=vision_disassembly` for vision-only
> - `TASK_NAME=vistac_disassembly` for vision+tacRGB
> - `TASK_NAME=visff_disassembly` for vision+tacFF

After updating your script, start the run:

```bash
./job_submit.sh
```

> **Important:**
> Among the parameters in `job_submit.sh`, the most critical ones to update when switching tasks or sensing modalities are:
> `DATASET_PATH`, `ISAACGYM_CONFIG`, and `TASK_NAME`.
> Other fields primarily affect file naming and experiment logging.
>
> You can freely adjust `SEED`, `NUM_DEMOS`, and `NUM_EPOCH` to control the randomness seed, number of demonstrations used for training, and total training epochs.

---

## 5. Run CONTACT Locally (PC or Workstation)

This section mirrors the Cluster workflow but runs training directly on a local machine without Slurm. It assumes:

* `contact.sif` has already been built
* The `contact` Conda environment
* `scripts/run_local.sh` is available

---

### 5.1 Prepare the Local Script

Grant execution permission to the local script:

```bash
chmod +x scripts/run_local.sh
```

You can now launch training directly from your workstation. Logs and checkpoints will be saved under `data/outputs/${EXP_NAME}/${SEED}`. If everything runs correctly, you will see success rate metrics and rollout videos logged to your W&B account.

### 5.2 Running Vision-Only Policy
To run the vision-only **Barbed Flat** policy, override the following variables at launch time:

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vision_disassembly \
INPUT_TYPE=vision \
bash scripts/run_local.sh
```

You do not need to edit the script itself; the environment variables passed before the command override the default values inside `run_local.sh`.

### 5.3 Running Vision + TacRGB Policy
To run the vision + TacRGB policy, override:

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vistac_disassembly \
INPUT_TYPE=vistac \
bash scripts/run_local.sh
```

### 5.4 Running Vision + TacFF Policy
To run the vision + TacFF (tactile force-field) policy, override:

```bash
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=visff_disassembly \
INPUT_TYPE=tacff \
bash scripts/run_local.sh
```

### 5.5 Running Other CONTACT Tasks Locally
To run other tasks, override the required fields when launching (see Section 4.5 for the task configuration reference):

```bash
DATASET_PATH=data/loose_plug \
ISAACGYM_CONFIG=isaacgym_config_looseplug.yaml \
TASK_NAME=vision_disassembly \
INPUT_TYPE=vision \
bash scripts/run_local.sh
```

### 5.6 Important Parameters
When switching tasks or sensing modalities, the most critical variables are: `DATASET_PATH`, `ISAACGYM_CONFIG`, `TASK_NAME`, `INPUT_TYPE`.

You can also adjust training hyperparameters: `SEED`, `NUM_DEMOS`, `NUM_EPOCH`.

Example:
```bash
SEED=44 \
NUM_DEMOS=50 \
NUM_EPOCH=500 \
DATASET_PATH=data/barbed_spike \
ISAACGYM_CONFIG=isaacgym_config_barbed_spike.yaml \
TASK_NAME=visff_disassembly \
INPUT_TYPE=tacff \
bash scripts/run_local.sh
```

### 5.7 Summary
The local workflow is identical to the Cluster setup, except:
  * No Slurm submission or `job_submit.sh`
  * Direct execution via bash `scripts/run_local.sh`
  * All sensing configurations are controlled by overriding environment variables at launch time

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
