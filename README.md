# cert-manager-clusterissuer-policy

# Install azure policy 
To create an Azure Policy with a source type of Base64Encoded, you would first need to decode the base64 content to get the actual policy definition.
```
base64 -i  tests/DenyClusterBasedOnAnnotationTemplate.yaml -o out.base64
```

## Enable Azure Policy
See https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks

## Deploy Policy 
 Thze defintion for azure policy can be found under [here](/azurepolicy/clusterissuer.yaml)
 this definition can be copied and pasted in the the azure policy UI and applied to the target scio 

## ConstraintTemplate For Azure Policy  

The metadata.gatekeeper.sh/requires-sync-data field is a special annotation used by Gatekeeper. This annotation tells Gatekeeper that this ConstraintTemplate requires certain Kubernetes resources to be synced for use in the Rego policies. The value of this field is a JSON-formatted string that specifies the group, version, and kind (GVK) of the resources to be synced.

In this case, the GVK is cert-manager.io/v1/ClusterIssuer. This means that the ConstraintTemplate requires Gatekeeper to sync the ClusterIssuer resources from the cert-manager.io group and the v1 version. The synced resources can then be accessed in the Rego policies using the data.inventory document.
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
In this case, the GVK is cert-manager.io/v1/ClusterIssuer. This means that the ConstraintTemplate requires Gatekeeper to sync the ClusterIssuer resources from the cert-manager.io group and the v1 version. The synced resources can then be accessed in the Rego policies using the data.inventory document.
In our policies case ClusterIssuer can be used accessed and checked the certifcate is allowe to reference it. 


# install GK  and Test  

 installing the oss project as its quick to test rego deployments than via azure policy 
 ```
 helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
 helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
```

## Configure Sync

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
* https://www.danielstechblog.io/evaluating-gatekeeper-policies-with-the-rego-playground/
* https://github.com/Azure/azure-policy/tree/master/samples/KubernetesService
* Rego example https://play.openpolicyagent.org/p/7O2UVOvrbN for checking data repo
* https://github.com/open-policy-agent/gatekeeper-library/blob/master/library/general/poddisruptionbudget/template.yaml
* https://github.com/clarenceb/aks-custom-policy-demo#