#!/bin/bash

region="${1:-us-east-1}"
cluster_name="${2:-DemoEKSCluster}"
arn="${3:-arn:aws:iam::817697258182:role/DemoEKSClusterLBCRole}"

# Install the TargetGroupBinding CRDs: 
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# Install the AWS Load Balancer controller:
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$cluster_name \
  --set image.repository=602401143452.dkr.ecr.$region.amazonaws.com/amazon/aws-load-balancer-controller \
  -f - <<EOF
serviceAccount:
  create: true
  name: aws-load-balancer-controller
  annotations:
    eks.amazonaws.com/role-arn: $arn
EOF
