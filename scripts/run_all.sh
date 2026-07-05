#!/usr/bin/env bash
# Run one modality across ALL tasks, sequentially.
#   bash scripts/run_all.sh vision [seed] [overrides...]
#   bash scripts/run_all.sh all    [seed]            # all 3 modalities x all 5 tasks
set -euo pipefail
MODALITY=${1:?usage: run_all.sh <vision|vistac|visff|all> [seed] [overrides...]}
SEED=${2:-42}
EXTRA=("${@:3}")
TASKS=(loose_plug tight_plug lidded_loose barbed_flat barbed_spike)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODS=("${MODALITY}")
[ "${MODALITY}" = "all" ] && MODS=(vision vistac visff)
for mod in "${MODS[@]}"; do
    for task in "${TASKS[@]}"; do
        echo "==== ${mod} | ${task} | seed ${SEED} ===="
        bash "${REPO_ROOT}/training/${task}/${mod}.sh" "${SEED}" "${EXTRA[@]+"${EXTRA[@]}"}"
    done
done
