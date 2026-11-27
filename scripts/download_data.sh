#!/usr/bin/env bash
# Download the CONTACT dataset from Hugging Face into data/.
#
#   bash scripts/download_data.sh barbed_flat        # one task
#   bash scripts/download_data.sh all                # all five tasks
#
# Tasks: loose_plug tight_plug lidded_loose barbed_flat barbed_spike
# Dataset page: https://huggingface.co/datasets/Adeesh09/CONTACT
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_ROOT}/data"
BASE_URL="https://huggingface.co/datasets/Adeesh09/CONTACT/resolve/main"
TASKS=(loose_plug tight_plug lidded_loose barbed_flat barbed_spike)

REQUESTED=("$@")
[ ${#REQUESTED[@]} -eq 0 ] && { echo "usage: $0 <task...|all>   tasks: ${TASKS[*]}"; exit 1; }
[ "${REQUESTED[0]}" = "all" ] && REQUESTED=("${TASKS[@]}")
for task in "${REQUESTED[@]}"; do
    [[ " ${TASKS[*]} " == *" ${task} "* ]] || { echo "ERROR: unknown task '${task}' (tasks: ${TASKS[*]})" >&2; exit 1; }
done

mkdir -p "${DATA_DIR}"
for task in "${REQUESTED[@]}"; do
    if [ -d "${DATA_DIR}/${task}" ]; then
        echo "OK ${task} already extracted"
        continue
    fi
    zip_path="${DATA_DIR}/${task}.zip"
    if [ ! -f "${zip_path}" ]; then
        echo "Downloading ${task}.zip ..."
        # download to .part (resumable) so an interrupted download is never unzipped
        if command -v curl >/dev/null 2>&1; then
            curl -L --fail --retry 3 -C - -o "${zip_path}.part" "${BASE_URL}/${task}.zip"
        else
            wget -c -O "${zip_path}.part" "${BASE_URL}/${task}.zip"
        fi
        mv "${zip_path}.part" "${zip_path}"
    fi
    unzip -q -o "${zip_path}" -d "${DATA_DIR}"
    rm -f "${zip_path}"
    echo "OK data/${task}"
done
echo "Done."
