#!/bin/bash
set -e

# ==========================================
# 0. Paquetes base requeridos en Debian
# ==========================================
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates

# ==========================================
# 1. Instalación de dependencias (Docker, K3d, kubectl)
# ==========================================
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
fi

if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# ==========================================
# 2. Creación del clúster K3d (Idempotente)
# ==========================================
if ! k3d cluster list | grep -q "iot-cluster"; then
    k3d cluster create iot-cluster -p "8888:8888@loadbalancer"
else
    echo "El clúster 'iot-cluster' ya existe. Omitiendo creación."
fi

# ==========================================
# 3. Namespaces requeridos (argocd y dev)
# ==========================================
kubectl create ns argocd || true
kubectl create ns dev || true

# ==========================================
# 4. Despliegue de Argo CD (Server-side con fuerza)
# ==========================================
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ==========================================
# 5. Espera y aplicación de la App GitOps
# ==========================================
kubectl wait --for=condition=ready pod --all -n argocd --timeout=180s || true

if [ -f "$(dirname "$0")/../confs/application.yaml" ]; then
    kubectl apply -f "$(dirname "$0")/../confs/application.yaml"
fi