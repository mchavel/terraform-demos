# k8s


1. To manage the EKS cluster locally via kubectl the local context needs to be updated:  

   update-kubeconfig.bash \<aws-region\> \<eks-cluster-name\>


2. To install the AWS Load Balancer Controller via Helm chart:

   install-lbc.bash \<aws-region\> \<eks-cluster-name\> \<lbc-iam-role-arn\>


3. To use EBS persistent volumes add the gp3 storage class:

   install-gp3-sc.bash


4. You can now deploy to the cluster.  Some simple Kubernetes applications are included:

   kubectl apply -f samplek8s-mongodb-pvc.yaml   

   kubectl apply -f samplek8s-mongoexpress.yaml

   kubectl apply -f samplek8s-web-nlb.yaml
   
