#!/bin/bash

region="${1:-us-east-1}"
cluster_name="${2:-DemoEKSCluster}"

aws eks --region $region update-kubeconfig --name $cluster_name

