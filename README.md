# cert-manager-clusterissuer-policy

This repo demostrates two implementations how to enforce a namespace in K8S to only a limited set of  clusterissuer. Theres two ConstraintTemplate defintions 
 * (tests/DenyClusterBasedOnAnnotationTemplate.yaml):  Checks if Certificate's origin namespace is found in annotation "allowedNamespaces" of the the ClusterIssuer the certificate. If not found, this results in a violation. This only works on the opensource gatekeeper as today azure policy does not support using data-inventory caches `metadata.gatekeeper.sh/requires-sync-data`  
 * (tests/DenyClusterBasedOnSimpleNameTemplate.yaml): Checks if certifcate is referencing a clusterissuer which has the naming convention. The expectation is the field  issuerRef.name =  "$Certificat-NS-clusterissuer". If its not the same then the policy fails. This works on opensource gatekeeper and azure policy


## To Test in azure policy
* Deploy Azure Policy to an aks cluster 
* Create a new Policy Definition based on [defintion](/azurepolicy/clusterissuer.yaml)
* Assign Policy to scope which includes the aks cluster 

### Postive allow Test 
 * Create a ns called `kubectl create ns ns-level2-dev-something`
 * Deploy a Certificate `kube apply -f setup/selfsigned.certificate.yaml -n ns-level2-dev-something`
 * this should be succesfully created 

### Negative deny Test 
 * Create a ns called `kubectl create ns ns-level2-dev-something`
 *  modify setup/selfsigned.certificate.yaml file and update field `spec.issuerRef.name` to any string  
 * Deploy a Certificate `kube apply -f setup/selfsigned.certificate.yaml -n ns-level2-dev-something`
 * this should be denied created. With message  `Certificate with name [my-selfsigned-ca] in your namespace  [ns-level2-dev-something] does is attempting to use Issuer   [ns-level2-dev-something-clusffterissuer]. This certificate is only allowed to use  ClusterIssuer [ns-level2-dev-something-clusterissuer]`
  
  ![ ](/assets/deny.png)

# Install Azure Policy 


## Enable Azure Policy
See
*  https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks

## Deploy Policy 
 Thze defintion for azure policy can be found under [here](/azurepolicy/clusterissuer.yaml)
 this definition can be copied and pasted in the the azure policy UI and applied to the target. Simple go to Azure Policy -> Definitions-> new Defintions  
 * Scope: 
 * Name
  * Description 
  * Policy Rule: copy and paste the content  [under here](/azurepolicy/clusterissuer.yaml) to this field 
![ ](/assets/addpolicy.png)

This policy does not accept any custom paramaters. these can be added later. 

### Base64  encodiong of template. 
To policy has the template constraint added as abase64 encoded file instead of a remote file. if you make modifications be sure to update the base64 content in the field templateinfo.content 
```
base64 -i  tests/DenyClusterBasedOnSimpleNameTemplate.yaml -o out.base64
```

The contents from out.base64 can be copied directly to the field "content"

###  Policy descriptions 
The active selection is a part of a JSON configuration file, specifically for a Gatekeeper policy. Gatekeeper is a customizable admission webhook for Kubernetes that enforces policies executed by the Open Policy Agent (OPA), a policy engine for Cloud Native environments.
```
    "then": {
      "effect": "[parameters('effect')]",
      "details": {
        "templateInfo": {
          "sourceType": "Base64Encoded",
          "content": "YXBpVmVyc2lvbjogdGVtxxxxxxgICAgCiAgICAgICA="
        },
        "apiGroups": [
          "cert-manager.io"
        ],
        "kinds": [
          "Certificate"
        ],
        "excludedNamespaces": "[parameters('excludedNamespaces')]",
        "namespaces": "[parameters('namespaces')]",
        "labelSelector": "[parameters('labelSelector')]"
      }
    }
  },
```


The then block defines what actions should be taken when the conditions specified in the if block (not shown in the selection) are met.

The effect field is set to the value of a parameter named effect. This parameter determines the effect of the policy, which could be deny, warn, or audit.

The details block contains more specific information about the policy:

* templateInfo specifies the source and content of the ConstraintTemplate that defines the policy. The sourceType is Base64Encoded, which means the content is a base64-encoded string representing a ConstraintTemplate in YAML format. This template includes a Rego policy that checks if a Certificate resource is being created or updated, and if the issuer of the Certificate is not the expected one, it triggers a violation.

* apiGroups specifies the API groups that the policy applies to. In this case, it's cert-manager.io.

* kinds specifies the kinds of resources that the policy applies to. In this case, it's Certificate.

* excludedNamespaces is set to the value of a parameter named excludedNamespaces. This parameter specifies the namespaces that are excluded from the policy.

* namespaces is set to the value of a parameter named namespaces. This parameter specifies the namespaces that the policy applies to.

 * labelSelector is set to the value of a parameter named labelSelector. This parameter specifies the labels of the resources that the policy applies to.

In summary, this policy checks if a Certificate resource in the cert-manager.io API group is being created or updated, and if the issuer of the Certificate is not the expected one, it triggers a violation. The policy applies to the resources in the specified namespaces and with the specified labels, except for the resources in the excluded namespaces.

~~
## ~~ConstraintTemplate For Azure Policy  using inventory Cache~~ 

~~The metadata.gatekeeper.sh/requires-sync-data field is a special annotation used by Gatekeeper. This annotation tells Gatekeeper that this ConstraintTemplate requires certain Kubernetes resources to be synced for use in the Rego policies. The value of this field is a JSON-formatted string that specifies the group, version, and kind (GVK) of the resources to be synced.~~

~~In this case, the GVK is cert-manager.io/v1/ClusterIssuer. This means that the ConstraintTemplate requires Gatekeeper to sync the ClusterIssuer resources from the cert-manager.io group and the v1 version. The synced resources can then be accessed in the Rego policies using the data.inventory document.~~
```
   metadata.gatekeeper.sh/requires-sync-data: |
      "[
        [
          {
            "groups": ["cert-manager.io"],
            "versions": ["v1"],
            "kinds": ["ClusterIssuer"]
          }
        ]
      ]"
```
~~In this case, the GVK is cert-manager.io/v1/ClusterIssuer. This means that the ConstraintTemplate requires Gatekeeper to sync the ClusterIssuer resources from the cert-manager.io group and the v1 version. The synced resources can then be accessed in the Rego policies using the data.inventory document.
In our policies case ClusterIssuer can be used accessed and checked the certifcate is allowe to reference it.~~


# Install GK  and Test  

***Note:  is only applicable if you want to test the  data-sync based approach on the OSS project***

 Installing the oss project as its quick to test rego deployments than via azure policy. Testing time with Azure policy is excessive so it quicker to validate rego rules against a local cluster with GK installed  
 ```
 helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
 helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
```

## Configure Sync
This only applies to the annotation based approach 

```
kubectl apply -f setup/config.gk.yaml
```
The provided YAML code  `setup/config.gk.yaml` is a configuration for the Gatekeeper. This configuration is specifically for Gatekeeper's sync functionality, which is used to replicate Kubernetes resources into the policy decision-making process.


In this case, the syncOnly field contains a list with one item, which specifies that only ClusterIssuer resources from the cert-manager.io/v1 API group should be synced. This means that Gatekeeper will only keep track of ClusterIssuer resources for its policy enforcement, ignoring all other types of resources. This is used within the policy to check the ClusterIssuer 

This configuration tells Gatekeeper to monitor ClusterIssuer resources from the cert-manager.io/v1 API group and use them for policy enforcement.

## Deploy the Constraint template and the Constraint with a opensource Gatekeeper V3 
The following deploys the rego rule that enforces which ClusterIssuers can be used 
```
kube apply -f tests/DenyClusterBasedOnAnnotationTemplate.yaml
```
The following deploy the instance of the rule 
```
kube apply -f tests/ConstraintDenyClusterBasedOnAnnotation.yaml
```

##  
This deploys the rego rule which should fail on the check ` issuer != "selfsigned-cluster-issuer"`
* deploy tests/constraintTemplate.yaml 
This deploy an instance of the rego rule 
* deploy tests/constraint.yaml 

### To test deploy a certifcate 
the actual cluster issuer is not required to be deployed 
* deploy setup/selfsigned.clusterissuer.yaml
## check annotation 
    annotation_value := kubernetes.pod_annotations[input.metadata.name][annotation_key]  // Access the annotation value



# Testing policy On  Rego playground

The provided code is a Rego policy for Open Policy Agent (OPA) that enforces certain rules on Kubernetes Certificate resources, specifically those managed by the cert-manager project.
```
        package k8sdenyclusterissuer

        violation[{"msg": msg, "details": {"issuer_name": issuer_name, "allowed_namespaces": allowedNamespaces}}] {
          input.review.kind.kind == "Certificate"
          issuer_name := input.review.object.spec.issuerRef.name
          ns := input.review.object.metadata.namespace

          ci := data.inventory.cluster["cert-manager.io/v1"]["ClusterIssuer"][issuer_name]
          annotations := ci.metadata.annotations
          allowedNamespaces := json.unmarshal(annotations.allowedNamespaces)

          ##not issuer_name != allowedNamespaces[_]
          ## this will be true indicating a violation 
          not contains(allowedNamespaces, ns)

          msg := sprintf("Issuer name %v is not allowed in ClusterIssuer's annotations", [issuer_name])
        }
        # Helper function to check if an array contains a value
        contains(arr, val) {
          arr[_] == val
        }
```
The policy is defined in the denyclusterissuer package. It contains a single rule named violation that generates a violation if certain conditions are met. The violation is returned as a JSON object containing a message and details about the issuer name and allowed namespaces.

The violation rule checks if the kind of the Kubernetes resource in the review object is a "Certificate". If it is, it extracts the issuer name from the spec.issuerRef.name field of the Certificate object and the namespace from the metadata.namespace field.

Next, it retrieves the corresponding ClusterIssuer object from the data.inventory.cluster object using the issuer name. It then extracts the allowedNamespaces annotation from the ClusterIssuer object and unmarshals it into an array.

The rule then checks if the namespace of the Certificate object is not present in the allowedNamespaces array using the contains helper function. If the namespace is not present, it means that the Certificate object is trying to use a ClusterIssuer that it's not allowed to, and a violation is generated.

The violation message indicates that the issuer name is not allowed in the ClusterIssuer's annotations. The details of the violation include the issuer name and the allowed namespaces.

The contains helper function checks if a given value is present in an array. It's used in the violation rule to check if the namespace of the Certificate object is present in the allowedNamespaces array.

The data object represents the current state of the Kubernetes cluster. It includes a ClusterIssuer named "selfsigned-cluster-issuer" with an allowedNamespaces annotation containing the namespaces "default", "argo", and "temp".

The input object, which is not provided in the code, would represent a request to create or update a Certificate resource. It would typically include the kind, metadata, and spec of the Certificate resource.


The policy can be tested using the following input and data for the rego playground. 
## Prohibit Clusterissuers from been used by allowed namespaces 

Copy the following entries () to the rego playground. 
### Viloation example
![ ](/assets/violate.png)
### pass example
![ ](/assets/pass.png)

or see here 
https://play.openpolicyagent.org/p/8wBHHfcG0R


### Rego Rule 
```
package denyclusterissuer

violation[{"msg": msg, "details": {"issuer_name": issuer_name, "allowed_namespaces": allowedNamespaces}}] {
  input.review.kind.kind == "Certificate"
  issuer_name := input.review.object.spec.issuerRef.name
  ns := input.review.object.metadata.namespace

  ci := data.inventory.cluster["cert-manager.io/v1"]["ClusterIssuer"][issuer_name]
  annotations := ci.metadata.annotations
  allowedNamespaces := json.unmarshal(annotations.allowedNamespaces)

  ##not issuer_name != allowedNamespaces[_]
  ## this will be true indicating a violation 
  not contains(allowedNamespaces, ns)

  msg := sprintf("Issuer name %v is not allowed in ClusterIssuer's annotations", [issuer_name])
}
# Helper function to check if an array contains a value
contains(arr, val) {
  arr[_] == val
}

```

### Data 
```
{
  "inventory": {
    "cluster": {
      "cert-manager.io/v1": {
        "ClusterIssuer": {
          "selfsigned-cluster-issuer": {
            "metadata": {
              "annotations": {
                "allowedNamespaces": "[\"default\", \"argo\", \"temp\"]"
              }
            }
          }
        }
      }
    }
  }
}
```
### Input

```
{
  "review": {
    "kind": {
      "kind": "Certificate"
    },
    "object": {
      "metadata": {
        "name": "my-selfsigned-ca",
        "namespace": "default"
      },
      "spec": {
        "issuerRef": {
          "name": "selfsigned-cluster-issuer",
          "kind": "ClusterIssuer",
          "group": "cert-manager.io"
        }
      }
    }
  }
}
```

## notes and Reference 
* https://open-policy-agent.github.io/gatekeeper/website/docs/howto/#input-review
* https://pkg.go.dev/k8s.io/kubernetes/pkg/apis/admission#AdmissionRequest
* By default GK sets the obj AdmissionRevew on the variable 'review' thats passed to the rego rule 

* https://www.danielstechblog.io/evaluating-gatekeeper-policies-with-the-rego-playground/
* https://github.com/Azure/azure-policy/tree/master/samples/KubernetesService
* Rego example https://play.openpolicyagent.org/p/7O2UVOvrbN for checking data repo
* https://github.com/open-policy-agent/gatekeeper-library/blob/master/library/general/poddisruptionbudget/template.yaml
* https://github.com/clarenceb/aks-custom-policy-demo#
* https://github.com/open-policy-agent/gatekeeper-library
# debuging and viewing the admissionReview object
*  enable this policy 😊. This will show the admissionReview objects hitting the GK controller
* * https://open-policy-agent.github.io/gatekeeper/website/docs/debug#viewing-the-request-object
*  View the audit log in AKS. This will show all objects in hitting the api admission controllers. Generates a lot of logs and costs 
