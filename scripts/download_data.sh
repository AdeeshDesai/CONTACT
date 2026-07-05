#!/usr/bin/env bash
# Download the CONTACT dataset from Google Drive into data/.
#
#   bash scripts/download_data.sh barbed_flat        # one task
#   bash scripts/download_data.sh all                # all five tasks
#
# Tasks: loose_plug tight_plug lidded_loose barbed_flat barbed_spike
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_ROOT}/data"
FOLDER_URL="https://drive.google.com/drive/folders/1FqhPtE4S8JfbGgZU9uFjm-rjhGslpqEy"
TASKS=(loose_plug tight_plug lidded_loose barbed_flat barbed_spike)

REQUESTED=("$@")
[ ${#REQUESTED[@]} -eq 0 ] && { echo "usage: $0 <task...|all>   tasks: ${TASKS[*]}"; exit 1; }
[ "${REQUESTED[0]}" = "all" ] && REQUESTED=("${TASKS[@]}")

command -v gdown >/dev/null 2>&1 || pip install gdown

mkdir -p "${DATA_DIR}"
# gdown fetches the whole Drive folder (individual files inside a folder
# cannot be addressed without their per-file ids)
NEED_FETCH=false
for task in "${REQUESTED[@]}"; do
    [ -d "${DATA_DIR}/${task}" ] || [ -f "${DATA_DIR}/${task}.zip" ] || NEED_FETCH=true
done
if [ "${NEED_FETCH}" = "true" ]; then
    gdown --folder "${FOLDER_URL}" -O "${DATA_DIR}"
    # the folder may download into a subdirectory; flatten zips into data/
    find "${DATA_DIR}" -maxdepth 2 -name "*.zip" -exec mv -n {} "${DATA_DIR}/" \; 2>/dev/null || true
fi

for task in "${REQUESTED[@]}"; do
    if [ -d "${DATA_DIR}/${task}" ]; then
        echo "OK ${task} already extracted"
        continue
    fi
    if [ ! -f "${DATA_DIR}/${task}.zip" ]; then
        echo "ERROR: ${task}.zip not found after download" >&2
        exit 1
    fi
    unzip -q -o "${DATA_DIR}/${task}.zip" -d "${DATA_DIR}"
    rm -f "${DATA_DIR}/${task}.zip"
    echo "OK data/${task}"
done
echo "Done."
