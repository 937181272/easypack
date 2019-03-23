#!/bin/sh

. ./install.cfg

echo -e "\n##  kube-apiserver service"
systemctl stop kube-apiserver 2>/dev/null

mkdir -p ${ENV_KUBE_DIR_BIN} ${ENV_KUBE_DIR_ETC}
chmod 755 ${ENV_HOME_K8S}/*
cp -p ${ENV_HOME_K8S}/{kubectl,kube-apiserver} ${ENV_KUBE_DIR_BIN}
if [ $? -ne 0 ]; then
  echo "please check kubectl and kube-apiserver binary files existed in ${ENV_HOME_K8S}/ or not"
  exit 
fi

# create kube token file
cat >${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_TOKEN} <<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# create kube-apiserver configuration file
cat >${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_CONF} <<EOF
KUBE_APISERVER_OPTS="--logtostderr=${ENV_KUBE_OPT_LOGTOSTDERR} \
--v=${ENV_KUBE_OPT_LOG_LEVEL} \
--log-dir=${ENV_KUBE_OPT_LOG_DIR} \\
EOF

echo ${ENV_ETCD_HOSTS} |awk -v etcd_names="${ENV_ETCD_NAMES}" \
-v port=${ENV_ETCD_CLIENT_PORT} -F" " 'BEGIN{
    printf("--etcd-servers=");
}
{
    for(cnt=1; cnt<NF; cnt++){
        printf("https://%s:%s,",$cnt,port);
    }
    printf("https://%s:%s ",$cnt,port);
}' >>${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_CONF}

cat >>${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_CONF} <<EOF
--bind-address=${ENV_CURRENT_HOSTIP} \
--secure-port=${ENV_KUBE_OPT_API_SSL_PORT} \
--advertise-address=${ENV_CURRENT_HOSTIP} \
--allow-privileged=${ENV_KUBE_OPT_ALLOW_PRIVILEGE} \
--service-cluster-ip-range=${ENV_KUBE_OPT_CLUSTER_IP_RANGE} \
--enable-admission-plugins=${ENV_KUBE_ADM_PLUGINS} \
--authorization-mode=${ENV_KUBE_OPT_AUTH_MODE} \
--enable-bootstrap-token-auth \
--token-auth-file=${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_TOKEN} \
--service-node-port-range=${ENV_KUBE_OPT_CLUSTER_PORT_RANGE} \
--tls-cert-file=${ENV_SSL_K8S_DIR}/${ENV_SSL_K8S_CERT_PRIFIX}.pem  \
--tls-private-key-file=${ENV_SSL_K8S_DIR}/${ENV_SSL_K8S_CERT_PRIFIX}-key.pem \
--client-ca-file=${ENV_SSL_CA_DIR}/${ENV_SSL_FILE_CA_PEM} \
--service-account-key-file=${ENV_SSL_CA_DIR}/${ENV_SSL_FILE_CA_KEY} \
--etcd-cafile=${ENV_SSL_CA_DIR}/${ENV_SSL_FILE_CA_PEM} \
--etcd-certfile=${ENV_SSL_ETCD_DIR}/${ENV_SSL_ETCD_CERT_PRIFIX}.pem \
--etcd-keyfile=/${ENV_SSL_ETCD_DIR}/${ENV_SSL_ETCD_CERT_PRIFIX}-key.pem"
EOF

# Create the kube-apiserver service.
cat >${ENV_KUBE_API_SERVICE} <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=-${ENV_KUBE_DIR_ETC}/${ENV_KUBE_API_CONF}
ExecStart=${ENV_KUBE_DIR_BIN}/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n##  daemon reload service "
systemctl daemon-reload
echo -e "\n##  start kube-apiserver service "
systemctl start kube-apiserver
echo -e "\n##  enable kube-apiserver service " 
systemctl enable kube-apiserver
echo -e "\n##  check  kube-apiserver status"
systemctl status kube-apiserver

echo -e "\n##  kubectl version"
kubectl version

echo -e "\n##  get cs"
kubectl get cs
