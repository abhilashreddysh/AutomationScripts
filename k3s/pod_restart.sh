#!/bin/bash

set -eo pipefail

# === CONFIGURATION ===
NAMESPACE="ns-homelab"
LOG_FILE="/tmp/${NAMESPACE}_pod_restart.log"
MAX_AGE_MINUTES=30          # Maximum allowed pod start age in minutes
ROLLBACK_ON_FAILURE=true    # Enable rollback if rollout fails
ROLLBACK_RETRY=3            # Number of rollback retry attempts
RESTART_RETRY=2             # Number of rollout restart retry attempts
ROLLOUT_TIMEOUT="30m"       # Timeout duration for rollout status check
SLEEP_BETWEEN_RETRIES=15    # Seconds to wait between retries

# === SETUP LOGGING ===
mkdir -p "$(dirname "$LOG_FILE")"
> "$LOG_FILE"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    echo "[$(timestamp)] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# === HELPER FUNCTIONS ===

retry_command() {
    local retries=$1
    shift
    local attempt=1
    until "$@"; do
        local exit_code=$?
        if (( attempt >= retries )); then
            return $exit_code
        fi
        log "Warning: Command '$*' failed (attempt $attempt/$retries). Retrying after $SLEEP_BETWEEN_RETRIES seconds."
        ((attempt++))
        sleep $SLEEP_BETWEEN_RETRIES
    done
    return 0
}

rollback_deployment() {
    local deployment=$1
    local attempt=1

    while (( attempt <= ROLLBACK_RETRY )); do
        log "Attempting rollback of deployment '$deployment' (attempt $attempt/$ROLLBACK_RETRY)."
        if kubectl rollout undo deployment/"$deployment" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1; then
            log "Rollback successful for deployment '$deployment'."
            return 0
        else
            log "Warning: Rollback attempt $attempt for deployment '$deployment' failed."
            ((attempt++))
            sleep $SLEEP_BETWEEN_RETRIES
        fi
    done

    log "Rollback failed after $ROLLBACK_RETRY attempts for deployment '$deployment'."
    return 1
}

restart_deployment() {
    local deployment=$1
    local attempt=1

    while (( attempt <= RESTART_RETRY )); do
        log "Restarting deployment '$deployment' (attempt $attempt/$RESTART_RETRY)."
        if kubectl rollout restart deployment/"$deployment" -n "$NAMESPACE" >> "$LOG_FILE" 2>&1; then
            log "Rollout restart command succeeded for deployment '$deployment'. Waiting for rollout to complete. (Waiting ${ROLLOUT_TIMEOUT})"
            if kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" >> "$LOG_FILE" 2>&1; then
                log "Rollout completed successfully for deployment '$deployment'."
                return 0
            else
                log "Warning: Rollout status check failed or timed out for deployment '$deployment'."
            fi
        else
            log "Warning: Rollout restart command failed for deployment '$deployment'."
        fi

        ((attempt++))
        log "Retrying rollout restart for deployment '$deployment' after $SLEEP_BETWEEN_RETRIES seconds."
        sleep $SLEEP_BETWEEN_RETRIES
    done

    if $ROLLBACK_ON_FAILURE; then
        log "Initiating rollback due to rollout failure for deployment '$deployment'."
        rollback_deployment "$deployment"
    fi

    return 1
}

check_pod_ready() {
    local pod=$1
    local namespace=$2

    # Fetch readiness condition from pod status
    local ready_status
    ready_status=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

    if [[ "$ready_status" == "True" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

verify_pods() {
    log "Verifying pods in namespace '$NAMESPACE' for readiness and start time within the last $MAX_AGE_MINUTES minutes."

    local now
    now=$(date +%s)
    local failed=0

    # Fetch pods with metadata
    mapfile -t pods < <(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name} {.status.startTime} {.status.phase}{"\n"}{end}')

    for pod_info in "${pods[@]}"; do
        pod=$(echo "$pod_info" | awk '{print $1}')
        start_time=$(echo "$pod_info" | awk '{print $2}')
        phase=$(echo "$pod_info" | awk '{print $3}')

        if [[ "$phase" != "Running" ]]; then
            log "Warning: Pod '$pod' is in phase '$phase', expected 'Running'. Pod may not be ready."
            failed=1
            continue
        fi

        local ready
        ready=$(check_pod_ready "$pod" "$NAMESPACE")
        if [[ "$ready" != "true" ]]; then
            log "Warning: Pod '$pod' readiness check failed. Pod is not Ready."
            failed=1
            continue
        fi

        if [[ -z "$start_time" ]]; then
            log "Warning: Pod '$pod' does not have a recorded start time. Possible pending or initialization state."
            failed=1
            continue
        fi

        # Attempt to parse start_time to epoch seconds (Linux and macOS compatibility)
        start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null || echo "")

        if [[ -z "$start_epoch" ]]; then
            log "Warning: Unable to parse start time '$start_time' for pod '$pod'."
            failed=1
            continue
        fi

        local age_minutes=$(( (now - start_epoch) / 60 ))

        if (( age_minutes > MAX_AGE_MINUTES )); then
            log "Error: Pod '$pod' was started $age_minutes minutes ago, exceeding the maximum allowed age of $MAX_AGE_MINUTES minutes."
            failed=1
        else
            log "Pod '$pod' was started $age_minutes minutes ago and is within the allowed age threshold."
        fi
    done

    if (( failed )); then
        error_exit "Pod readiness and start time verification failed. One or more pods are not ready or too old."
    else
        log "All pods are confirmed Ready and started within the acceptable time frame."
    fi
}

# === MAIN SCRIPT ===

log "Starting pod restart process in namespace '$NAMESPACE'."

deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}') || error_exit "Failed to retrieve deployments in namespace '$NAMESPACE'."

if [[ -z "$deployments" ]]; then
    error_exit "No deployments found in namespace '$NAMESPACE'. Exiting."
fi

for deployment in $deployments; do
    if ! restart_deployment "$deployment"; then
        error_exit "Failed to restart deployment '$deployment'. Exiting process."
    fi
done

verify_pods

log "Pod restart process completed successfully in namespace '$NAMESPACE'."
exit 0
