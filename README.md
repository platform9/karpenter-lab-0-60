# 0-60 Lab: Managing Karpenter with Terraform

## Important notes before we begin

* As we go through the workshop, we'll alternate between discussion and lab.  Each lab builds on and assumes successful setup of the required tools and completion of the previous labs, so if you have issues or problems, please speak up right away so we can get you going again as quickly as possible.  (To make sure you have adequate time for setup, the first lab is dedicated to it.)
* When directed to edit or inspect a file, that file will be located in the top level of the workshop code directory unless stated otherwise.  For example, some of the editing we do will be in the `main.tf` file in the top level of the workshop code repository.  For convenience we will just write `main.tf` when we mean this file even though other `main.tf` files may exist in other directories.
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
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [OpenTofu](https://opentofu.org/docs/intro/install/) or [HashiCorp Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [helm](https://helm.sh/docs/intro/install/)
* [jq](https://jqlang.github.io/jq/download/)

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
> The `aws eks update-kubeconfig` command below will update the default kubeconfig file.  If you don't want to update your default kubeconfig file with the lab config, run the "Update alternate kubeconfig" command instead and it will create (or update, if you run it again) the file `kube.config` in the `files` directory.  If you use this option, you may need to add arguments to `kubectl` and `helm` commands during the rest of the lab to direct them to use that file instead of the default.  Also, since the kubeconfig contains info that might be considered sensitive, make sure you do not accidentally push this lab code to a repo with this file included.  (As a precaution, this repo's .gitignore excludes the entire `files` directory from commits by default.)

Update the default kubeconfig:
```
aws eks update-kubeconfig --name [your cluster name]
```

Update alternate kubeconfig:
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
> * The clusters used in this lab were created with the Terraform config found in the `platform9/simple-eks` GitHub repo.  You do not need to apply this code during this lab, it's provided just for your reference.  However, should you wish to rerun the lab later in your own AWS account, you can use that code to create the necessary EKS cluster.
> * The lab cluster has a single EKS managed node group running a single node to allow CoreDNS and Karpenter to run on nodes not subject to being deprovisioned by Karpenter.

Now initialize the Terraform directory for later use:

```
terraform init
```

This should download and install all the Terraform providers that will be used later in the lab.

Lastly, rename the `lab.tfvars` file to `terraform.tfvars` and edit it to set the workshop variables for your assigned cluster name, your cluster's AWS region, and the owner string that will be used for some resource tags (note: use only alphanumeric characters in the value of the `owner` variable or some applies later may fail).

At this point you should be able to run a plan without errors:

```
terraform plan
```

Now you can use `kubectl`, `helm` and the provided Terraform config to manage your EKS cluster for the rest of the lab.

#### Run a single replica of the test workload

As we progress through the lab, we'll be scaling a test workload up and down to show Karpenter in action.  As the final step of setup, we'll install that workload as a single-replica deployment with Terraform.  This "workload" actually does nothing at all, but has a large amount of CPU and memory requested, so it will trigger Karpenter to provision or disrupt nodes when we scale it up or down.

> [!NOTE]
> We deploy the test workload with no `replicas` parameter specified in its manifest, so the default number of replicas is 1.  Not specifying the number of replicas allows other tools like `kubectl` or the Horizontal Pod Autoscaler to control the actual number of replicas dynamically.

Uncomment the `resource "kubernetes_namespace_v1" "lab"` and `resource "kubernetes_deployment_v1" "test_workload"` stanzas in `main.tf`, then run a plan:

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
kubectl get pods -n karpenter-lab
```

### Lab 2: Install and configure Karpenter

#### Install Karpenter with Terraform

As noted in the discussion portion of the workshop, while the Karpenter project publishes infrastructure configuration artifacts as CloudFormation and Terraform configuration is capable of representing the same resources, there's no 100% reliable translator from CloudFormation to Terraform config.  For this part of the lab we'll use a copy of the Karpenter sub-module from the community-maintained `terraform-aws-modules` GitHub project, since the maintainer has already done the work of creating native Terraform equivalents of the CloudFormation resource definitions.

Uncomment the `resource "aws_eks_addon" "identity-agent"` and `module "eks_karpenter"` stanzas in `main.tf`.

Because you just enabled a new module that Terraform hasn't initialized yet, you'll need to run `terraform init` again, then you can plan and apply.

This will create the resources Karpenter needs but doesn't (yet) install Karpenter itself.  (The apply may take a few minutes because it creates some new infrastructure like an Amazon SQS queue.)

Once the first apply completes successfully, you can install the Karpenter Helm chart with Terraform.  Uncomment the `resource "helm_release" "karpenter_crd"` and `resource "helm_release" "karpenter"` stanzas in `main.tf`, then plan and apply.

If this is successful, you should be able to monitor the status of the helm chart install with the helm CLI:

```
helm status -n kube-system karpenter
```

Once the install completes, you'll be ready to move on.

#### Create a Karpenter EC2NodeClass and NodeGroup

Uncomment the `resource "kubernetes_manifest" "karpenter_nodeclass"` and `resource "kubernetes_manifest" "karpenter_nodepool"` stanzas in `main.tf`, then plan and apply.

This finally will create the NodeClass and NodePool that Karpenter will use to handle scaling.

#### Scale up the test workload to observe autoscaling

Scale up the test workload to 4 replicas:

```
kubectl scale deployment -n karpenter-lab karpenter-lab-workload --replicas 4
```

Now list the pods in the `karpenter-lab` namespace:

```
kubectl get po -n karpenter-lab
```

At least one should show as Pending.  Note that the Pending pods do not (yet) trigger Karpenter to scale the cluster, so they don't ever get scheduled.  This is because our NodeClass applies a taint to the nodes it creates, and the test workload does not currently tolerate that taint.

To enable the taint, look in the `locals` stanza.  There is a local value called `add_tolerations` which is set to `false`.  Set this to `true` -- this will cause a dynamic `toleration` block that tolerates the NodePool-applied taint to be created next time you apply the Terraform config.  Now plan and apply.

Wait a minute or so and list the cluster nodes:

```
kubectl get nodes
```

You should see a new node appear in the list (if not, keep trying a few more times, but it shouldn't take longer than a minute or two from the time your apply succeeds).  After the node appears, your pods should quickly all show as Running:

```
kubectl get po -n karpenter-lab
```

#### Scale down the test workload to trigger consolidation

Scale the test deployment back to 1 replica:

```
kubectl scale deployment -n karpenter-lab karpenter-lab-workload --replicas 1
```

Wait a minute or so and list the nodes again as above.  You should see that the new node created by Karpenter is now gone.

### Lab 3: Maintaining Karpenter for day 2 and beyond

#### Update Karpenter

One of the variables passed in to the Terraform config for the Karpenter Helm charts is the version of Karpenter to install.  At the start of the lab, it's set to `0.36.1`.  Upgrade Karpenter to `0.37.0` by either changing the default value in `variables.tf`, or adding a new variable declaration to your `terraform.tfvars` file, then plan and apply.

Now, repeat the scale-up/scale-down exercise from the previous lab to verify Karpenter is still working.

#### Experiment with your EC2NodeClass and NodePool

For the final part of the lab, experiment with the configuration of the EC2NodeClass and NodePool.  As an example, try adding new instance families to the list in the `karpenter_nodepool_instance_families` variable, then repeating the scale-up test to see what kind of instance Karpenter provisions (look at the `node.kubernetes.io/instance-type` label on the node to see the instance type).

## Additional learning resources

* GitHub repos:
  * [platform9/karpenter-lab-0-60](https://github.com/platform9/karpenter-lab-0-60)
  * [platform9/simple-eks](https://github.com/platform9/simple-eks)
  * [terraform-aws-modules/terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)
* [Karpenter docs](https://karpenter.sh/docs/)
