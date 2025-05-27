#! /usr/bin/env bash
# This script updates a DNS record using the Cloudflare API.
set -euo pipefail

function get_my_ip() {
    curl -s https://api.ipify.org
}

function get_zone_id() {
    local zone_name="$1"
    local api_token="${CLOUDFLARE_API_TOKEN}"

    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${api_token}")

    if echo "$response" | grep -q '"success":true'; then
        echo "$response" | jq -r '.result[0].id'
    else
        echo "Failed to retrieve zone ID for ${zone_name}. Response: $response"
        exit 1
    fi
}

function get_dns_record_id() {
    local zone_id="$1"
    local api_token="${CLOUDFLARE_API_TOKEN}"

    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${api_token}")

    if echo "${response}" | grep -q '"success":true'; then
        for record in $(echo "${response}" | jq -r '.result[] | select(.type=="A") | .id'); do
            echo "${record}"
            return
        done
    else
        echo "Failed to retrieve DNS record ID for ${record_name}. Response: $response"
        exit 1
    fi
}

function update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local ip_address="$3"
    local api_token="${CLOUDFLARE_API_TOKEN}"

    local max_attempts=3
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        if response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${api_token}" \
            -d '{
                "type": "A",
                "name": "tahmidcloud.com",
                "content": "'"${ip_address}"'",
                "ttl": 1,
                "proxied": false
            }'); then
            if echo "$response" | grep -q '"success":true'; then
                success=true
            else
                echo "Attempt $attempt failed. Response: $response"
            fi
        fi

        if [ "$success" = false ] ; then
            if [ $attempt -lt $max_attempts ]; then
                echo "Retrying in 5 seconds..."
                sleep 5
            fi
            ((attempt++))
        fi
    done

    if [ "$success" = false ]; then
        echo "Failed to update DNS record after ${max_attempts} attempts"
        exit 1
    fi
    echo "DNS record updated successfully to IP address: ${ip_address}"
}

function main() {
    if ! CLOUDFLARE_API_TOKEN=$(grep -A2 'machine api.cloudflare.com' "${HOME}/.netrc" \
        | grep 'password' | awk '{print $2}'); then
        echo "Failed to read Cloudflare API token from .netrc file"
        exit 1
    fi

    if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
        echo "CLOUDFLARE_API_TOKEN environment variable is not set."
        exit 1
    fi

    zone_id=$(get_zone_id "tahmidcloud.com")
    record_id=$(get_dns_record_id "${zone_id}")
    ip_address=$(get_my_ip)

    update_dns_record "${zone_id}" "${record_id}" "${ip_address}"
}

main