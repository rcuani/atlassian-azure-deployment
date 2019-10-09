#!/bin/bash

for rg in $(az group list --query [].name | sed 's/ *//g' | sed 's/"//g' | grep ^BB_PIPELINE | sed 's/,//g')
do
        echo "Deleting resource group: $rg"
        vaultName=$(az backup vault list --resource-group $rg --query [].name -o tsv)
        az backup protection disable --resource-group $rg --vault-name $vaultName --container-name "IaasVMContainer;iaasvmcontainerv2;$rg;bitbucket-nfs" --item-name bitbucket-nfs --delete-backup-data true --yes
        az group delete --resource-group $rg --yes --no-wait
done
