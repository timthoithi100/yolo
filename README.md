# Independent Project: Containerized E-commerce Platform

This document explains the choices and implementations I made to containerize the Yolo e-commerce platform, addressing the objectives outlined in the project rubrik.

## 1. Choice of Base Image

### Backend (Node.js API)
* **Initial Image:** `node:14` (build stage) and `alpine:3.16.7` (final stage).
* **Chosen Image:** `node:20-alpine` for both build and final stages.
* **Reasoning:**
    * **`node:20-alpine`:** This image is based on Alpine Linux, which is significantly smaller than Debian-based Node.js images. It provides a minimal environment, reducing the final image size. Node.js 20 is a current Long Term Support (LTS) version, offering stability and modern features.
    * **Multi-stage build:** While the original used multi-stage, ensuring both stages use `node:20-alpine` simplifies dependency management and ensures `npm` and `node` are consistently available for runtime needs.

### Frontend (React Application)
* **Initial Image:** `node:14-slim` (build stage) and `alpine:3.16.7` (final stage).
* **Chosen Image:** `node:20-alpine` for both build and final stages.
* **Reasoning:**
    * **`node:20-alpine`:** Similar to the backend, this provides a lightweight base. React applications require Node.js and `npm` for the build process (`npm run build`). Using `node:20-alpine` for the final stage ensures `npm` is available if needed for global packages like `serve`, which is used to serve the static build.
    * **Multi-stage build:** The build stage compiles the React app into static assets. The final stage uses `serve` to host these assets. Using `node:20-alpine` in the final stage ensures `npm` is available to install `serve` globally.

### Database (MongoDB)
* **Initial Image:** `mongo` (effectively `mongo:latest`).
* **Chosen Image:** `mongo:4.4`.
* **Reasoning:**
    * During testing, `mongo:latest` (which is MongoDB 5.0+) consistently failed to start with an `AVX support` error on my machine's CPU.
    * MongoDB 4.4 is the last major version that does not require AVX CPU instruction set, making it compatible with a wider range of older hardware such as mine. This ensures the database container starts and functions correctly.

## 2. Dockerfile Directives Used

### Common Directives:
* **`FROM`:** Specifies the base image for each stage.
* **`WORKDIR`:** Sets the working directory inside the container.
* **`COPY`:** Copies files from the host to the container. `COPY package*.json ./` is used early to leverage Docker's build cache. `COPY . .` copies the rest of the application code. `COPY --from=build /usr/src/app/build .` (for client) and `COPY --from=build /usr/src/app .` (for backend) are used in multi-stage builds to copy only necessary artifacts from the build stage to the smaller final stage.
* **`RUN`:** Executes commands during the image build process (e.g., `npm ci --omit=dev` for installing production dependencies, `npm run build` for React build, `apk add --no-cache curl` for installing `curl`).
* **`EXPOSE`:** Documents the port(s) the application listens on.
* **`CMD`:** Defines the default command to execute when the container starts (e.g., `node server.js` for backend, `serve -s . -l 0.0.0.0 -p 3000` for frontend).
* **`.dockerignore`:** Used in both `backend` and `client` directories to exclude unnecessary files (like `node_modules`, `.git`, `build` for client) from the build context, speeding up builds and reducing image size.
* **`ENV NODE_OPTIONS=--openssl-legacy-provider`:** Added to the client's build stage to resolve `ERR_OSSL_EVP_UNSUPPORTED` errors encountered with Node.js 20 and React scripts. It's unset afterward to not carry into the final image.
* **`ARG REACT_APP_API_URL` and `ENV REACT_APP_API_URL=$REACT_APP_API_URL`:** Used in the client's Dockerfile to allow passing the backend API URL as a build argument, making the frontend configurable for different environments (e.g., `http://localhost:5000` for browser access).

## 3. Docker-compose Networking

* **Custom Bridge Network (`app-net`):** I have implemented a custom bridge network named `app-net` (`driver: bridge`). This isolates the application's containers, providing better security and preventing conflicts with other Docker networks.
* **IP Address Management (`ipam`):** I have defined a specific subnet (`172.20.0.0/16`) and IP range for `app-net`. This provides a predictable internal network for the services.
* **Application Port Allocation:**
    * **Backend (`tim-backend`):** Exposes port `5000` (`5000:5000`). The backend listens on `5000` internally, and this is mapped to port `5000` on the host machine.
    * **Frontend (`tim-client`):** Exposes port `3000` (`3000:3000`). The frontend serves on `3000` internally, mapped to port `3000` on the host.
    * **MongoDB (`app-mongo`):** Exposes port `27017` (`27017:27017`).
* **Inter-service Communication:** Services communicate using their service names within the `app-net` network (e.g., `mongodb://app-mongo:27017/yolodb` for the backend to connect to MongoDB, and `http://localhost:5000` for the frontend to connect to the backend *during its build process*).
* **Browser to Frontend/Backend Communication:** The browser on the host machine accesses the frontend at `http://localhost:3000`. The frontend then makes API calls to the backend at `http://localhost:5000` (configured via `REACT_APP_API_URL` build argument), which is the port exposed on the host.

## 4. Docker-compose Volume Definition and Usage

* **Named Volume (`app-mongo-data`):** I have defined and named a Docker volume `app-mongo-data` (`driver: local`).
* **Persistence:** This volume is mounted to the `/data/db` directory inside the `app-mongo` container (`target: /data/db`). This ensures that all data stored by the MongoDB database persists even if the `app-mongo` container is stopped, removed, or recreated. This directly addresses the persistence requirement of the project.
* **`MONGO_INITDB_DATABASE=yolodb`:** An environment variable was added to the `app-mongo` service to ensure that the `yolodb` database is automatically created and initialized when the MongoDB container starts for the first time with the volume.

## 5. Git Workflow Used

* **Forking:** The original repository was forked to my personal GitHub account (`timthoithi100/yolo`).
* **Branching:** A feature branch (`feature/docker-containerization`) was created for all development work.
* **Commits:** Changes were committed incrementally with descriptive commit messages, reflecting each step of the containerization process (e.g., "feat: Update backend Dockerfile to install curl for healthcheck").
* **Pushing:** The feature branch was pushed to the remote forked repository.
* **Future Merge:** The intention was to create a Pull Request from this feature branch to the `master` branch of the forked repository upon completion.

## 6. Successful Running of the Applications and Debugging Measures

The application now runs successfully with all components containerized. Several debugging measures were applied throughout the process:

* **`docker compose ps`:** Regularly used to check the status of containers (running, exited, unhealthy).
* **`docker compose logs <service_name>`:** Crucial for inspecting container output and identifying errors. This was instrumental in diagnosing:
    * `MongooseServerSelectionError` initially (backend not connecting to Mongo).
    * `npm: not found` (missing `npm` in client's final stage).
    * `ERR_OSSL_EVP_UNSUPPORTED` (Node.js 20 compatibility with React build).
    * `AVX support` error (MongoDB 5.0+ CPU incompatibility).
    * `Network Error` / `ERR_NAME_NOT_RESOLVED` (frontend trying to access backend via internal Docker hostname from browser).
* **`docker exec -it <container_name> bash`:** Used to get a shell inside containers to manually inspect files (`ls -l /app`), check command availability (`which serve`), and test commands directly.
* **Browser Developer Tools (Network Tab):** Essential for verifying frontend API calls, their status codes, payloads, and responses.
* **Healthchecks:** Implemented robust healthchecks in `docker-compose.yaml` for MongoDB and the backend to ensure services are fully ready before dependent services start.
* **Full Cleanup (`docker compose down --volumes --rmi all`):** Frequently used to ensure a clean slate and avoid caching issues during debugging, especially when dealing with volume or image changes.

## 7. Good Practices - Docker Image Tag Naming Standards

* **DockerHub Username Prefix:** All custom-built images are prefixed with my DockerHub username (`timthoithi100/`), e.g., `timthoithi100/yolo-client`.
* **Semantic Versioning:** Images are tagged with `1.0.0` (e.g., `timthoithi100/yolo-client:1.0.0`) following semantic versioning conventions. This provides clear versioning for releases.
* **Service-specific Naming:** Images are named clearly based on the service they represent (e.g., `yolo-client`, `yolo-backend`).

## 8. DockerHub Deployment Screenshots

![Screenshot of timthoithi100 repos on DockerHub](<https://github.com/timthoithi100/yolo/raw/feature/docker-containerization/docs/images/Screenshot From 2025-07-10 16-34-52.png>)

![Screenshot of timthoithi100/yolo-client:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/feature/docker-containerization/docs/images/Screenshot From 2025-07-10 16-33-16.png>)

![Screenshot of timthoithi100/yolo-client:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/feature/docker-containerization/docs/images/Screenshot From 2025-07-10 16-33-31.png>)

![Screenshot of timthoithi100/yolo-backend:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/feature/docker-containerization/docs/images/Screenshot From 2025-07-10 16-32-29.png>)

![Screenshot of timthoithi100/yolo-backend:1.0.0 on DockerHub](<https://github.com/timthoithi100/yolo/raw/feature/docker-containerization/docs/images/Screenshot From 2025-07-10 16-32-50.png>)

</markdown>
