# Yolo E-commerce Platform

A containerized e-commerce platform built with React frontend, Node.js backend, and MongoDB database. This project demonstrates infrastructure as code using Ansible and Terraform for automated deployment.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Docker Containerization](#docker-containerization)
- [Stage 1: Ansible with Vagrant](#stage-1-ansible-with-vagrant)
- [Stage 2: Ansible with Terraform on AWS](#stage-2-ansible-with-terraform-on-aws)
- [Project Structure](#project-structure)
- [Contributing](#contributing)

## Overview

The Yolo platform is a full-stack e-commerce application that allows users to browse and add products to an online store. The application has been fully containerized and can be deployed using various infrastructure automation approaches.

## Architecture

- **Frontend**: React application served via Node.js
- **Backend**: Node.js REST API with Express.js
- **Database**: MongoDB for data persistence
- **Infrastructure**: Terraform for AWS resource provisioning
- **Configuration Management**: Ansible for server setup and application deployment

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Ansible (for automated deployment)
- Terraform (for AWS deployment)
- AWS CLI configured (for Stage 2)
- Vagrant (for Stage 1)

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

## Project Structure

```
yolo/
├── backend/                 # Node.js API application
├── client/                  # React frontend application
├── Stage_two/              # Stage 2 implementation
│   ├── terraform/          # Terraform configuration files
│   ├── roles/              # Ansible roles
│   ├── vars/               # Ansible variables
│   ├── playbook.yml        # Main Ansible playbook
│   └── docker-compose.yaml.j2  # Docker Compose template
├── docker-compose.yaml     # Local development compose file
├── Vagrantfile            # Vagrant VM configuration
├── playbook.yml           # Stage 1 Ansible playbook
└── README.md              # This documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a Pull Request