#!/bin/bash

echo "PX 2.8 Deployment Script Running on FA Cloud Volumes"
sleep 1

echo "Checking K8 Nodes are Ready"
while true; do    
	NUM_READY=`kubectl get nodes 2> /dev/null | grep -v NAME | awk '{print $2}' | grep -e ^Ready | wc -l`
    if [ "${NUM_READY}" == "4" ]; then
        echo "All ${NUM_READY} Kubernetes nodes are ready !"
        break
    else
        echo "Waiting for all Kubernetes nodes to be ready. Current ready nodes: ${NUM_READY}"
        kubectl get nodes
    fi
    sleep 5
done

echo "Make Sure you're at the master node home directory: /home/pureuser"

echo " Step 1. Verify JSON file FA API token from home directory:"
cat pure.json
sleep 10

echo " Step 2. Create Kubernetes Secret called px-pure-secret:"
kubectl create secret generic px-pure-secret --namespace kube-system --from-file=pure.json
sleep 2
kubectl get secrets -A | grep px-pure-secret
sleep 5

echo " Step 3. Install Prometheus Operator and check if the POD is running:"
kubectl apply -f portworx-pxc-operator.yaml

while true; do
    NUM_READY=`kubectl get pods -n kube-system -o wide | grep prometheus-operator | grep Running | wc -l`
    if [ "${NUM_READY}" == "1" ]; then
        echo "Prometheus pod is ready !"
        kubectl get pods -n kube-system -o wide | grep prometheus-operator | grep Running
        break
    else
        echo "Waiting for Prometheus pods to be ready. Current ready pods: ${NUM_READY}"
    fi
    sleep 5
done
sleep 2

echo " Step 4. Install PortWorx 2.8 Spec using FlashArray Cloud Drives:"
sleep 5
kubectl apply -f px-spec-2-9-ds-np.yaml

echo " Step 5. Wait for Portworx Installation to complete:"
while true; do
    NUM_READY=`kubectl get pods -n kube-system -l name=portworx -o wide | grep Running | grep 3/3 | wc -l`
    if [ "${NUM_READY}" == "3" ]; then
        echo "All portworx nodes are ready !"
        kubectl get pods -n kube-system -l name=portworx -o wide
        break
    else
        echo "Waiting for portworx nodes to be ready. Current ready nodes: ${NUM_READY}"
    fi
    sleep 5
done
echo " Checking Portworx Status"
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status
sleep 5

echo " Step 6. Login to the FlashArray and verify the Cloud Volumes have been created - http://10.0.0.11"
echo " Step 7. Configure Grafana using default user: admin | password: admin - http://10.0.0.30:30196"
echo " Step 8. Deploy K8 - PX Apps!"

