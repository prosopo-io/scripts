#! /bin/bash

set -eu

# expect this script to be run from the scripts directory and the protocol directory to be adjacent to the scripts dir
if [ ! -d "../protocol" ]; then
    echo "protocol repo not found as sibling directory"
    exit 1
fi

if [ $(basename $(pwd)) != "scripts" ]; then
    echo "this script must be run from the scripts directory"
    exit 1
fi

# # stop any running substrate containers
docker ps | grep prosopo/substrate | awk '{print $1}' | xargs docker rm -f
# # remove any old substrate images
docker image ls | grep prosopo/substrate | awk '{print $3}' | xargs docker rmi -f

# get the latest build tools
docker pull paritytech/contracts-ci-linux:production

# get the latest substrate node
docker compose --file ./docker/docker-compose.development.yml pull

# spin up containers for substrate node
docker compose --file ./docker/docker-compose.development.yml rm -sf
docker compose --file ./docker/docker-compose.development.yml up -d
docker ps

# build the contract in the protocol repo
echo
echo "building contract, please wait..."
docker run --rm -it -v $(pwd)/../protocol/contracts:/contracts paritytech/contracts-ci-linux:production cargo +nightly contract build --manifest-path=/contracts/Cargo.toml

# instantiate the contract using Alice's account
echo
echo "instantiating contract, please wait..."

cd ../protocol

docker run --network host --rm -it -v $(pwd)/contracts:/contracts paritytech/contracts-ci-linux:production cargo contract instantiate /contracts/target/ink/prosopo.wasm --args 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY 1000000000000 --constructor default --suri "//Alice" --value 2000000000000 --url ws://localhost:9944 --manifest-path /contracts/Cargo.toml --verbose  --skip-confirm | tee instantiate.log

# get the contract address and code hash from the instantiate log
contractAddr=$( cat instantiate.log | grep "Contract" | tail -n 1 | awk '{print $3}')
codeHash=$( cat instantiate.log | grep "Code hash" | awk '{print $4}')

cd ../scripts 

echo "Contract at:"
echo $contractAddr
echo "Code hash:"
echo $codeHash

# for each repo needing knowledge of the contract address, update the corresponding .env file with the new address
echo "updating provider .env.development file"
sed -i '/^CONTRACT_ADDRESS=/{h;s/=.*/='"$contractAddr"'/};${x;/^$/{s//CONTRACT_ADDRESS='"$contractAddr"'/;H};x}' ../workspaces/packages/provider/.env.development

echo "updating client-example .env.development file"
sed -i '/^REACT_APP_PROSOPO_CONTRACT_ADDRESS=/{h;s/=.*/='"$contractAddr"'/};${x;/^$/{s//REACT_APP_PROSOPO_CONTRACT_ADDRESS='"$contractAddr"'/;H};x}' ../workspaces/demos/client-example/.env.development

echo "updating client-example-server .env.development file"
sed -i '/^REACT_APP_PROSOPO_CONTRACT_ADDRESS=/{h;s/=.*/='"$contractAddr"'/};${x;/^$/{s//REACT_APP_PROSOPO_CONTRACT_ADDRESS='"$contractAddr"'/;H};x}' ../workspaces/demos/client-example-server/.env.development

echo "updating demo-nft-marketplace .env.development file"
sed -i '/^NEXT_PUBLIC_PROSOPO_CONTRACT_ADDRESS=/{h;s/=.*/='"$contractAddr"'/};${x;/^$/{s//NEXT_PUBLIC_PROSOPO_CONTRACT_ADDRESS='"$contractAddr"'/;H};x}' ../workspaces/demos/demo-nft-marketplace/.env.development