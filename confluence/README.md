# Atlassian Confluence Data Center

Confluence Data Center gives you uninterrupted access to Confluence with performance at scale, disaster recovery and instant scalability when hosting our applications in your Azure private cloud account.

## Confluence Architecture

The original version of the Azure templates created a standalone Synchrony cluster as part of the deployment. These templates follow the now recommended approach of letting Confluence manage Synchrony for you. This will reduce setup maintenance and cost. For more information see the [Set up a Synchrony Cluster for Confluence Data Center](https://confluence.atlassian.com/display/DOC/Set+up+a+Synchrony+cluster+for+Confluence+Data+Center) article.

## Deploy to Azure Portal

[![Deploy Confluence Data Center to Azure Portal](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fbitbucket.org%2Fatlassian%2Fatlassian-azure-deployment%2Fraw%2Fmaster%2Fconfluence%2FmainTemplate.json)

Note: The current Azure deployment utilizes certain Azure functionality like App Insights, Azure Monitoring, SQL Analytics etc that are still in Preview mode and not available in most regions. To ensure you can utilize these technologies deploy into the following regions:  

1. Canada Central  
2. Central India  
3. East US  
4. Southeast Asia  
5. UK South  
6. West Europe  
7. West US 2  


You can of course disable App Insights, Analytics etc via the template parameters to allow installation to your desired region.  

NB That the templates will download the latest version available from Atlassian Download site. These new releases might introduce breaking changes but you can always specify particular version by updating the confluenceVersion parameter.

Further information on parameters and other installation options for the Atlassian Azure solution can be found at our [Confluence Azure Support Page](https://confluence.atlassian.com/doc/getting-started-with-confluence-data-center-on-azure-937176452.html)  

## View Azure Deployment Results

View deployment output values in Azure Portal for endpoints, DB url etc.  
![Confluence Deployment Results](images/ConfDeploymentResults.png "Confluence Deployment Results")
