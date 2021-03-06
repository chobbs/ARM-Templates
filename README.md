# InfluxEnterprise Azure Marketplace offering

__Note: These templates are still under active development. They are not recommended for production.__

## Publishing a new image

This repository consists of:

* [src/mainTemplate.json](src/mainTemplate.json) - Entry Azure Resource Management (ARM) template.
* [src/createUiDefinition](src/createUiDefinition.json) - UI definition file for our market place offering. This file produces an output JSON that the ARM template can accept as input parameters JSON.


## ARM template

The output from the market place UI is fed directly to the ARM template. You can use the ARM template on its own without going through the market place.

### Parameters

<table>
  <tr><th>Parameter</td><th>Type</th><th>Description</th></tr>
  <tr><td>loadBalancerType</td><td>string</td>
    <td>Whether the loadbalancer should be <code>internal</code> or <code>external</code>
    </td></tr>
  <tr><td>chronograf</td><td>string</td>
    <td>Either <code>Yes</code> or <code>No</code> provision an extra machine with a public IP that
    has Chronograf installed on it.
    </td></tr>

  <tr><td>vmSizeDataNodes</td><td>string</td>
    <td>Azure VM size of the data nodes see <a href="https://github.com/influxdata/azure-resource-manager-influxdb-enterprise/blob/master/src/mainTemplate.json#L69">this list for supported sizes</a>
    </td></tr>

  <tr><td>vmDataNodeCount</td><td>int</td>
    <td>The number of data nodes you wish to deploy. (Min: 2 | Max: 6).
    </td></tr>

  <tr><td>vmDataNodeDiskSize</td><td>string</td>
    <td>The disk size of each attached disk. Choose <code>1TiB</code>, <code>512GiB</code>, <code>256GiB</code>, <code>128GiB</code>, <code>64GiB</code> or <code>32GiB</code>.
    For Premium Storage, disk sizes equate to <a href="https://docs.microsoft.com/en-us/azure/storage/storage-premium-storage#premium-storage-disks-limits">P80, P70, P60, P50, P40, P30, P20, P15, P10 and P6</a>
    storage disk types, respectively.
    </td>

  <tr><td>adminUsername</td><td>string</td>
    <td>Admin username used when provisioning virtual machines
    </td></tr>

  <tr><td>password</td><td>object</td>
    <td>Password is a complex object parameter, we support both authenticating through username/pass or ssh keys. See the <a href="https://github.com/influxdata/azure-resource-manager-influxdb-enterprise/tree/master/parameters"> parameters example folder</a> for an example of what to pass for either option.
    </td></tr>

  <tr><td>influxdbPassword</td><td>securestring</td>
    <td>InfluxDB password for the <code>admin</code> user with all privs, must be &gt; 6 characters 
    </td></tr>

  <tr><td>location</td><td>string</td>
    <td>The location where to provision all the items in this template. Defaults to the special <code>ResourceGroup</code> value which means it will inherit the location
    from the resource group see <a href="https://github.com/influxdata/azure-resource-manager-influxdb-enterprise/blob/master/src/mainTemplate.json#L197">this list for supported locations</a>.
    </td></tr>

</table>

### Command line deploy

Begin by making sure you're logged into your azure account subscription.

```shell
$ az login
```

You can use the `deploy.sh` script to publish the template. The script will prompt you for a resourceGroup, if the group
does not exit it will be created.

```shell
$ ./deploy.sh
```

After the initial creation, you can continue to publish *Incremental* deployments using one of the following commands.
You can published this repo template directly using `--template-uri`

> az group deployment create --template-uri https://raw.githubusercontent.com/influxdata/azure-resource-manager-influxdb-enterprise/master/src/mainTemplate.json --verbose --resource-group "${group}" --mode Incremental --parameters parameters/password.parameters.json

or if your are executing commands from a clone of this repo using `--template-file`

> az group deployment create --template-file src/mainTemplate.json --verbose --resource-group "${group}" --mode Incremental --parameters parameters/password.parameters.json

`<group>` in these last two examples refers to the resource group created by the deploy.sh script.

**NOTE**

The `--parameters` can specify a different location for the items that get provisioned inside of the resource group. Make sure these are the same prior to deploying if you need them to be. Omitting location from the parameters file is another way to make sure the resources get deployed in the same location as the resource group.

### Web based deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Finfluxdata%2Fazure-resource-manager-influxdb-enterprise%2Fmaster%2Fsrc%2FmainTemplate.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

The above button will take you to the autogenerated web based UI based on the parameters from the ARM template.

It should be pretty self explanatory except for password which only accepts a json object. Luckily the web UI lets you paste json in the text box. Here's an example:

> {"sshPublicKey":null,"authenticationType":"password", "password":"Password1234"}
