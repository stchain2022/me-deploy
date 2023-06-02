#!/bin/bash

bin_name="./me-chaind"
admin_name="superadmin"
project_name="PM"
key="--keyring-backend=test"
key_dir="--keyring-dir=/home/user1/.me-chain/"
chain_id="--chain-id=me-chain"
home="--home=node1"

genesis_file="/home/user1/me-test/deploy/node1/config/genesis.json"
node1_app_toml="/home/user1/me-test/deploy/node1/config/app.toml"
node_file="/home/user1/me-test/deploy"

# Clear process and node data
function setup() {
  pkill me-chaind
  sleep 1
  rm -rf ./node*
}

# Start One node
function startMainNode() {
  $bin_name init node1 $chain_id $home
  echo "-----init node1 finish..."
  sleep 1

  # Create superadmin and project manage
  echo "y" | $bin_name keys add $admin_name $key
  echo "y" | $bin_name keys add $project_name $key

  # Allocate genesis accounts (cosmos formatted addresses)
  $bin_name add-genesis-account $($bin_name keys show $admin_name -a $key) 0mec $home
  $bin_name add-genesis-account $($bin_name keys show $project_name -a $key) 0mec $home
  $bin_name add-genesis-module-account stake_tokens_pool 10000000000mec $home

  # Admin create validator stake 50000000mec
  $bin_name gentx $admin_name 50000000mec $key $chain_id $home $key_dir

  # Collect genesis txs
  $bin_name collect-gentxs $home

  updateMainConfig

  nohup $bin_name start $home 1>node1.log &
  echo "-----start node1"
  sleep 10
}

function updateMainConfig() {
  # config file path
  app_toml="$node_file/node1/config/app.toml"
  client_toml="$node_file/node1/config/client.toml"
  config_toml="$node_file/node1/config/config.toml"

  # [api] Only change the content under the api
  sed -i '0,/enable = false/s//enable = true/' $app_toml
  sed -i 's#swagger = false#swagger = true#g' $app_toml
  sed -i 's#enabled-unsafe-cors = false#enabled-unsafe-cors = true#g' $app_toml
  # sed -i 's#address = "tcp://0.0.0.0:1317"#address = "tcp://0.0.0.0:10001"#g' $app_toml
  # [grpc]
  #sed -i 's#address = "0.0.0.0:9090"#address = "0.0.0.0:20001"#g' $app_toml
  # [grpc-web]
  #sed -i 's#address = "0.0.0.0:9091"#address = "0.0.0.0:30001"#g' $app_toml

  # [node]
  #sed -i 's#node = "tcp://localhost:26657"#node = "tcp://localhost:50001"#g' $client_toml

  #sed -i 's#proxy_app = "tcp://127.0.0.1:26658"#proxy_app = "tcp://127.0.0.1:40001"#g' $config_toml
  # [rpc]
  sed -i 's#laddr = "tcp://127.0.0.1:26657"#laddr = "tcp://0.0.0.0:26657"#g' $config_toml
  sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $config_toml
  # [p2p]
  #sed -i 's#laddr = "tcp://0.0.0.0:26656"#laddr = "tcp://0.0.0.0:60001"#g' $config_toml

  sleep 1
  echo "-----Update node1 config finish..."
}

function startOtherNode() {
  node1_id=$($bin_name tendermint show-node-id $home)
  echo "-----output node1_id - $node1_id"

  for i in {2..7}; do
    $bin_name init node$i $chain_id --home=node$i
    echo "-----init node$i finish..."
    sleep 1

    # copy genesis.json
    cp $genesis_file $node_file/node$i/config/

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
    ip1="127.0.0.1"
    ip2="192.168.88.8"
    if [ $i -eq 2 ]; then
      sed -i "s#seeds = \"\"#seeds = \"$node1_id\@$ip2:26656\"#g" $config_toml
    elif ((i > 2)) && [ $((i % 2)) -eq 0 ]; then
      if [ $i -le 10 ]; then
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip2:6000$(expr $i - 1)\"#g" $config_toml
      else
        sed -i "s#seeds = \"\"#seeds = \"$node_id\@$ip2:600$(expr $i - 1)\"#g" $config_toml
      fi
    elif ((i > 2)) && [ $((i % 2)) -ne 0 ]; then
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

function setFixedDepositInterestRate() {
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_1_MONTHS 0.05 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=1
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_3_MONTHS 0.10 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=2
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_6_MONTHS 0.15 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=3
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_12_MONTHS 0.20 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=4
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_24_MONTHS 0.30 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=5
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_36_MONTHS 0.40 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=6
  $bin_name tx staking set-fixed-deposit-interest-rate TERM_48_MONTHS 0.50 --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y -s=7
  sleep 10
  $bin_name q staking show-fixed-deposit-interest-rate
}

function sendToAdmin() {
  echo "-----sendToAdmin"
  $bin_name tx bank sendToAdmin 1000mec --from=$($bin_name keys show $admin_name -a $key) $chain_id $key -y
  sleep 10
  echo "-----superadmin balances"
  $bin_name q bank balances $($bin_name keys show $admin_name -a $key)
}

function updateNode1GasPrice() {
  echo "-----UpdateNode1GasPrice"
  sed -i 's#minimum-gas-prices = "0stake"#minimum-gas-prices = "0.0005umec"#g' $node1_app_toml
  sleep 1
}

function restartNode1() {
  pid=$(ps -ef | grep 'me-chaind start --home=node1' | grep -v grep | awk '{print $2}')
  kill $pid
  echo "-----kill node1 pid - $pid"
  sleep 2
  echo "-----Restart node1"
  nohup $bin_name start --home node1 1>node1.log &
  echo "-----Viewing process information"
  ps -ef | grep me-chaind
}

function main() {
  setup
  startMainNode
  startOtherNode
  setFixedDepositInterestRate
  sendToAdmin
  updateNode1GasPrice
  restartNode1
}

main
