# AKS/Terraform/Traefik Ingress Sample

#### This repo demonstrates terraform infrastructure provisioning and configuration of a very basic traefik ingress configuration. It does not yet include SSL configuration.
> [!NOTE]
> This guide is based on linux shell syntax and commands. Some commands will need to be modified for Powershell.

## Infrastructure Deployment
```
# Log into Azure via the CLI
$ az login

# Confirm you are in the desired Subscription
$ az account show

# Use the following commands to set the Subscription if not already selected

# To get a list of all subscriptions
$ az account list

# To set the Subscription context
$ az account set --subscription <subscription_id>
# or
az account set --subscription-name <subscription_name>

```
### Terraform

```
# Run terraform init to initialize the Terraform deployment. This command downloads the Azure provider required to manage your Azure resources. 

$ terraform init -upgrade
```
> - The ```-upgrade``` parameter upgrades the necessary provider plugins to the newest version that complies with the configuration's version constraints.
```
# Run terraform plan to create an execution plan.
$ terraform plan -out petstore.tfplan
```
> - The ```terraform plan``` command creates an execution plan, but doesn't execute it. Instead, it determines what actions are necessary to create the configuration specified in your configuration files. This pattern allows you to verify whether the execution plan matches your expectations before making any changes to actual resources.
>- The optional ```-out``` parameter allows you to specify an output file for the plan. Using the -out parameter ensures that the plan you reviewed is exactly what is applied.
```
# Run terraform apply to apply the execution plan to your cloud infrastructure.
$ terraform apply petstore.tfplan
```
>  - The ```terraform apply``` command assumes you previously ran ```terraform plan -out petstore.tfplan```.
>  - If you specified a different filename for the ```-out``` parameter, use that same filename in the call to terraform apply.
> - If you didn't use the ```-out``` parameter, call ```terraform apply``` without any parameters.

### Confirm the Deployment
```
# Get the Azure resource group name from the terraform outputs
$ resource_group_name=$(terraform output -raw resource_group_name)
```

#### Get the Kubernetes configuration from the Terraform state and store it in a file that kubectl can read using the following command.
```
$ echo "$(terraform output kube_config)" > ./azurek8s
```
> If you see ```<< EOT``` at the beginning and ```EOT``` at the end, remove these characters from the file. 

#### Set the KUBECONFIG environment variable so kubectl can pick up the correct config using the following command.
```
$ export KUBECONFIG=./azurek8s
```

#### Verify the health of the cluster using the ```kubectl get nodes``` command.
```
$ kubectl get nodes
```

### Helm Install Traefik
> [!NOTE]
> You need to have the traefik repo registered in your helm config.
> To list you helm repos:
> ```
> $ helm repo list
> NAME                    URL
> traefik                 https://helm.traefik.io/traefik
> ```
> 
> To add the repo if not present in your list:
> ```
> $ helm repo add traefik https://helm.traefik.io/traefik
>```


```
$ helm install traefik traefik/traefik -f traefik-additional-args.yaml
```
> The traefik-additional-args.yaml allow for setting values in the congfiguration. The specific values present in
> this file are to enable the traefik dashboard in an insecure way. This is **NOT** for production use.

#### After installing traefik, AKS will provision a load balancer and a external ip. You will need this IP to configure the ingress route.
![traefik load balancer public ip](/images/traefik-public-ip.png)

### Deploy the Application
```
$ kubectl apply -f pet-store-deployment.yaml
```
> Check that the pods have created and started successfully
> ```
> $ kubectl get pods
> NAME                               READY   STATUS    RESTARTS   AGE
> order-service-76d7f5b8f5-mtbgk     1/1     Running   0          2m53s
> product-service-7566c548bd-wlz58   1/1     Running   0          2m53s
> rabbitmq-6ddd848578-mq9ps          1/1     Running   0          2m54s
> store-front-7cc6c7bb67-5tvc8       1/1     Running   0          2m53s
> ```

### Configure the traefik ingress
Using the External IP address from the AKS Services and ingresses blade of the cluster, update the pet-store-ingress.yaml file. Update the 'host' field to use the external ip. [nip.io](https://nip.io) allows you to do that by mapping any IP Address to a hostname, which is necessary as the 'host' field must be a DNS name, and not an IP address. 
``` yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pet-store
  namespace: default
spec:
  ingressClassName: traefik
  rules:
  - host: <EXTERNAL_IP>.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: store-front
            port:
              number: 80
```

### Navigate to the Website
In a browser, enter http://<EXTERNAL_IP>.nip.io

![Pet Store Page](/images/pet-store.png)

## Teardown
Generate the plan
```
$ terraform plan -destroy -out petstore.destroy.tfplan
```
Apply the plan
```
$ terraform apply petstore.destroy.tfplan
```
