## Deploying via Azure CLI with AzCopy
This page contains alternative methods to the ones found on [Deploying via Azure CLI with Node and Gulp](DEVELOPING.md). The configuration and deployment instructions on this page are more suited to developers who are comfortable with command-line programming, or for those who prefer not to install NodeJS/Gulp dependencies.

## Dependencies  
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)  
* [AzCopy](https://github.com/Azure/azure-storage-azcopy)  


## Creating a custom parameters template

A _custom paramaters template_ is a JSON file that contains parameters for a customized deployment. You can use this template as a basis for other templates; for example, you can have separate custom parameters templates for Confluence, Jira Service Desk, or similar instances with different database schemas.

1. Clone this Bitbucket repository.

    ```
    cd ~/git
    ```

    ```
    git clone git@bitbucket.org:atlassian/atlassian-azure-deployment.git
    ```

2. Create a [blobstore](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-cli) in a new storage account. Keep this storage account in a resource group separate from any deployment.   

    ```
    az group create --name blobstoreresourcegroup --location eastus
    ```

    ```
    az storage account create --name storageaccount --resource-group blobstoreresourcegroup --location eastus --sku Standard_LRS
    ```

    ```
    [...]
      "primaryEndpoints": {
        "blob": "https://storageaccount.blob.core.windows.net/",
        "dfs": null,
        "file": "https://storageaccount.file.core.windows.net/",
        "queue": "https://storageaccount.queue.core.windows.net/",
        "table": "https://storageaccount.table.core.windows.net/",
        "web": null
        },
    [...]
    ```

3. Create a [SAS token](https://docs.microsoft.com/en-us/cli/azure/storage/account?view=azure-cli-latest#az-storage-account-generate-sas).

    ```
    az storage account generate-sas --account-name storageaccount --services bfqt --resource-types sco --permissions cdlruwap --expiry $(date --date "next year" '+%Y-%m-%dT%H:%MZ')
    "se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D"
    ```

4. Create a container for each Atlassian application (for example, `jiratemplateupload` for Jira, or `confluenceupload` for Confluence):  

    ```
    az storage container create --name jiratemplateupload --account-name storageaccount --sas-token 'se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D'
    ```

5. Use AzCopy to upload edited templates/scripts to the blobstore (do this before each deployment). Note the use of the blob's primary endpoint and the question mark prefix on the SAS token.  

    ```
    ~/apps/azcopy/azcopy --quiet --source ~/git/atlassian-azure-deployment/jira/ --destination https://storageaccount.blob.core.windows.net/jiratemplateupload/ --recursive --dest-sas '?se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D'
    ```

    Since you will be using the same AzCopy command often, you might want to copy/paste this command into a new script file (for example, `~/atlassian/bin/azupload`).  

6. Create a local directory for your templates and copy the default `azuredeploy.parameters.json` to there:  

    ```
    mkdir -p ~/atlassian/templates
    ```

    ```
    cp azuredeploy.parameters.json ~/atlassian/templates/myparameterstemplate.json
    ```

    The `~/atlassian/templates/myparameterstemplate.json` file is your new _parameters file_, which you can now edit to suit your needs.


Before you can use your parameters template in a deployment, open it first and update the following parameters:

* `_artifactsLocation`: the blob primary endpoint. By default, this parameter will point to the `master` branch in this Bitbucket repo.

* `_artifactsLocationSasToken`: the SAS token you generated in step 3.

* `sshKey`: your SSH public key (for example, `~/.ssh/id_rsa.pub`).

For example:
```
{
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "canadacentral"
        },
        "_artifactsLocation": {
            "value": "https://storageaccount.blob.core.windows.net/jiratemplateupload/"
        },
        "_artifactsLocationSasToken": {
            "value": "?sv=2017-11-09&ss=bfqt&srt=sco&sp=rwdlacup&se=2028-10-24T23:00:00Z&st=2018-10-24T23:00:00Z&spr=https,http&sig=vGvcjMRxHZFlD69KxUytEkuWwG8ojUehkgdRupyLVME%3D"
        },
        "jiraClusterSize": {
            "value": "small"
        },
        "dbPassword": {
            "value": "P@55w0rd"
        },
        "jiraAdminUserPassword": {
            "value": "admin"
        }
        "sshKey": {
                "value": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA...."
        }
    }
}
```

At this point, you can now deploy using this new parameters template.

## Deploying via Azure CLI
Use the `--parameters` option reference a specific parameters template during deployment. For example, to deploy an instance using `~/atlassian/templates/myparameterstemplate.json`:

```
cd ~/git/atlassian-azure-deployment/jira
```

```
az group create --resource-group mydeployresourcegroup --location canadacentral
~/atlassian/bin/azupload && az group deployment create --resource-group mydeployresourcegroup --template-file mainTemplate.json --parameters ~/atlassian/templates/myparameterstemplate.json
```

## Deleting a Deployment  
To delete a deployment, simply delete its resource group:
```
 az group delete --resource-group mydeployresourcegroup
```

## Static Code Analysis  
To check for common template errors, install and use Microsoft's [Quickstart Validation tests](https://github.com/Azure/azure-quickstart-templates/tree/master/test/template-validation-tests):  
```
npm --folder=/home/user/git/atlassian-azure-deployment/jira run all
```
