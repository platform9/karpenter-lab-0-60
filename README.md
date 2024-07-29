# 0-60 Lab: Managing Karpenter with Terraform

## Important notes before we begin

* As we go through the workshop, we'll alternate between discussion and lab.  Each lab builds on and assumes successful setup of the required tools and completion of the previous labs, so if you have issues or problems, please speak up right away so we can get you going again as quickly as possible.  (To make sure you have adequate time for setup, the first lab is dedicated to it.)
* When directed to edit or inspect a file, that file will be located in the top level of the workshop code directory unless stated otherwise.  For example, some of the editing we do will be in the main.tf file in the top level of the workshop code repository.  For convenience we will just write `main.tf` when we mean this file even though other `main.tf` files exist in other directories.
* During the lab, we will refer to `terraform` throughout, but the lab exercises should work with OpenTofu as well (in fact, they were written using OpenTofu) -- if you are using OpenTofu, you can either alias or rename the `tofu` command to `terraform` (which will make copying and pasting from these instructions easier), or just run `tofu` directly with the same arguments.

For various exercises you'll be asked to uncomment sections of Terraform config.  These will be set off with descriptive comment lines (starting with `#`) and multiline comment markers (using `/* */` around the section) as follows:

```
# Applying this block will complete exercise 1
/*
locals {
  my_var = "This is a local value."
}
*/
```

When asked to uncomment these sections, you'll remove only the multiline comment markers -- so the above example would become:

```
# Applying this block will complete exercise 1

locals {
  my_var = "This is a local value."
}

```


## Prerequisites (to be done before the workshop if possible)

For the initial setup of the lab, make sure you have the following utilities already installed:
* AWS CLI
* OpenTofu or HashiCorp Terraform
* kubectl
* helm
* jq

Installation procedures will vary by whether you are running on Windows, OS X or Linux -- see the linked documentation for each utility if you need assistance installing.

If your initial setup is correct, the following commands should all produce output instead of errors:

```
aws --version
```
```
terraform version
```
```
kubectl version --client
```
```
helm version
```
```
jq --null-input '. + {"status": "jq is correctly installed"}'
```

## Exercises

### Lab 1: Setup

#### Set up AWS CLI region and credentials

Configure the AWS CLI to authenticate with the credentials provided to you prior to the start of the lab -- the AWS credentials will also be used automatically by OpenTofu or Terraform when applying the Terraform config.  You will also need to configure the CLI with your preferred region for the cluster you're using for this lab.  (If you already have the CLI configured with other credentials, you can configure the credentials and region for this lab as a new profile.)

Once your AWS CLI is properly configured, you should be able to see details of your assigned EKS cluster:

```
aws eks describe-cluster --name [your cluster name]
```

#### Inspect the state of your EKS cluster

If your AWS credentials are set up correctly, you should now be able to set up `kubectl` and use it to view the initial state of the cluster.

> [!NOTE]
> The `aws eks update-kubeconfig` command will create (or update, if you run it again) the file `kube.config` in the `files` directory.  Since this contains info that might be considered sensitive, make sure you do not accidentally push this lab code to a repo with this file included.  As a precaution, this repo's .gitignore excludes the entire `files` directory from commits by default.

```
aws eks update-kubeconfig --name [your cluster name] --kubeconfig files/kube.config
```

Check that kubectl is now able to authenticate to the cluster API:

```
kubectl get po -n kube-system
```

You should see the CoreDNS pods for cluster DNS running, along with a few others.

> [!NOTE]
> About your cluster:
> * The clusters used in this lab were created with the Terraform config found in the `simple-eks` directory.  You do not need to apply this code during this lab, it's provided just for your reference.  However, should you wish to rerun the lab later in your own AWS account, you can use that code to create the necessary EKS cluster.
> * The lab cluster has a single EKS managed node group running a single node -- this allows CoreDNS and Karpenter to run on nodes not subject to being deprovisioned by Karpenter.

Initialize the Terraform directory for later use:

```
terraform init
```

This should download and install all the Terraform providers that will be used later in the lab.

Lastly, edit the `terraform.tfvars` file to set the workshop_cluster variable to your assigned cluster name.  After doing so, you should be able to run a plan without errors:

```
terraform plan
```

Now you can use `kubectl`, `helm` and the provided Terraform config to manage your EKS cluster for the rest of the lab.

#### Run a single replica of the test workload

As we progress through the lab, we'll be scaling a test workload up and down to show Karpenter in action.  As the final step of setup, we'll install that workload as a single-replica deployment with Terraform.  This "workload" actually does nothing at all, but has a large amount of CPU and memory requested, so it will trigger Karpenter to provision or disrupt nodes when we scale it up or down.

> [!NOTE]
> We deploy the test workload with no `replicas` parameter specified in its manifest, so the default number of replicas is 1.  Not specifying the number of replicas allows other tools like `kubectl` or the Horizontal Pod Autoscaler to control the actual number of replicas dynamically.

Uncomment the `resource "kubernetes_deployment_v1" "test_workload"` stanza in `main.tf`, then run a plan:

```
terraform plan
```

Assuming there were no errors, apply the updated configuration:

```
terraform apply
```

(During the remainder of the lab, for brevity we will refer to the above two steps as "plan and apply".)

After the apply is successful, you should be able to see the test workload running in the `workshop` namespace with kubectl:

```
kubectl get pods -n workshop
```

### Lab 2: Install and configure Karpenter

#### Install Karpenter with Terraform

As noted in the discussion portion of the workshop, while the Karpenter project publishes infrastructure configuration artifacts as CloudFormation and Terraform configuration is capable of representing the same resources, there's no 100% reliable translator from CloudFormation to Terraform config.  For this part of the lab we'll use a copy of the Karpenter sub-module from the community-maintained `terraform-aws-modules` GitHub project.

Uncomment the `module "karpenter"` stanza in `main.tf`, then plan and apply.

This will create the resources Karpenter needs but doesn't (yet) install Karpenter itself.  (The apply may take a few minutes because it creates some new infrastructure like an Amazon SQS queue.)

Once the first apply completes successfully, you can install the Karpenter Helm chart with Terraform.  Uncomment the `resource "helm_chart" "karpenter"` stanza in `main.tf`, then plan and apply.  If this is succesful, you should be able to monitor the status of the helm chart install with the helm CLI:

```
helm status lab-karpenter
```

Once the install completes, you'll be ready to move on.

#### Create a Karpenter EC2NodeClass and NodeGroup



#### Scale up the test workload to trigger autoscaling

#### Scale down the test workload to trigger consolidation

### Lab 3: Maintaining Karpenter for day 2 and beyond

#### Edit your EC2NodeClass

#### Update Karpenter



### Lab 4: Cleaning up

To remove Karpenter from your cluster, 

## Additional learning resources