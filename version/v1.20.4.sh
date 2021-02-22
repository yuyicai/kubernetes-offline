#!/usr/bin/env bash

# export
export PLATFORM=amd64

# version
export DOCKER_VERSION=20.10.3
export KUBE_VERSION=v1.20.4
export CNI_VERSION=v0.8.7
export PAUSE_VERSION=3.2
export ETCD_VERSION=3.4.13-0
export COREDNS_VERSION=1.7.0
export NGINX_VERSION=1.17
export FLANNEL_VERSION=v0.11.0
export FLANNEL_VERSION_PLATFORM=v0.11.0-${PLATFORM}

# images
export HA_NGINX_IMAGE=nginx:${NGINX_VERSION}
export NETWOEK_FALNNEL=quay.io/coreos/flannel:${FLANNEL_VERSION_PLATFORM}
export KUBE_APISERVER_IMAGE=k8s.gcr.io/kube-apiserver:${KUBE_VERSION}
export KUBE_CONTROLLER_MANAGER_IMAGE=k8s.gcr.io/kube-controller-manager:${KUBE_VERSION}
export KUBE_SCHEDULER_IMAGE=k8s.gcr.io/kube-scheduler:${KUBE_VERSION}
export KUBE_PROXY_IMAGE=k8s.gcr.io/kube-proxy:${KUBE_VERSION}
export PAUSE_IMAGE=k8s.gcr.io/pause:${PAUSE_VERSION}
export ETCD_IMAGE=k8s.gcr.io/etcd:${ETCD_VERSION}
export COREDNS_IMAGE=k8s.gcr.io/coredns:${COREDNS_VERSION}

# download url
export DOCKER_URL=https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz
export KUBE_URL=https://dl.k8s.io/${KUBE_VERSION}/kubernetes-server-linux-amd64.tar.gz
export CNI_URL=https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz
