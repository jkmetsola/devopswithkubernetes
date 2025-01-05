README.md

# Devops with Kubernetes project

- Whitelisted files when searching for similarity patterns: .devcontainer/git-hooks/whitelist.json

# DBaaS vs DIY

Comparison between database as a service and do it yourself database.
In calculations it is assumed that we can manage with following specs

    cpu: "100m"
    memory: "256Mi"

    --> i.e. ~ 0.1 vCPU + 0.25 GB

- Let's assume that 0.5GB of storage is needed. We are fine with HDD speed.
- It is assumed that we are going to have the Kubernetes cluster anyway. So let's consider costs only for the DB.
- Database will be accessed only within cloud service. So there will be no network costs.

| Destination                          | Price                        |
|------------------------------------  |------------------------      |
| Compute Engine instances             | Within the same region: free |

Table from: [dbaas-mysql-pg-pricing]

## DBaas pricing

| Resource  | Price (USD)/month  |
|-----------|-------------------:|
| vCPUs     | $33.142 per vCPU   |
| Memory    | $5.621 per GB      |
| HA vCPUs  | $66.357 per vCPU   |
| HA Memory | $11.242 per GB     |

Table from: [dbaas-mysql-pg-pricing]

| Storage Type             | Price / month  |
|--------------------------|---------------:|
| SSD storage capacity     | $0.187         |
| HDD storage capacity     | $0.099         |
| Backups (used)           | $0.088         |

Table from: [dbaas-storage-networking-prices]

### Total Cost Summary

| Resource       | Amount    | Cost per month (USD)  |
|----------------|-----------|----------------------:|
| CPU            | 0.1 vCPU  | 3.3142                |
| Memory         | 0.25 GB   | 1.4025                |
| Storage (HDD)  | 0.5 GB    | 0.0495                |
| Backup         | 0.5 GB    | 0.044                 |
| **Total**      |           | **4.81**              |


## DIY DB pricing

General-purpose costs (default) Pods (europenorth1) / month

| Item                                           | Regular Price  |
|-------------------------------------------     |--------------: |
| GKE Autopilot vCPU Price (vCPU)                | $35.77         |
| GKE Autopilot Pod Memory Price (GB)            | $3.956746      |
| GKE Autopilot Ephemeral SSD Storage Price (GB) | $0.111617      |

Table from: [gke-pricing]

Storage used with databases is persistent (not Ephemeral), but let's assume it is
0.15$/month/GB as I could not find the exact pricing.

### Total Cost Summary

| Resource       | Amount                | Cost per month (USD)  |
|----------------|-----------------------|----------------------:|
| CPU            | 0.1 vCPU              | 3.577                 |
| Memory         | 0.25 GB               | 0.9891865             |
| Storage (HDD)  | 0.5 GB                | 0.075                 |
| Backup         | 0.5 GB                | 0.075                 |
| **Total**      |                       | **4.7161865**         |

[dbaas-mysql-pg-pricing]: https://cloud.google.com/sql/pricing/#mysql-pg-pricing

[dbaas-storage-networking-prices]: https://cloud.google.com/sql/pricing/#storage-networking-prices

[gke-pricing]: https://cloud.google.com/kubernetes-engine/pricing#google-kubernetes-engine-pricing

## Conclusions / Comparison

- DBaaS
    - Pros
        - Known costs
        - Lower maintenance effort
        - Lower security risks (thanks to good maintenance)
        - Definitely Go-To option if there is no existing Kubernetes cluster
    - Cons
        - Costs more if there's e.g. high memory consumption for the DB
        - No possibility to customize the deployment (which on the other hand might be just a good thing)
- DIY
    - Pros
        - Full control of the database deployment & maintenance
        - Costs can be lower if done right
    - Cons
        - Relatively high deployment & maintenance effort needed compared to DBaaS
        - Higher security risks when maintained poorly
        - Costs are significantly higher if there is not existing Kubernetes
        cluster available (that is needed anyway.)
        - Real costs (including maintenance) can be difficult to estimate

# Horizontal Pod Autoscaling (HPA)

Example command where logserver automatic scaling is tested.

    tools/testing-scripts/test-sending-many-requests.sh \
        logserver \
        project-other-dev-jmetsola

This can be used to test scenarios where lot of requests are coming that needs
to be served. This tool can help to determine the resources for the pod so that
horizontal pod autoscaling is triggered.
