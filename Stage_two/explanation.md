# Stage 2: Ansible and Terraform Implementation - Explanation

## Overview

Stage 2 demonstrates the integration of Terraform for infrastructure provisioning and Ansible for configuration management and application deployment on Amazon Web Services (AWS). This approach provides a complete Infrastructure as Code (IaC) solution that can provision, configure, and deploy the Yolo e-commerce platform automatically.

## Execution Order Reasoning

The playbook is structured in two main plays that run sequentially, with each play containing tasks that must execute in a specific order for successful deployment.

### Play 1: Infrastructure Provisioning (localhost)

**Task Order and Reasoning:**

1. **Python Dependencies Installation**
   - **Purpose**: Ensures boto3 and botocore are available for Terraform's AWS provider
   - **Why First**: Required before any AWS API calls can be made
   - **Implementation**: Uses conditional installation to avoid sudo timeout issues

2. **Terraform Initialization**
   - **Purpose**: Initializes Terraform working directory and downloads providers
   - **Why Second**: Must occur before any Terraform apply operations
   - **Implementation**: Uses community.general.terraform module

3. **Terraform Apply**
   - **Purpose**: Provisions all AWS resources (VPC, subnet, security group, EC2 instance)
   - **Why Third**: Creates the infrastructure needed for application deployment
   - **Implementation**: Uses targeted resources to ensure proper dependency order

4. **Public IP Extraction**
   - **Purpose**: Retrieves the EC2 instance's public IP from Terraform outputs
   - **Why Fourth**: Needed for SSH connection and application configuration
   - **Implementation**: Uses set_fact to store IP for later use

5. **SSH Availability Check**
   - **Purpose**: Ensures EC2 instance is fully booted and SSH service is running
   - **Why Fifth**: Prevents connection failures in subsequent tasks
   - **Implementation**: Uses wait_for module with extended timeout

6. **Dynamic Inventory Addition**
   - **Purpose**: Adds the EC2 instance to Ansible's in-memory inventory
   - **Why Last**: Prepares for the configuration management play
   - **Implementation**: Includes SSH configuration and public IP as host variable

### Play 2: Configuration and Deployment (EC2 Instance)

**Role Order and Reasoning:**

1. **common Role**
   - **Purpose**: Installs Docker, configures system, sets up user permissions
   - **Why First**: Provides the foundation for all subsequent deployments
   - **Key Tasks**: Docker installation, user group management, service startup
   - **Tags**: `[setup, common]`

2. **clone_app Role**
   - **Purpose**: Downloads application source code from GitHub repository
   - **Why Second**: Application code must be available before containerization
   - **Key Tasks**: Git installation, repository cloning, permission setting
   - **Tags**: `[setup, clone]`

3. **mongo_deploy Role**
   - **Purpose**: Deploys MongoDB database container with persistence
   - **Why Third**: Database must be available before backend services
   - **Key Tasks**: Docker Compose template processing, container deployment, health verification
   - **Tags**: `[deploy, mongo]`
   - **Variables**: Receives public_ip_for_compose for frontend configuration

4. **backend_deploy Role**
   - **Purpose**: Builds and deploys the Node.js API service
   - **Why Fourth**: Backend API must be running before frontend deployment
   - **Key Tasks**: Image building, container deployment, health checking
   - **Tags**: `[deploy, backend]`

5. **frontend_deploy Role**
   - **Purpose**: Builds and deploys the React frontend application
   - **Why Last**: Frontend depends on backend API availability
   - **Key Tasks**: Image building with API URL, container deployment, access verification
   - **Tags**: `[deploy, frontend]`
   - **Variables**: Receives public_ip_for_compose for build-time configuration

## Role Functions and Positioning

### common Role
**Function**: System foundation setup
**Position**: First in deployment sequence
**Modules Applied**:
- `ansible.builtin.apt`: Package management for system updates
- `ansible.builtin.file`: Directory creation and permission management
- `ansible.builtin.get_url`: Docker GPG key retrieval
- `ansible.builtin.apt_repository`: Docker repository addition
- `ansible.builtin.user`: User group management for Docker access
- `ansible.builtin.systemd`: Docker service management
- `ansible.builtin.meta`: Connection reset for group changes

**Why This Position**: All subsequent roles depend on Docker being properly installed and configured. The system must be prepared before any application-specific tasks can execute.

### clone_app Role
**Function**: Source code acquisition and preparation
**Position**: Second in deployment sequence
**Modules Applied**:
- `ansible.builtin.apt`: Git installation
- `ansible.builtin.file`: Directory cleanup and preparation
- `ansible.builtin.git`: Repository cloning with version control
- `ansible.builtin.file`: Ownership and permission configuration

**Why This Position**: Application source code must be available before any containerization can occur. This role ensures a clean, properly owned codebase is ready for Docker builds.

### mongo_deploy Role
**Function**: Database service deployment and initialization
**Position**: Third in deployment sequence
**Modules Applied**:
- `ansible.builtin.template`: Docker Compose configuration generation
- `ansible.builtin.shell`: Docker image pulling and container operations
- `ansible.builtin.wait_for`: Port availability verification
- `ansible.builtin.debug`: Status information display

**Why This Position**: The database layer forms the foundation of the application stack. Backend services require database connectivity, so MongoDB must be running and healthy before API deployment.

### backend_deploy Role
**Function**: API service deployment and health verification
**Position**: Fourth in deployment sequence
**Modules Applied**:
- `ansible.builtin.shell`: Docker image building and container deployment
- `ansible.builtin.uri`: HTTP health check for API endpoints
- `ansible.builtin.debug`: Service status reporting

**Why This Position**: The backend API serves as the data layer for the frontend application. It must be running and responding to HTTP requests before the frontend can be successfully deployed and configured.

### frontend_deploy Role
**Function**: Web interface deployment and access configuration
**Position**: Last in deployment sequence
**Modules Applied**:
- `ansible.builtin.shell`: Docker image building with build arguments and container deployment
- `ansible.builtin.debug`: Access information display with public URLs

**Why This Position**: The frontend is the user-facing component that depends on both database and API services. It requires the backend API URL to be configured during build time, making it dependent on the complete backend stack.

## Variable Management Strategy

### Centralized Configuration
Variables are stored in `vars/main.yml` to maintain consistency and ease of modification:
- **terraform_dir**: Dynamic path resolution using environment variables
- **aws_region**: Regional deployment configuration
- **key_pair_name**: SSH key identification for AWS
- **public_key_path**: SSH public key location for EC2 access
- **private_key_path**: SSH private key location for connection

### Dynamic Variable Passing
The public IP address is dynamically passed between plays using:
- **set_fact**: Stores Terraform output in localhost context
- **add_host**: Transfers IP to EC2 host variables
- **hostvars**: Accesses stored IP in role variable definitions

## Tags Implementation Strategy

Tags are implemented to provide granular control over playbook execution:
- **setup**: Groups infrastructure preparation tasks (common, clone_app)
- **deploy**: Groups application deployment tasks (mongo_deploy, backend_deploy, frontend_deploy)
- **Component-specific**: Allows targeted execution of individual services

This tagging strategy enables selective execution for debugging, updates, or partial deployments while maintaining the correct execution order.

## Error Handling and Reliability

### Health Checks
Each service deployment includes comprehensive health verification:
- **MongoDB**: Port availability and connection testing
- **Backend**: HTTP endpoint response verification
- **Frontend**: Container status and port binding confirmation

### Retry Logic
Critical tasks implement retry mechanisms with appropriate delays:
- **SSH Availability**: Extended timeout for EC2 instance startup
- **Service Health**: Multiple attempts with progressive delays
- **Container Status**: Polling with reasonable retry limits

### Cleanup and Recovery
The implementation includes cleanup procedures:
- **Directory Removal**: Ensures clean application deployment
- **Container Management**: Proper service lifecycle management
- **Connection Handling**: SSH connection optimization and error handling

This comprehensive approach ensures reliable, repeatable deployments with clear failure points and recovery mechanisms.
