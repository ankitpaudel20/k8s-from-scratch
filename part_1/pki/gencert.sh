#!/bin/bash
#

set -euo pipefail

PROFILE_FILE="./ca-config.json"
ROOT_CA_DIR="./root-ca"

## root-ca
cfssl gencert -initca "$ROOT_CA_DIR/ca-csr.json" | cfssljson -bare "$ROOT_CA_DIR/root-ca"

for folder in ./*; do
    if [ -d "$folder" ] && [ "$folder" != "./root-ca" ]; then
        for file in "$folder"/*.json; do
            echo "Generating cert for using csr file: $file"

            # Determine profile: peer if file contains -peer, server if it defines hosts (SANs), otherwise client
            if [[ "$file" == *"-peer"* ]] || [[ "$file" == *"worker-"* ]]; then
                PROFILE="peer"
            elif grep -q '"hosts"' "$file"; then
                PROFILE="server"
            else
                PROFILE="client"
            fi

            echo "Profile: $PROFILE"


            cfssl gencert \
            -ca="$ROOT_CA_DIR/root-ca.pem" \
            -ca-key="$ROOT_CA_DIR/root-ca-key.pem" \
            -config="$PROFILE_FILE" \
            -profile="$PROFILE" \
            "$file" | cfssljson -bare "$folder/$(basename "$file" .json)"
        done
    fi
done
