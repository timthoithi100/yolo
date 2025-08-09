# YOLO App Kubernetes Deployment - Implementation Explanation

## 1. Choice of Kubernetes Objects Used for Deployment

### StatefulSet for MongoDB Storage Solution
I chose to implement **StatefulSet** for the MongoDB deployment instead of a regular Deployment for the following reasons:

- **Persistent Identity**: StatefulSets provide stable, unique network identifiers for each pod, which is crucial for database applications that need consistent identity across restarts
- **Ordered Deployment**: StatefulSets guarantee ordered deployment and scaling, ensuring database initialization occurs properly
- **Stable Storage**: Each pod in a StatefulSet gets its own persistent storage that survives pod rescheduling, which is essential for database persistence
- **Predictable DNS Names**: StatefulSets provide predictable DNS names (mongodb-0, mongodb-1, etc.) which simplifies database clustering if we scale in the future

### Deployment for Application Services
For both **backend** and **frontend** services, I used standard Deployments because:

- **Stateless Nature**: Both application services are stateless and don't require persistent identity
- **Horizontal Scaling**: Deployments make it easy to scale replicas up/down based on load
- **Rolling Updates**: Deployments provide built-in rolling update strategies for zero-downtime deployments
- **Pod Management**: Automatic pod replacement and health management

## 2. Method Used to Expose Pods to Internet Traffic

### LoadBalancer Services for External Access
I implemented **LoadBalancer** services for external traffic exposure:

- **Frontend Service**: LoadBalancer on port 80 → frontend pods on port 3000
- **Backend Service**: LoadBalancer on port 80 → backend pods on port 5000

**Reasoning:**
- LoadBalancer is ideal for GKE as it automatically provisions Google Cloud Load Balancers
- Provides external IP addresses accessible from the internet
- Built-in health checking and traffic distribution
- Production-ready solution with high availability

### ClusterIP Services for Internal Communication
- **MongoDB Service**: ClusterIP for internal database access only
- **Backend Internal Service**: ClusterIP for frontend-to-backend communication

**Benefits:**
- Security: Database is not exposed externally
- Performance: Internal cluster networking is faster
- Service Discovery: DNS-based service discovery within cluster

## 3. Use of Persistent Storage

### PersistentVolume and PersistentVolumeClaim Implementation
I implemented persistent storage using:

- **PersistentVolume (PV)**: 10GB storage with `hostPath` provisioner
- **PersistentVolumeClaim (PVC)**: Claims 10GB for MongoDB StatefulSet
- **Volume Mount**: MongoDB container mounts PVC at `/data/db`

**Key Benefits:**
- **Data Durability**: Database data survives pod deletion and recreation
- **Storage Abstraction**: PVC abstracts storage details from pod specifications.
- **Flexible Provisioning**: Can easily switch storage classes (SSD, regional persistent disks)
- **Backup/Recovery**: Persistent volumes can be snapshotted and backed up

**Configuration Details:**
- **Storage Class**: `standard` (GKE default)
- **Access Mode**: `ReadWriteOnce` (suitable for single-node database)
- **Reclaim Policy**: `Retain` (prevents accidental data loss)


### Commit Strategy
1. **Initial Setup**: Repository structure and base manifests
2. **Namespace Creation**: Isolated environment for YOLO app
3. **Storage Implementation**: PV and PVC for MongoDB
4. **StatefulSet Deployment**: MongoDB with persistent storage
5. **Backend Deployment**: API service with health checks
6. **Frontend Deployment**: React app with proper environment variables
7. **Service Configuration**: LoadBalancer and ClusterIP services
8. **Testing and Debugging**: Iterative fixes and improvements
9. **Documentation**: README and explanation files
10. **Final Validation**: End-to-end testing

### Quality Practices
- **Descriptive Commits**: Each commit clearly describes the change made
- **Atomic Commits**: Single responsibility per commit
- **Feature Branches**: Separate branches for major features
- **Merge Strategy**: Squash merges to main branch

## 4. Implementation Highlights

### Health Checks and Monitoring
- **Liveness Probes**: Automatic pod restart on failure
- **Readiness Probes**: Traffic routing only to ready pods
- **Resource Limits**: Prevent resource starvation

### Security Considerations
- **Namespace Isolation**: Separate namespace for the application
- **Internal Services**: Database not exposed externally
- **Resource Quotas**: CPU and memory limits defined

### High Availability
- **Multiple Replicas**: 2 replicas each for frontend and backend
- **Load Distribution**: LoadBalancer distributes traffic across pods
- **Pod Anti-Affinity**: Could be added to spread pods across nodes

## 5. Deployment Architecture

```
Internet Traffic
       ↓
   LoadBalancer (Frontend) :80
       ↓
   Frontend Pods :3000 (2 replicas)
       ↓
   ClusterIP (Backend) :5000  
       ↓
   Backend Pods :5000 (2 replicas)
       ↓
   ClusterIP (MongoDB) :27017
       ↓
   MongoDB StatefulSet :27017 (1 replica)
       ↓
   PersistentVolume (10GB)
```

This architecture ensures scalability, reliability, and proper data persistence while following Kubernetes best practices.