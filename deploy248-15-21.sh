#!/bin/bash

bin_name="./me-chaind"
admin_name="superadmin"
project_name="PM"
key="--keyring-backend=test"
key_dir="--keyring-dir=/home/user1/.me-chain/"
chain_id="--chain-id=me-chain"

genesis_file="/home/user1/me-test/deploy/genesis.json"
node_file="/home/user1/me-test/deploy"

# Clear process and node data, node1 required  Genesis files
function setup() {
  pkill me-chaind
  sleep 1
  rm -rf ./node*
}

node1_id=$1
echo "Start import nodeid:$1"

function startOtherNode() {
  echo "-----Script import nodeid: $node1_id"

  for i in {15..21}; do
    $bin_name init node$i $chain_id --home=node$i
    echo "-----init node$i finish..."
    sleep 2

    # copy genesis.json
    cp -f $genesis_file $node_file/node$i/config/

    # config file path
    app_toml="$node_file/node$i/config/app.toml"
    client_toml="$node_file/node$i/config/client.toml"
    config_toml="$node_file/node$i/config/config.toml"

    # update gas-prices
    sed -i 's#minimum-gas-prices = "0stake"#minimum-gas-prices = "0.0005umec"#g' $app_toml

    # api is enabled only on the first three nodes
    if [ $i -ge 3 ]; then
      # [api] Only change the content under the api
      sed -i '0,/enable = false/s//enable = true/' $app_toml
      sed -i 's#swagger = false#swagger = true#g' $app_toml
      sed -i 's#enabled-unsafe-cors = false#enabled-unsafe-cors = true#g' $app_toml
    fi

    if [ $i -ge 10 ]; then
      sed -i "s#address = \"tcp://0.0.0.0:1317\"#address = \"tcp://0.0.0.0:100$i\"#g" $app_toml
      sed -i "s#address = \"0.0.0.0:9090\"#address = \"0.0.0.0:200$i\"#g" $app_toml
      sed -i "s#address = \"0.0.0.0:9091\"#address = \"0.0.0.0:300$i\"#g" $app_toml
      sed -i "s#node = \"tcp://localhost:26657\"#node = \"tcp://localhost:500$i\"#g" $client_toml
      sed -i "s#proxy_app = \"tcp://127.0.0.1:26658\"#proxy_app = \"tcp://127.0.0.1:400$i\"#g" $config_toml
      sed -i "s#laddr = \"tcp://127.0.0.1:26657\"#laddr = \"tcp://0.0.0.0:500$i\"#g" $config_toml
      sed -i "s#pprof_laddr = \"localhost:6060\"#pprof_laddr = \"localhost:606$i\"#g" $config_toml
      sed -i "s#laddr = \"tcp://0.0.0.0:26656\"#laddr = \"tcp://0.0.0.0:600$i\"#g" $config_toml

    else

      sed -i "s#address = \"tcp://0.0.0.0:1317\"#address = \"tcp://0.0.0.0:1000$i\"#g" $app_toml
      sed -i "s#address = \"0.0.0.0:9090\"#address = \"0.0.0.0:2000$i\"#g" $app_toml
      sed -i "s#address = \"0.0.0.0:9091\"#address = \"0.0.0.0:3000$i\"#g" $app_toml
      sed -i "s#node = \"tcp://localhost:26657\"#node = \"tcp://localhost:5000$i\"#g" $client_toml
      sed -i "s#proxy_app = \"tcp://127.0.0.1:26658\"#proxy_app = \"tcp://127.0.0.1:4000$i\"#g" $config_toml
      sed -i "s#laddr = \"tcp://127.0.0.1:26657\"#laddr = \"tcp://0.0.0.0:5000$i\"#g" $config_toml
      sed -i "s#pprof_laddr = \"localhost:6060\"#pprof_laddr = \"localhost:6060$i\"#g" $config_toml
      sed -i "s#laddr = \"tcp://0.0.0.0:26656\"#laddr = \"tcp://0.0.0.0:6000$i\"#g" $config_toml

    fi

    sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $config_toml

    # [- p2p port]
    parent="192.168.88.8"
    ip1="127.0.0.1"
    ip2="192.168.88.10"
    if [ $i -eq 15 ]; then
      sed -i "s#seeds = \"\"#seeds = \"$node1_id\@$parent:26656\"#g" $config_toml
    elif ((i > 15)) && [ $((i % 2)) -eq 0 ]; then
      echo "----- The current value of i is $i, the current node is an even node, ip2: $ip2"
      if [ $i -le 10 ]; then
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip2:6000$(expr $i - 1)\"#g" $config_toml
      else
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip2:600$(expr $i - 1)\"#g" $config_toml
      fi
    elif ((i > 15)) && [ $((i % 2)) -ne 0 ]; then
      echo "----- The current value of i is $i, the current node is an odd number, ip1: $ip1"
      if [ $i -le 10 ]; then
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip1:6000$(expr $i - 1)\"#g" $config_toml
      else
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip1:600$(expr $i - 1)\"#g" $config_toml
      fi
    fi

    # Start other node. Traveling through the startup node requires dependencies node-id
    nohup $bin_name start --home node$i 1>node$i.log &
    echo "-----start node$i"
    sleep 5

    node_id=$($bin_name tendermint show-node-id --home=node$i)
    echo "-----output node$i node_id - $node_id"
  done
}

function main() {
  setup
  startOtherNode
}

main
