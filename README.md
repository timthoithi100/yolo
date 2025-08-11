# Yolo E-commerce Platform

A containerized e-commerce platform built with React frontend, Node.js backend, and MongoDB database. This project demonstrates infrastructure as code using Ansible and Terraform for automated deployment, with advanced Kubernetes orchestration on Google Kubernetes Engine (GKE).

## Live Application

**Frontend URL**: `http://[EXTERNAL-IP]` _(To be updated after deployment)_  
**Backend API**: `http://[EXTERNAL-IP]/api/products` _(To be updated after deployment)_

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Docker Containerization](#docker-containerization)
- [Stage 1: Ansible with Vagrant](#stage-1-ansible-with-vagrant)
- [Stage 2: Ansible with Terraform on AWS](#stage-2-ansible-with-terraform-on-aws)
- [Kubernetes Deployment on GKE](#kubernetes-deployment-on-gke)
- [Contributing](#contributing)

## Overview

The Yolo platform is a full-stack e-commerce application that allows users to browse and add products to an online store. The application has been fully containerized and can be deployed using various infrastructure automation approaches, from local development with Docker Compose to production-ready Kubernetes clusters on Google Cloud Platform.

## Architecture

- **Frontend**: React application served via Node.js
- **Backend**: Node.js REST API with Express.js
- **Database**: MongoDB for data persistence
- **Infrastructure**: Terraform for AWS resource provisioning, Kubernetes for orchestration
- **Configuration Management**: Ansible for server setup and application deployment
- **Container Orchestration**: Kubernetes with StatefulSets, Deployments, and Services

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Ansible (for automated deployment)
- Terraform (for AWS deployment)
- AWS CLI configured (for Stage 2)
- Vagrant (for Stage 1)
- Google Cloud SDK and kubectl (for Kubernetes deployment)

### Local Development

1. Clone the repository:
```bash
git clone https://github.com/timthoithi100/yolo.git
cd yolo
```

2. Build and run with Docker Compose:
```bash
docker compose up -d
```

3. Access the application:
- Frontend: http://localhost:3000
- Backend API: http://localhost:5000
- MongoDB: localhost:27017

## Docker Containerization

This section explains the choices and implementations made to containerize the Yolo e-commerce platform.

### 1. Choice of Base Image

#### Backend (Node.js API)
* **Initial Image:** `node:14` (build stage) and `alpine:3.16.7` (final stage).
* **Chosen Image:** `node:20-alpine` for both build and final stages.
* **Reasoning:**
    * **`node:20-alpine`:** This image is based on Alpine Linux, which is significantly smaller than Debian-based Node.js images. It provides a minimal environment, reducing the final image size. Node.js 20 is a current Long Term Support (LTS) version, offering stability and modern features.
    * **Multi-stage build:** While the original used multi-stage, ensuring both stages use `node:20-alpine` simplifies dependency management and ensures `npm` and `node` are consistently available for runtime needs.

#### Frontend (React Application)
* **Initial Image:** `node:14-slim` (build stage) and `alpine:3.16.7` (final stage).
* **Chosen Image:** `node:20-alpine` for both build and final stages.
* **Reasoning:**
    * **`node:20-alpine`:** Similar to the backend, this provides a lightweight base. React applications require Node.js and `npm` for the build process (`npm run build`). Using `node:20-alpine` for the final stage ensures `npm` is available if needed for global packages like `serve`, which is used to serve the static build.
    * **Multi-stage build:** The build stage compiles the React app into static assets. The final stage uses `serve` to host these assets. Using `node:20-alpine` in the final stage ensures `npm` is available to install `serve` globally.

#### Database (MongoDB)
* **Initial Image:** `mongo` (effectively `mongo:latest`).
* **Chosen Image:** `mongo:4.4`.
* **Reasoning:**
    * During testing, `mongo:latest` (which is MongoDB 5.0+) consistently failed to start with an `AVX support` error on my machine's CPU.
    * MongoDB 4.4 is the last major version that does not require AVX CPU instruction set, making it compatible with a wider range of older hardware such as mine. This ensures the database container starts and functions correctly.

### 2. Dockerfile Directives Used

#### Common Directives:
* **`FROM`:** Specifies the base image for each stage.
* **`WORKDIR`:** Sets the working directory inside the container.
* **`COPY`:** Copies files from the host to the container. `COPY package*.json ./` is used early to leverage Docker's build cache. `COPY . .` copies the rest of the application code. `COPY --from=build /usr/src/app/build .` (for client) and `COPY --from=build /usr/src/app .` (for backend) are used in multi-stage builds to copy only necessary artifacts from the build stage to the smaller final stage.
* **`RUN`:** Executes commands during the image build process (e.g., `npm ci --omit=dev` for installing production dependencies, `npm run build` for React build, `apk add --no-cache curl` for installing `curl`).
* **`EXPOSE`:** Documents the port(s) the application listens on.
* **`CMD`:** Defines the default command to execute when the container starts (e.g., `node server.js` for backend, `serve -s . -l 0.0.0.0 -p 3000` for frontend).
* **`.dockerignore`:** Used in both `backend` and `client` directories to exclude unnecessary files (like `node_modules`, `.git`, `build` for client) from the build context, speeding up builds and reducing image size.
* **`ENV NODE_OPTIONS=--openssl-legacy-provider`:** Added to the client's build stage to resolve `ERR_OSSL_EVP_UNSUPPORTED` errors encountered with Node.js 20 and React scripts. It's unset afterward to not carry into the final image.
* **`ARG REACT_APP_API_URL` and `ENV REACT_APP_API_URL=$REACT_APP_API_URL`:** Used in the client's Dockerfile to allow passing the backend API URL as a build argument, making the frontend configurable for different environments (e.g., `http://localhost:5000` for browser access).

### 3. Docker-compose Networking

* **Custom Bridge Network (`app-net`):** I have implemented a custom bridge network named `app-net` (`driver: bridge`). This isolates the application's containers, providing better security and preventing conflicts with other Docker networks.
* **IP Address Management (`ipam`):** I have defined a specific subnet (`172.20.0.0/16`) and IP range for `app-net`. This provides a predictable internal network for the services.
* **Application Port Allocation:**
    * **Backend (`tim-backend`):** Exposes port `5000` (`5000:5000`). The backend listens on `5000` internally, and this is mapped to port `5000` on the host machine.
    * **Frontend (`tim-client`):** Exposes port `3000` (`3000:3000`). The frontend serves on `3000` internally, mapped to port `3000` on the host.
    * **MongoDB (`app-mongo`):** Exposes port `27017` (`27017:27017`).
* **Inter-service Communication:** Services communicate using their service names within the `app-net` network (e.g., `mongodb://app-mongo:27017/yolodb` for the backend to connect to MongoDB, and `http://localhost:5000` for the frontend to connect to the backend *during its build process*).
* **Browser to Frontend/Backend Communication:** The browser on the host machine accesses the frontend at `http://localhost:3000`. The frontend then makes API calls to the backend at `http://localhost:5000` (configured via `REACT_APP_API_URL` build argument), which is the port exposed on the host.

### 4. Docker-compose Volume Definition and Usage

* **Named Volume (`app-mongo-data`):** I have defined and named a Docker volume `app-mongo-data` (`driver: local`).
* **Persistence:** This volume is mounted to the `/data/db` directory inside the `app-mongo` container (`target: /data/db`). This ensures that all data stored by the MongoDB database persists even if the `app-mongo` container is stopped, removed, or recreated. This directly addresses the persistence requirement of the project.
* **`MONGO_INITDB_DATABASE=yolodb`:** An environment variable was added to the `app-mongo` service to ensure that the `yolodb` database is automatically created and initialized when the MongoDB container starts for the first time with the volume.

### 5. Good Practices - Docker Image Tag Naming Standards

* **DockerHub Username Prefix:** All custom-built images are prefixed with my DockerHub username (`timthoithi100/`), e.g., `timthoithi100/yolo-client`.
* **Semantic Versioning:** Images are tagged with `1.0.0` (e.g., `timthoithi100/yolo-client:1.0.0`) following semantic versioning conventions. This provides clear versioning for releases.
* **Service-specific Naming:** Images are named clearly based on the service they represent (e.g., `yolo-client`, `yolo-backend`).

### 6. DockerHub Deployment Screenshots

![Screenshot of timthoithi100 repos on DockerHub](<https://github.com/timthoithi100/yolo/raw/master/docs/images/Screenshot From 2025-07-10 16-34-52.png>)

![Screenshot of timthoithi100/yolo-client:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/master/docs/images/Screenshot From 2025-07-10 16-33-16.png>)

![Screenshot of timthoithi100/yolo-client:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/master/docs/images/Screenshot From 2025-07-10 16-33-31.png>)

![Screenshot of timthoithi100/yolo-backend:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/master/docs/images/Screenshot From 2025-07-10 16-32-29.png>)

![Screenshot of timthoithi100/yolo-backend:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/master/docs/images/Screenshot From 2025-07-10 16-32-50.png>)

## Stage 1: Ansible with Vagrant

Stage 1 implements infrastructure provisioning using Vagrant for local virtualization and Ansible for configuration management and application deployment.

### Architecture

- **Virtualization**: Vagrant with Ubuntu/Focal64 VM
- **Configuration Management**: Ansible playbooks and roles
- **Containerization**: Docker and Docker Compose
- **Network**: Local VM with port forwarding

### Implementation Details

The Stage 1 implementation uses a Vagrantfile to provision a local Ubuntu virtual machine and Ansible playbooks to configure the environment and deploy the containerized application.

#### Key Components:

1. **Vagrant Configuration**: VM provisioning with resource allocation
2. **Ansible Roles**: Modular configuration management
3. **Docker Deployment**: Containerized application stack
4. **Port Forwarding**: Access to services from host machine

#### Execution Order:

1. VM provisioning via Vagrant
2. Common system setup (Docker installation)
3. Application code deployment
4. Database container deployment
5. Backend service deployment
6. Frontend service deployment

## Stage 2: Ansible with Terraform on AWS

Stage 2 implements cloud infrastructure provisioning using Terraform for AWS resource management and Ansible for configuration management and application deployment.

### Architecture

- **Cloud Provider**: Amazon Web Services (AWS)
- **Infrastructure as Code**: Terraform for resource provisioning
- **Configuration Management**: Ansible playbooks and roles
- **Containerization**: Docker and Docker Compose on EC2
- **Network**: VPC with public subnet and security groups

### Implementation Details

The Stage 2 implementation uses Terraform to provision AWS infrastructure and Ansible to configure the EC2 instance and deploy the containerized application.

#### Key AWS Resources:

1. **VPC (Virtual Private Cloud)**: Isolated network environment
2. **Public Subnet**: Network segment with internet access
3. **Internet Gateway**: Internet connectivity for VPC
4. **Security Group**: Firewall rules for EC2 instance
5. **EC2 Instance**: Virtual server for application deployment
6. **Key Pair**: SSH access to EC2 instance

#### Execution Order:

The playbook runs sequentially with the following phases:

1. **Infrastructure Provisioning**:
   - Terraform initialization
   - AWS resource creation (VPC, subnet, security group, EC2)
   - Public IP retrieval and SSH availability check

2. **Configuration Management**:
   - System updates and Docker installation
   - Application code cloning from GitHub
   - Environment setup and dependency installation

3. **Application Deployment**:
   - MongoDB container deployment with health checks
   - Backend API container deployment and verification
   - Frontend container deployment and service validation

#### Role Functions:

- **common**: System preparation, Docker installation, user configuration
- **clone_app**: Git repository cloning and file permissions setup
- **mongo_deploy**: Database container deployment with persistence configuration
- **backend_deploy**: API service deployment with health monitoring
- **frontend_deploy**: Web interface deployment with connectivity verification

#### Variable Management:

Variables are centralized in `vars/main.yml` for maintainability:
- AWS region and resource configuration
- SSH key paths for secure access
- Terraform working directory paths
- Network and security configurations

#### Tags Implementation:

Tasks are organized with tags for selective execution:
- `setup`: System preparation tasks (common, clone)
- `deploy`: Application deployment tasks (mongo, backend, frontend)
- Component-specific tags for targeted deployments

## Kubernetes Deployment on GKE

This section covers the advanced Kubernetes implementation of the Yolo e-commerce platform on Google Kubernetes Engine (GKE), featuring StatefulSets, persistent storage, and production-ready orchestration.

### Kubernetes Architecture

#### Application Stack
- **Frontend**: React.js application served via Node.js with LoadBalancer service
- **Backend**: Node.js/Express.js REST API with horizontal pod autoscaling
- **Database**: MongoDB with StatefulSet and persistent volume storage
- **Container Registry**: Docker Hub with semantic versioning
- **Orchestration**: Kubernetes on GKE with high availability

#### Kubernetes Objects Implemented
- **1x Namespace**: `yolo-app` for resource isolation
- **1x StatefulSet**: MongoDB with ordered deployment and persistent identity
- **2x Deployments**: Frontend (2 replicas) and Backend (2 replicas) services
- **4x Services**: 2x LoadBalancer (external access) + 2x ClusterIP (internal communication)
- **1x PersistentVolume**: 10GB storage for MongoDB data persistence
- **1x PersistentVolumeClaim**: Storage allocation for StatefulSet

### Prerequisites for Kubernetes Deployment

#### Required Tools
```bash
# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# kubectl
gcloud components install kubectl

# Verify installations
gcloud --version
kubectl version --client
```

#### GKE Cluster Setup
```bash
# Set project and zone
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export CLUSTER_NAME="yolo-cluster"

# Create GKE cluster
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=3 \
    --machine-type=e2-medium \
    --enable-autorepair \
    --enable-autoupgrade

# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

### Quick Deployment

#### 1. Deploy Application
```bash
# Apply all manifests
kubectl apply -f k8s-manifests.yaml

# Verify deployment
kubectl get all -n yolo-app
```

#### 2. Get External Access URLs
```bash
# Get frontend URL
kubectl get service frontend-service -n yolo-app

# Get backend URL  
kubectl get service backend-external-service -n yolo-app
```

### Detailed Kubernetes Implementation

#### StatefulSet for MongoDB
- **Persistent Identity**: Stable network identifiers for database consistency
- **Ordered Deployment**: Ensures proper database initialization sequence
- **Persistent Storage**: 10GB volume that survives pod rescheduling
- **Health Checks**: Liveness and readiness probes for reliability

#### Deployments for Application Services
- **Frontend Deployment**: 2 replicas with React build serving on port 3000
- **Backend Deployment**: 2 replicas with Node.js API on port 5000
- **Rolling Updates**: Zero-downtime deployment strategy
- **Resource Limits**: CPU and memory constraints for efficient resource usage

#### Service Architecture
- **LoadBalancer Services**: External access for frontend (port 80) and backend API
- **ClusterIP Services**: Internal communication between services
- **DNS-based Discovery**: Service names resolve to cluster IPs automatically

#### Persistent Storage Implementation
- **Storage Class**: `standard` (GKE default persistent disks)
- **Access Mode**: `ReadWriteOnce` for single-node database access
- **Reclaim Policy**: `Retain` to prevent accidental data loss
- **Volume Mount**: MongoDB data directory (`/data/db`) mapped to persistent storage

### Verification and Testing

#### Pod Status Check
```bash
# Verify all pods are running
kubectl get pods -n yolo-app

# Expected output shows all pods in Running state
```

#### Persistent Storage Test
```bash
# Test data persistence by deleting MongoDB pod
kubectl delete pod mongodb-0 -n yolo-app

# Verify pod recreates and data persists
kubectl get pods -n yolo-app -w
```

#### Application Functionality
```bash
# Test backend health endpoint
curl http://[BACKEND-EXTERNAL-IP]/health

# Access frontend application
open http://[FRONTEND-EXTERNAL-IP]
```

### Troubleshooting

#### Common Issues
- **Pods in Pending**: Check resource quotas and PVC binding status
- **External IP Pending**: LoadBalancer provisioning takes 2-3 minutes on GCP
- **Database Connection**: Verify internal DNS resolution and service endpoints
- **Image Pull Errors**: Confirm Docker Hub image availability and tags

#### Debug Commands
```bash
# Check pod logs
kubectl logs -f deployment/backend-deployment -n yolo-app

# Describe resources for events
kubectl describe pod mongodb-0 -n yolo-app

# Test internal connectivity
kubectl exec -it deployment/backend-deployment -n yolo-app -- nslookup mongodb-service
```

### Cleanup

```bash
# Delete namespace and all resources
kubectl delete namespace yolo-app

# Delete GKE cluster
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE
```

### Resource Requirements

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Frontend  | 100m        | 128Mi          | 250m      | 256Mi        |
| Backend   | 250m        | 256Mi          | 500m      | 512Mi        |
| MongoDB   | 250m        | 512Mi          | 500m      | 1Gi          |

**Total Cluster Requirements**: ~600m CPU, ~900Mi Memory minimum

### Docker Images Used

- **Frontend**: `timthoithi100/yolo-client:1.0.0`
- **Backend**: `timthoithi100/yolo-backend:1.0.0`
- **Database**: `mongo:4.4` (compatible with wider hardware range)

### Kubernetes Files Structure

```
k8s-manifests/
├── 00-namespace.yaml           # Application namespace
├── 01-persistent-storage.yaml  # PV and PVC for MongoDB
├── 02-mongodb-statefulset.yaml # Database with persistent storage
├── 03-backend-deployment.yaml  # API service deployment
├── 04-frontend-deployment.yaml # React app deployment
└── 05-services.yaml           # LoadBalancer and ClusterIP services
```

This Kubernetes implementation demonstrates production-ready container orchestration with high availability, persistent storage, and scalable architecture suitable for enterprise deployment.
