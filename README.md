# InfluxEnterprise Azure Marketplace offering

__Note: These templates are still under active development. They are not recommended for production.__

## Publishing a new image

### Generate a SAS

A Shared Access Signature (SAS) URL is required by the Partner Portal to import a VHD ([official guide](https://docs.microsoft.com/en-us/azure/marketplace/cloud-partner-portal/virtual-machine/cpp-get-sas-uri)).
Packer is used to build the images and will only create managed disks.
In order to create the SAS URL, the underlying VHD of the managed disk needs to be extracted and put in a storage account.
The  script that handles the steps in [this guide](https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-linux-cli-sample-copy-managed-disks-vhd) provides instructions on how to extract the VHD and create the SAS URL.

This repository consists of:

* [src/mainTemplate.json](src/mainTemplate.json) - Entry Azure Resource Management (ARM) template.
* [src/createUiDefinition](src/createUiDefinition.json) - UI definition file for our market place offering. This file produces an output JSON that the ARM template can accept as input parameters JSON.

### Command line deploy

first make sure you are logged into azure

```shell
$ az login
```

Then make sure you are in Incremental mode

```shell
$ az config mode Incremental
```

Then create a resource group `<group>` in a `<location>` (e.g `centralus`) where we can deploy too

```shell
$ az group create <group> <location>
```
You will need to accept the `Legal Terms` of the offer before deploying the template. 

```shell
$ az vm image accept-terms --urn influxdata:influxdb-enterprise-vm:influxdb-enterprise-data-byol:1.7.90
$ az vm image accept-terms --urn influxdata:influxdb-enterprise-vm:influxdb-enterprise-meta-byol:1.7.90
```

Next we can either use our published template directly using `--template-uri`

> az group deployment create --template-uri https://raw.githubusercontent.com/chobbs/ARM-Templates/master/src/mainTemplate.json --verbose --resource-group "${group}" --mode Incremental --parameters parameters/password.parameters.json

or if your are executing commands from a clone of this repo using `--template-file`

> $ az group deployment create --template-file src/mainTemplate.json --parameters parameters/password.parameters.json

> az group deployment create --template-file src/mainTemplate.json --verbose --resource-group "${group}" --mode Incremental --parameters parameters/password.parameters.json

`<group>` in these last two examples refers to the resource group you just created.

**NOTE**

The `--parameters` can specify a different location for the items that get provisioned inside of the resource group. Make sure these are the same prior to deploying if you need them to be. Omitting location from the parameters file is another way to make sure the resources get deployed in the same location as the resource group.

### Web based deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchobbs%2FARM-Templates%2Fmaster%2Fsrc%2FmainTemplate.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

The above button will take you to the autogenerated web based UI based on the parameters from the ARM template.

It should be pretty self explanatory except for password which only accepts a json object. Luckily the web UI lets you paste json in the text box. Here's an example:

> {"sshPublicKey":null,"authenticationType":"password", "password":"Password1234"}
