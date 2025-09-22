# 🚀 CI/CD Pipeline Setup Guide

This guide explains how to set up and configure the GitHub Actions CI/CD pipeline for the Wisecow application.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [GitHub Secrets Setup](#github-secrets-setup)
- [Pipeline Configuration](#pipeline-configuration)
- [Workflow Details](#workflow-details)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## 🎯 Overview

The CI/CD pipeline automatically:
- ✅ Builds Docker images on code changes
- ✅ Pushes images to Docker Hub
- ✅ Updates Kubernetes deployment files
- ✅ Supports multiple architectures
- ✅ Uses build caching for faster builds

## 📋 Prerequisites

### Required Accounts
- **GitHub Account**: For repository hosting
- **Docker Hub Account**: For image registry
- **Kubernetes Cluster**: For deployment (optional)

### Required Tools
- **Git**: For version control
- **Docker**: For local testing
- **kubectl**: For Kubernetes management

## 🔐 GitHub Secrets Setup

### Step 1: Access Repository Settings
1. Go to your GitHub repository
2. Click on **Settings** tab
3. Navigate to **Secrets and variables** → **Actions**

### Step 2: Add Required Secrets

#### DOCKER_USERNAME
- **Name**: `DOCKER_USERNAME`
- **Value**: Your Docker Hub username
- **Example**: `anupsharma329`

#### DOCKER_PASSWORD
- **Name**: `DOCKER_PASSWORD`
- **Value**: Your Docker Hub password or access token
- **Note**: Use access token for better security

### Step 3: Create Docker Hub Access Token (Recommended)
1. Go to [Docker Hub](https://hub.docker.com)
2. Navigate to **Account Settings** → **Security**
3. Click **New Access Token**
4. Give it a name (e.g., "GitHub Actions")
5. Copy the token and use it as `DOCKER_PASSWORD`

### Step 4: Verify Secrets
```bash
# Check if secrets are configured (in GitHub Actions logs)
echo "Docker username: ${{ secrets.DOCKER_USERNAME }}"
echo "Docker password: [HIDDEN]"
```

## ⚙️ Pipeline Configuration

### Workflow File Location
```
.github/workflows/ci-cd.yml
```

### Trigger Configuration
```yaml
on:
  push:
    branches: [ main ]        # Triggers on main branch pushes
  pull_request:
    branches: [ main ]        # Triggers on PRs to main
```

### Environment Variables
```yaml
env:
  REGISTRY: docker.io                    # Docker registry
  IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/wisecow-app  # Image name
```

## 🔄 Workflow Details

### Phase 1: CI (Continuous Integration)

#### 1. Checkout Code
```yaml
- name: Checkout repository
  uses: actions/checkout@v4
```
- **Purpose**: Downloads the repository code
- **Duration**: ~10-30 seconds

#### 2. Set up Docker Buildx
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```
- **Purpose**: Enables advanced Docker features
- **Features**: Multi-platform builds, caching
- **Duration**: ~15-30 seconds

#### 3. Login to Docker Hub
```yaml
- name: Log in to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```
- **Purpose**: Authenticates with Docker Hub
- **Duration**: ~5-10 seconds

#### 4. Extract Metadata
```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
    tags: |
      type=ref,event=branch
      type=ref,event=pr
      type=sha,prefix={{branch}}-
      type=raw,value=latest,enable={{is_default_branch}}
```
- **Purpose**: Generates image tags automatically
- **Tags Created**:
  - `latest` (for main branch)
  - `main-<sha>` (for main branch commits)
  - `pr-<number>` (for pull requests)

#### 5. Build and Push Image
```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```
- **Purpose**: Builds and pushes Docker image
- **Features**: 
  - Multi-platform support
  - Build caching
  - Automatic retries
- **Duration**: ~2-5 minutes

### Phase 2: CD (Continuous Deployment)

#### 1. Update Deployment File
```yaml
- name: Update image in deployment
  run: |
    sed -i "s|image:.*|image: docker.io/${{ secrets.DOCKER_USERNAME }}/wisecow-app:${{ github.sha }}|g" k8s/deployment.yaml
    echo "✅ Updated deployment.yaml with new image tag"
```
- **Purpose**: Updates Kubernetes deployment with new image
- **Changes**: Replaces image tag in `k8s/deployment.yaml`

#### 2. Build Complete Notification
```yaml
- name: Build Complete
  run: |
    echo "✅ Docker image built and pushed successfully!"
    echo "📦 Image: docker.io/${{ secrets.DOCKER_USERNAME }}/wisecow-app:${{ github.sha }}"
    echo "📝 Deployment file updated with new image tag"
    echo "🔧 For local deployment: kubectl apply -f k8s/"
```
- **Purpose**: Provides build summary and next steps

## 🔧 Advanced Configuration

### Custom Image Tags
```yaml
# In ci-cd.yml
tags: |
  type=ref,event=branch
  type=ref,event=pr
  type=sha,prefix={{branch}}-
  type=raw,value=latest,enable={{is_default_branch}}
  type=raw,value=v1.0.0,enable={{is_default_branch}}
  type=raw,value=stable,enable={{is_default_branch}}
```

### Multi-Platform Builds
```yaml
# Add to build step
platforms: linux/amd64,linux/arm64
```

### Build Arguments
```yaml
# Add to build step
build-args: |
  BUILD_DATE=${{ github.event.head_commit.timestamp }}
  VCS_REF=${{ github.sha }}
```

### Conditional Deployment
```yaml
# Add condition to deployment steps
if: github.ref == 'refs/heads/main'
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Docker Login Failed
**Error**: `Error: Cannot perform an interactive login from a non TTY device`

**Solution**:
```yaml
# Check secrets are properly set
- name: Debug secrets
  run: |
    echo "Username: ${{ secrets.DOCKER_USERNAME }}"
    echo "Password length: ${#DOCKER_PASSWORD}"
```

#### 2. Image Push Failed
**Error**: `denied: requested access to the resource is denied`

**Solutions**:
- Verify Docker Hub credentials
- Check if repository exists
- Ensure access token has push permissions

#### 3. Build Cache Issues
**Error**: Build takes too long or fails

**Solution**:
```yaml
# Clear cache
cache-from: type=gha,scope=build
cache-to: type=gha,mode=max,scope=build
```

#### 4. Metadata Extraction Failed
**Error**: `Invalid tag format`

**Solution**:
```yaml
# Simplify tags
tags: |
  type=raw,value=latest
  type=sha
```

### Debug Commands

#### Check Workflow Status
```bash
# View workflow runs
gh run list

# View specific run
gh run view <run-id>

# Download logs
gh run download <run-id>
```

#### Test Locally
```bash
# Test Docker build
docker build -t wisecow-app .

# Test image
docker run -p 4499:4499 wisecow-app

# Test with different tags
docker tag wisecow-app your-username/wisecow-app:test
docker push your-username/wisecow-app:test
```

## 📊 Monitoring and Metrics

### Build Metrics
- **Build Time**: Typically 2-5 minutes
- **Image Size**: ~50-100MB
- **Success Rate**: Should be >95%

### Monitoring Commands
```bash
# Check recent builds
gh run list --limit 10

# Check build status
gh run view --log

# Check Docker Hub for new images
docker search your-username/wisecow-app
```

## 🔄 Workflow Optimization

### Performance Improvements
1. **Use Build Cache**: Already configured
2. **Parallel Jobs**: Add matrix strategy
3. **Conditional Steps**: Skip unnecessary steps
4. **Image Optimization**: Use multi-stage builds

### Example Optimized Workflow
```yaml
strategy:
  matrix:
    platform: [linux/amd64, linux/arm64]
  fail-fast: false

steps:
  - name: Build for ${{ matrix.platform }}
    uses: docker/build-push-action@v5
    with:
      platforms: ${{ matrix.platform }}
      # ... other options
```

## 🚀 Deployment Integration

### Automatic Deployment (Optional)
```yaml
# Add after build step
- name: Deploy to Kubernetes
  if: github.ref == 'refs/heads/main'
  run: |
    echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > ~/.kube/config
    kubectl apply -f k8s/
```

### Manual Deployment
After successful build:
```bash
# Pull latest image
docker pull your-username/wisecow-app:latest

# Update deployment
kubectl set image deployment/wisecow-deployment wisecow=your-username/wisecow-app:latest -n wisecow
```

---

**Happy CI/CD! 🚀**
