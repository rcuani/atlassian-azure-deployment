# Deployment customizations

The [Jira Software](jira/mainTemplate.json), [Jira Service Desk](servicedesk/mainTemplate.json), and [Confluence](confluence/mainTemplate.json) templates in this repository provide common parameters for customizing your deployment.

## Basic customizations

You can configure these settings through the available Azure Marketplace interface *or* through a _custom parameters template_ during a CLI deployment.

### Custom domain name

Azure doesn't register domain names, so you'll have to secure yours through a separate third-party domain provider like GoDaddy or CloudFlare. You can set your custom domain name through the Azure Marketplace templates in the *Configure Domain* step. For CLI deployments, use the `cname` parameter:

```
    {
        "parameters": {
            "cname": {
                "value": "mycustomdomainname.com"
            }
        }
    }
```

When you set a custom domain like `mycustomdomainname.com`, our templates will create a DNS Zone called `jira.mycustomdomainname.com` configured with the relevant Azure DNS Name Servers. You can add these Azure Name Servers to your domain configuration to provide a public endpoint of http://jira.mycustomdomainname.com.

For more information, see https://docs.microsoft.com/en-us/azure/dns/dns-zones-records.

### SSL

From the Azure Marketplace templates, you can enable HTTPS/SSL and configure it through the *Configure Domain* step. There, you'll be asked to provide your own _Base64-encoded PFX certificate_ and its corresponding password.

For CLI deployments, use the `sslBase64EncodedPfxCertificate` and `sslPfxCertificatePassword` parameters:

```
    {
        "parameters": {
            "sslBase64EncodedPfxCertificate": {
                "value": "-----BEGIN CERTIFICATE-----MIIF2zCCBMOgAwIBAgIQMj8HjgweXkb..."
            }
            "sslPfxCertificatePassword": {
                "value": "Myazurepassword1!"
            }
        }
    }
```

With HTTPS enabled, all incoming HTTP traffic will be redirected to HTTPS for added security. For more information, see https://docs.microsoft.com/en-us/azure/application-gateway/redirect-http-to-https-cli.

## Advanced customizations

You can only configure the following customizations through the CLI.

### Linux Distribution

By default, our templates will deploy your chosen product on [Ubuntu 18.04 LTS](https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes). You can override this with the following Linux distributions (all supported):

- "Canonical:UbuntuServer:16.04-LTS",
- "RedHat:RHEL:7.5",
- "OpenLogic:CentOS:7.5",
- "credativ:Debian:9-backports"

To use any of these distributions, set the `linuxOsType` parameter. For example, to use Red Hat Enterprise Linux 7.5:

```
    {
        "parameters": {
            "linuxOsType": {
                "value": "RedHat:RHEL:7.5"
            }
        }
    }
```

### Custom Download URL

By default, our templates will only download and install supported releases of each product. If you want to deploy unsupported development versions like [EAP](https://developer.atlassian.com/server/framework/atlassian-sdk/early-access-programs/)s, release candidates, or betas, you need to configure your deployment to download them from a different source.

You can specify this source through the `customDownloadUrl` parameter. You'll also need to set the EAP, beta, or other development version of the product through `jiraVersion` or `confluenceVersion`. See [Jira Development Releases](https://confluence.atlassian.com/adminjira/jira-development-releases-955171963.html) and [Confluence Development Releases](https://confluence.atlassian.com/doc/confluence-development-releases-8163.html) for details on available pre-release versions.

The following snippets demonstrate how to target some pre-release versions:

**Jira Software 8.1.0 EAP**

```
  {
    "parameters": {
      "jiraProduct": {
        "value": "jira-software"
        },
      "jiraVersion": {
        "value": "8.1.0-EAP02"
        },
      "customDownloadUrl": {
        "value": "https://www.atlassian.com/software/jira/downloads/binary/"
        },
      }
    }
```

**Jira Service Desk 4.0.0 Release Candidate**

```
  {
    "parameters": {
      "jiraProduct": {
        "value": "servicedesk"
        },
      "jiraVersion": {
        "value": "4.0.0-RC"
        },
        "customDownloadUrl": {
          "value": "https://www.atlassian.com/software/jira/downloads/binary/"
        },
      }
    }
```

**Confluence 6.15 Milestone**

```
    {
        "parameters": {
          "confluenceVersion": {
            "value": "6.15.0-m30"
            },
          "customDownloadUrl": {
            "value": "https://www.atlassian.com/software/confluence/downloads/binary"
            },
        }
    }
```
