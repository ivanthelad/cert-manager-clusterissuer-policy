##We installed Cilium with BYOCNI:
#az aks create \
#  --resource-group "${AZURE_RESOURCE_GROUP}" \
#  --name "${NAME}" \
#  --network-plugin none 
VM_SIZE=Standard_D4s_v3



#!/bin/bash
PREFIX='clu'

SUFFIX='mon1'

RGNAME="${PREFIX}-k8s-${SUFFIX}-rg"
RESOURCE_GROUP=$RGNAME
LOCATION='westeurope'
REGION=$LOCATION
AKSCLUSTERNAME="${PREFIX}${SUFFIX}aks"
ACRNAME="${PREFIX}${SUFFIX}acr"
VERSION="1.27.3"
GRAFANA_NAME="${PREFIX}${SUFFIX}grafana"
AZMON_NAME="${PREFIX}${SUFFIX}azmon"
AKS_IDENTITY_NAME="${PREFIX}${SUFFIX}aksidentity"
AKS_KUBELET_IDENTITY_NAME="${PREFIX}${SUFFIX}kubletidentity"
vnetName="k8svnet"
KVNAME="${PREFIX}${SUFFIX}kv"
dnszone="azuredemoapps.com"
dnszone="${PREFIX}${SUFFIX}zone.com"
certifcatename="aks-ingress-tls"
IDENTITY_RESOURCE_NAME="${PREFIX}${SUFFIX}-alb-identity"

LAWORKSPACENAME="${PREFIX}${SUFFIX}ala"
az group create --name $RGNAME --location $LOCATION

 az identity create -n  $AKS_IDENTITY_NAME -g $RGNAME -l $LOCATION 
      AKS_IDENTITY_ID="$(az identity show -n  $AKS_IDENTITY_NAME -g $RGNAME --query id -o tsv )"
      echo "created USER managed identity with id $AKS_IDENTITY_ID" 

az identity create -n  $AKS_KUBELET_IDENTITY_NAME -g $RESOURCE_GROUP -l $LOCATION  
AKS_KUBELET_IDENTITY_ID="$(az identity show -n  $AKS_KUBELET_IDENTITY_NAME -g $RGNAME --query id -o tsv )"
      echo "created USER managed identity with id $AKS_KUBELET_IDENTITY_ID" 

echo "Creating identity $IDENTITY_RESOURCE_NAME in resource group $RESOURCE_GROUP"
az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
principalId="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -otsv)"

    ## Az mon 
    az network vnet create -g $RESOURCE_GROUP --location $REGION --name $vnetName --address-prefixes "196.0.0.0/8" 
    az network vnet subnet create -g $RESOURCE_GROUP --vnet-name $vnetName --name nodesubnet --address-prefixes "196.240.0.0/16"  
     az network vnet subnet create -g $RESOURCE_GROUP --vnet-name $vnetName --name albsubnet --address-prefixes "196.10.0.0/24"    --delegations 'Microsoft.ServiceNetworking/trafficControllers'


    NODE_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $vnetName --name nodesubnet --query id -o tsv)
    ALB_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $vnetName --name albsubnet --query id -o tsv)
    VNET_ID=$(az network vnet show -g $RESOURCE_GROUP --name $vnetName --query id -o tsv)

az resource create \
--resource-group $RESOURCE_GROUP \
--namespace microsoft.monitor \
--resource-type accounts \
--name $AZMON_NAME \
--location $REGION \
--properties '{}' 
## AKS 




echo $SUBNET_ID
## --service-principal $SP_ID \
## --client-secret $SP_PASS \
sleep 40
echo managed identity $AKS_IDENTITY_ID
USER_ASSIGNED_IDENTITY_CLIENTID="$(  az identity show  --ids $AKS_IDENTITY_ID --query clientId -o tsv)"

echo creating kublet managed identity $
USER_ASSIGNED_IDENTITY_CLIENTID="$(  az identity show  --ids $AKS_IDENTITY_ID --query clientId -o tsv)"
AKS_VNET_RG=$(echo $SUBNET_ID|cut -d'/' -f 5) 
AKS_VNET=$(echo $SUBNET_ID| cut -d'/' -f 9)
echo $AKS_VNET_RG ..... $AKS_VNET .... $USER_ASSIGNED_IDENTITY_CLIENTID

az role assignment create --assignee $USER_ASSIGNED_IDENTITY_CLIENTID --role "Contributor" --scope $VNET_ID
az role assignment create --assignee $USER_ASSIGNED_IDENTITY_CLIENTID --role "Network Contributor" --scope $VNET_ID



echo kevault stuff 
az keyvault create -g $RGNAME -l $LOCATION -n $KVNAME
openssl req -new -x509 -nodes -out aks-ingress-tls.crt -keyout aks-ingress-tls.key -subj "/CN=$dnszone" -addext "subjectAltName=DNS:$dnszone"
openssl pkcs12 -export -in aks-ingress-tls.crt -inkey aks-ingress-tls.key -out aks-ingress-tls.pfx -passout pass:
az keyvault certificate import --vault-name $KVNAME -n $certifcatename -f aks-ingress-tls.pfx 
az network dns zone create -g $RGNAME -n $dnszone

echo creating log analytics
az monitor log-analytics workspace create --resource-group $RGNAME   --workspace-name $LAWORKSPACENAME

# extract the log workspace id
echo getting log analytics workspace id
LAWORKSPACEID=$(az monitor log-analytics workspace show --resource-group $RGNAME --workspace-name $LAWORKSPACENAME --query id -o tsv)
echo $LAWORKSPACEID

zonid=$(az network dns zone show  --name $dnszone -g $RGNAME --query id -o tsv)
az aks create -g $RGNAME -n $AKSCLUSTERNAME  --enable-managed-identity --node-count 3 --enable-addons monitoring --generate-ssh-keys \
 --enable-addons monitoring,azure-keyvault-secrets-provider \
 --workspace-resource-id $LAWORKSPACEID \
 --nodepool-name="basepool" \
 --node-count 3 \
 --zones 1 2 3 \
 --node-resource-group $RGNAME-managed \
 --enable-managed-identity \
 --assign-identity $AKS_IDENTITY_ID \
 --assign-kubelet-identity $AKS_KUBELET_IDENTITY_ID \
 --network-plugin azure  \
 --auto-upgrade-channel stable \
 --vnet-subnet-id $NODE_SUBNET_ID \
 --kubernetes-version $VERSION \
 --node-vm-size=$VM_SIZE \
 --node-os-upgrade-channel SecurityPatch \
 --enable-oidc-issuer --enable-workload-identity --enable-secret-rotation     
az aks get-credentials --resource-group $RGNAME --name $AKSCLUSTERNAME
exit 
 echo " installing cert manager" 
helm repo add jetstack https://charts.jetstack.io
helm repo update
##kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.2 \
  --set installCRDs=true  --set prometheus.enabled=true

echo "cert manager installed" 

#echo " installing gk controller"
#helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
#helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
#echo "gk controller installed"

 mcResourceGroupId=$(az group show --name $RGNAME-managed  --query id -o tsv)

exit
## Grafana 
az grafana create \
--name $GRAFANA_NAME \
--resource-group $RESOURCE_GROUP

MANAGEDIDENTITY_OBJECTID=$(az aks show -g ${RESOURCE_GROUP} -n ${AKSCLUSTERNAME} --query ingressProfile.webAppRouting.identity.objectId -o tsv)

export AZMON_RESOURCE_ID=$(az resource show --resource-group $RESOURCE_GROUP --name $AZMON_NAME --resource-type "Microsoft.Monitor/accounts" --query id -o tsv)
export GRAFANA_RESOURCE_ID=$(az resource show --resource-group $RESOURCE_GROUP --name $GRAFANA_NAME --resource-type "microsoft.dashboard/grafana" --query id -o tsv)
## link az mon
az aks update --enable-azure-monitor-metrics \
-n $AKSCLUSTERNAME \
-g $RESOURCE_GROUP \
--azure-monitor-workspace-resource-id $AZMON_RESOURCE_ID \
--grafana-resource-id  $GRAFANA_RESOURCE_ID



exit 
