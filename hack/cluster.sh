#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DEFAULT_NAMESPACE=ccloud
DEFAULT_CLUSTER=ccloud-local

kind_setup() {
  CLUSTER_NAME=$1
  echo "===== 🤖 creating kind cluster with name $CLUSTER_NAME"

  if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo "===== 🤖 kind cluster already created "
  else
    kind create cluster --name "$CLUSTER_NAME" --config "${SCRIPT_DIR}"/config/kind-config.yaml
    if [ $? -ne 0 ]; then
      echo "===== 👎 failed to create kind cluster "
      exit 1
    fi
    namespace_setup
  fi

  kubectl cluster-info --context kind-"$CLUSTER_NAME"
}

namespace_setup() {
  echo "===== 🤖 creating namespace $DEFAULT_NAMESPACE"
  kubectl create namespace $DEFAULT_NAMESPACE
  gum spin --spinner dot --title "===== 🤖 Setting  $DEFAULT_NAMESPACE to current context..." -- sleep 2
  kubectl config set-context --current --namespace=$DEFAULT_NAMESPACE
}

k3d_setup() {
  CLUSTER_NAME=$1
  echo "===== 🤖 creating k3d cluster with name $CLUSTER_NAME"

  if k3d cluster list "$CLUSTER_NAME" 2>/dev/null; then
    k3d cluster start "$CLUSTER_NAME"
  else
    k3d cluster create "$CLUSTER_NAME" --registry-create ccloud-registry
    if [ $? -ne 0 ]; then
      echo "===== 👎 failed to create k3d cluster..."
      exit 1
    fi
    namespace_setup
  fi

  kubectl cluster-info --context k3d-"$CLUSTER_NAME"
}

create_cluster() {
  echo "===== 🤖 Choose a local cluster type to create..."
  CLUSTER_TYPE=$(gum choose "k3d" "kind")
  echo "===== 🤖 Provide name of cluster..."
  CLUSTER_NAME=$(gum input --placeholder $DEFAULT_CLUSTER --value $DEFAULT_CLUSTER)
  case $CLUSTER_TYPE in
  kind) kind_setup $CLUSTER_NAME ;;
  k3d) k3d_setup $CLUSTER_NAME ;;
  esac
}

delete_cluster() {
  echo "===== 🤖 Choose a local cluster type to delete"
  CLUSTER_TYPE=$(gum choose "k3d" "kind")
  if [[ $CLUSTER_TYPE == "kind" ]]; then
    LIST=$(kind get clusters)
    DELETE_CLUSTER=$(gum choose $LIST)
    if [[ ! -z $DELETE_CLUSTER && $DELETE_CLUSTER == *"gum"* ]]; then
      echo "===== 🤖 Nothing to delete..."
    else
      gum confirm "===== 🗑 Are you sure you want to delete CLUSTER?: $DELETE_CLUSTER" && kind delete cluster --name $DELETE_CLUSTER
    fi
  fi
  if [[ $CLUSTER_TYPE == "k3d" ]]; then
    LIST=$(k3d cluster list | cut -d " " -f 1 | sed "1 d")
    DELETE_CLUSTER=$(gum choose $LIST)
    if [[ ! -z $DELETE_CLUSTER && $DELETE_CLUSTER == *"gum"* ]]; then
      echo "===== 🤖 Nothing to delete..."
    else
      gum confirm "===== 🗑 Are you sure you want to delete CLUSTER?: $DELETE_CLUSTER" && k3d cluster delete $DELETE_CLUSTER
    fi
  fi
}

main() {
  install
  TYPE=$(gum choose "CREATE-CLUSTER" "DELETE-CLUSTER")
  case $TYPE in
  CREATE-CLUSTER) create_cluster ;;
  DELETE-CLUSTER) delete_cluster ;;
  esac
}

source "${SCRIPT_DIR}/install.sh"
main
