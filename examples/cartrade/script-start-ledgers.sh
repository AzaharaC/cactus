#!/usr/bin/env bash
# Copyright 2020-2022 Hyperledger Cactus Contributors
# SPDX-License-Identifier: Apache-2.0

set -e

ROOT_DIR="../.." # Path to cactus root dir
WAIT_TIME=30 # How often to check container status
CONFIG_VOLUME_PATH="./etc/cactus" # Docker volume with shared configuration

# Fabric Env Variables
export CACTUS_FABRIC_ALL_IN_ONE_CONTAINER_NAME="cartrade_faio14x_testnet"
export CACTUS_FABRIC_TEST_LOOSE_MEMBERSHIP=1 # Loose membership check required for cartrade

function start_fabric_testnet() {
    echo ">> start_fabric_testnet()"
    pushd "${ROOT_DIR}/tools/docker/fabric-all-in-one"

    echo ">> Start Fabric 1.4 FabCar..."
    docker-compose -f ./docker-compose-v1.4.yml build
    docker-compose -f ./docker-compose-v1.4.yml up -d
    sleep 1

    # Wait for fabric cotnainer to become healthy
    health_status="$(docker inspect -f '{{.State.Health.Status}}' ${CACTUS_FABRIC_ALL_IN_ONE_CONTAINER_NAME})"
    while ! [ "${health_status}" == "healthy" ]
    do
        echo "Waiting for fabric container... current status => ${health_status}"
        sleep $WAIT_TIME
        health_status="$(docker inspect -f '{{.State.Health.Status}}' ${CACTUS_FABRIC_ALL_IN_ONE_CONTAINER_NAME})"
    done
    echo ">> Fabric 1.4 FabCar started."

    echo ">> Register admin and user1..."
    pushd fabcar-cli-1.4
    ./setup.sh
    popd
    echo ">> Register done."

    echo ">> start_fabric_testnet() done."
    popd
}

function copy_fabric_tlsca() {
    echo ">> copy_fabric_tlsca()"
    mkdir -p "${CONFIG_VOLUME_PATH}/fabric"
    docker cp "${CACTUS_FABRIC_ALL_IN_ONE_CONTAINER_NAME}:/fabric-samples/first-network/crypto-config/" "${CONFIG_VOLUME_PATH}/fabric/"
    echo ">> copy_fabric_tlsca() done."
}

function copy_fabric_wallet() {
    echo ">> copy_fabric_wallet()"
    cp -fr "../../tools/docker/fabric-all-in-one/fabcar-cli-1.4/wallet" "${CONFIG_VOLUME_PATH}/fabric/"
    echo ">> copy_fabric_wallet() done."
}

function start_ethereum_testnet() {
    pushd "../../tools/docker/geth-testnet"
    ./script-start-docker.sh
    popd
}

function start_ledgers() {
    # Clear ./etc/cactus
    mkdir -p "${CONFIG_VOLUME_PATH}/"
    rm -fr "${CONFIG_VOLUME_PATH}/*"

    # Copy cmd-socketio-config
    cp -f ./config/*.yaml "${CONFIG_VOLUME_PATH}/"

    # Start Fabric
    start_fabric_testnet
    copy_fabric_tlsca
    copy_fabric_wallet

    # Start Ethereum
    start_ethereum_testnet
}

start_ledgers
echo "All Done."
