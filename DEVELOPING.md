## Deploying via Azure CLI with Node and Gulp
This deployment procedure features a simpler method for overriding the default parameters, but requires Node and Gulp. See [Deploying via Azure CLI with AzCopy](DEVELOPING2.md) for an alternative method.

## Dependencies
* Node (`brew install node`), version 7.6+ to support `async`
* Gulp
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)  

## Making changes
If you make changes to any file, you have to put the changed file into the blobstore that is used for provisioning. Either create a new blobstore or reuse an existing one.

If you create a new blobstore, you have to update the parameters `provisioningStorageName` and `provisioningStorageToken`
in the file `azuredeploy.parameters.json`.

## Keep parameters clean

By default, this deployment process uses the `azuredeploy.parameters.json` parameters template in this repository. To override this, copy it as `azuredeploy.parameters.local.json` to any of the Atlassian application directories. This is now your _custom parameters template_. The settings in this template will override `azuredeploy.parameters.json` when you deploy an application later.

Files named `azuredeploy.parameters.local.json` will be ignored by GIT, allowing you to test your configuration freely without accidentally checking in your changes. You'll also need to set your SSH key on this file first before any deployment (see [Jumpbox SSH Key Parameter](README.md) for instructions).

## Configuration
Before making changes to the configuration, be sure to first read the *Keeping parameters clean* section above.


1. Clone this Bitbucket repository.

    ```
    cd ~/git
    ```
    ```
    git clone git@bitbucket.org:atlassian/atlassian-azure-deployment.git
    ```

2. Enter the repository's root directory.

    ```
    cd ~/git/atlassian-azure-deployment
    ```

3. Enter your username into the `.prefix` file. This will prefix all resource groups with your username.

    ```
    echo "$(whoami)-" > .prefix
    ```

4. The `.product` file in that same directory sets what product to deploy. By default, it is set to `jira`. To deploy a different product (for example, `confluence`), replace this value:

    ```
    echo confluence > .product
    ```

The `.product` file sets which product-specific ARM templates to use during deployment.

## How to run a deployment
1. [Sign in](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest) your credentials:

    ```
    az login -u <username> -p <password>
    ```

2. Run `npm i` to install dependencies.
3. Check all of the settings of your deployment. The command in the next step will start the deployment, and it uses settings from the following files:
    * `<product>/azuredeploy.parameters.local.json`: this is where all of your product's deployment settings should be. At a minimum, your SSH key should be set properly here (see [Jumpbox SSH Key Parameter](README.md) for instructions).
    * `.prefix`: sets what prefix to use for resource groups.
    * `.product`: sets what product to deploy (`jira`, `confluence`, or `bitbucket`).
4. Run `npm start` to start the deployment.

To remove a deployment:
```
npm stop
```

To re-deploy an environment,  just run `npm start` again - it will delete the old resource group (stored in the file `.group`) and run a new deployment.

## Using SSH to connect to nodes
You can only access JIRA nodes via the NAT gateway. To connect to a node directly via the NAT gateway, you can use a
SSH command like this:
```
ssh -o 'ProxyCommand=ssh -i ~/.ssh/id_rsa jiraadmin@jiranat_address_.australiaeast.cloudapp.azure.com nc %h %p' jiraadmin@10.0.2.4
```

The default password for the `jiraadmin` user on JIRA nodes is `JIRA@dmin`.

## Building a zip for publishing
Run `gulp publish` to build a zip in the `target/` directory. Similarly with running a deployment, if you have a `.product` file with `confluence` in it,
then the publish will build the confluence deployment files. If you want to run the publish directly regardless of the `.product` file,
use `gulp publish-jira`, `gulp publish-confluence` or `gulp publish-bitbucket`.
