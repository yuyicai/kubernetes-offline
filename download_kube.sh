#!/usr/bin/env bash

KUBE=/tmp/.kubei
TEMP=${KUBE}/temp
PKG=${KUBE}/pkg

gen_docker_conf() {
    echo "gen docker config"
    mkdir -p ${TEMP}/container_engine/etc/systemd/system/
    cat <<EOF >${TEMP}/container_engine/etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/usr/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target

EOF

    cat <<'EOF' >${TEMP}/container_engine/etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target containerd.service
Wants=network-online.target docker.socket

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID

TimeoutSec=0
RestartSec=2
Restart=always

StartLimitBurst=3
StartLimitInterval=60s

LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
}

download_docker() {
    echo "Downloading Docker"
    curl -sSL -o ${TEMP}/docker-${DOCKER_VERSION}.tgz ${DOCKER_URL}
    mkdir -p ${TEMP}/container_engine/usr/bin || true
    echo "Decompress docker to container_engine/usr/bin/"
    tar --strip-components=1 --no-same-owner -xvf ${TEMP}/docker-${DOCKER_VERSION}.tgz -C ${TEMP}/container_engine/usr/bin/
    rm -f ${TEMP}/docker-${DOCKER_VERSION}.tgz
    mkdir -p ${TEMP}/container_engine/etc/systemd/system || true

    cd ${TEMP}/container_engine || exit 1
    mkdir ${PKG}/container_engine || true
    echo "Compress ${PKG}/container_engine/docker-${DOCKER_VERSION}.tgz"
    tar --owner=0 --group=0 -zcvf ${PKG}/container_engine/docker-${DOCKER_VERSION}.tgz ./

    cat <<EOF >${PKG}/container_engine/default.sh
#!/usr/bin/env bash

DOCKER_VERSION=${DOCKER_VERSION}
EOF
    cat <<"EOF" >>${PKG}/container_engine/default.sh
DOCKER_TGZ=$(dirname $0)/docker-${DOCKER_VERSION}.tgz
echo "tar --no-same-owner -xf ${DOCKER_TGZ} -C /"
tar --no-same-owner -xf ${DOCKER_TGZ} -C /
EOF

    chmod 755 ${PKG}/container_engine/default.sh
}

gen_kubernetes_conf() {
    echo "gen kubernetes config"
    mkdir -p ${TEMP}/kube/etc/systemd/system/
    cat <<'EOF' > ${TEMP}/kube/etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p ${TEMP}/kube/etc/systemd/system/kubelet.service.d/
    cat <<'EOF' > ${TEMP}/kube/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF

    mkdir -p ${PKG}/kube/
    cat <<EOF >${PKG}/kube/default.sh
#!/usr/bin/env bash

KUBE_VERSION=${KUBE_VERSION}
CNI_VERSION=${CNI_VERSION}
EOF

    mkdir -p ${PKG}/kube/
    cat <<"EOF" >>${PKG}/kube/default.sh
KUBE_TGZ=$(dirname $0)/kube-${KUBE_VERSION}.tgz
echo "tar --no-same-owner -xf ${KUBE_TGZ} -C /"
tar --no-same-owner -xf ${KUBE_TGZ} -C /

CNI_TGZ=$(dirname $0)/cni-plugins-linux-amd64-${CNI_VERSION}.tgz
echo "tar --no-same-owner -xf ${CNI_TGZ} -C /opt/cni/bin"
mkdir -p /opt/cni/bin || true
tar --no-same-owner -xf ${CNI_TGZ} -C /opt/cni/bin
EOF
    chmod 755 ${PKG}/kube/default.sh
}

download_kubernetes() {
    # Download kubernetes
    echo "Download kubernetes"
    curl -sSL -o ${TEMP}/kubernetes-server-linux-amd64.tar.gz ${KUBE_URL}
    tar xvf ${TEMP}/kubernetes-server-linux-amd64.tar.gz -C ${TEMP}

    mkdir -p ${TEMP}/kube/usr/bin || true
    cp -p ${TEMP}/kubernetes/server/bin/kubeadm ${TEMP}/kube/usr/bin
    cp -p ${TEMP}/kubernetes/server/bin/kubectl ${TEMP}/kube/usr/bin
    cp -p ${TEMP}/kubernetes/server/bin/kubelet ${TEMP}/kube/usr/bin

    cd ${TEMP}/kube || exit 1
    mkdir ${PKG}/kube || true
    echo "Compress ${PKG}/kube/kube-${KUBE_VERSION}.tgz"
    tar --owner=0 --group=0 -zcvf ${PKG}/kube/kube-${KUBE_VERSION}.tgz ./
}

download_cni() {
    # Download CNI
    echo "download cni"
    curl -sSL -o ${PKG}/kube/cni-plugins-linux-amd64-${CNI_VERSION}.tgz ${CNI_URL}
}

download_kube_image() {
    mkdir -p ${PKG}/images || true

    echo "Pull iamges"
    docker pull ${KUBE_APISERVER_IMAGE}
    docker pull ${KUBE_CONTROLLER_MANAGER_IMAGE}
    docker pull ${KUBE_SCHEDULER_IMAGE}
    docker pull ${KUBE_PROXY_IMAGE}
    docker pull ${PAUSE_IMAGE}
    docker pull ${ETCD_IMAGE}
    docker pull ${COREDNS_IMAGE}

    # ha images
    docker pull ${HA_NGINX_IMAGE}

    # networking
    docker pull ${NETWOEK_FALNNEL}

    docker save ${KUBE_APISERVER_IMAGE} ${KUBE_CONTROLLER_MANAGER_IMAGE} ${KUBE_SCHEDULER_IMAGE} ${ETCD_IMAGE} -o ${PKG}/images/kube_master_images.rar
    docker save ${KUBE_PROXY_IMAGE} ${PAUSE_IMAGE} ${COREDNS_IMAGE} ${HA_NGINX_IMAGE} ${NETWOEK_FALNNEL} -o ${PKG}/images/kube_node_images.rar

    cat <<"EOF" >>${PKG}/images/master.sh
docker load -i $(dirname $0)/kube_master_images.rar
EOF
    chmod 755 ${PKG}/images/master.sh

    cat <<"EOF" >>${PKG}/images/node.sh
docker load -i $(dirname $0)/kube_node_images.rar
EOF
    chmod 755 ${PKG}/images/node.sh
}

gen_pkg() {
    cd ${PKG}
    echo "Compress kube_${KUBE_VERSION}-docker_v${DOCKER_VERSION}.tgz"
    tar --owner=0 --group=0 -zcvf ../kube_${KUBE_VERSION}-docker_v${DOCKER_VERSION}.tgz ./
}

main() {

    if [[ -d ${KUBE} ]]; then
        echo "remove ${KUBE}"
        rm -rf ${KUBE} || true
    fi

    mkdir -p ${TEMP} || true
    mkdir -p ${PKG} || true

    gen_docker_conf
    download_docker

    gen_kubernetes_conf
    download_kubernetes

    download_cni

    download_kube_image

    gen_pkg
}

main
