# AAP Must Gather

This is a must-gather plugin for Ansible Automation Platform, used with `oc adm must-gather`.

## Purpose

The purpose of this plugin is to gather debugging 

## Usage

### Build Image

```
podman build -f Dockerfile --tag quay.io/<username>/aap-must-gather:latest .
podman push quay.io/<username>/aap-must-gather:latest
```

### Run Must Gather

To use this must-gather for Ansible Automation Platform please use the following command:

```
oc adm must-gather --image=quay.io/<username>/aap-must-gather:latest
```

By default, this collects resources for all AAP components including AutomationOrchestrator
across all namespaces. You can restrict collection using flags:

| Flag | Effect |
|---|---|
| `--aap-only` | Collect AAP resources only (no AutomationOrchestrator) |
| `--ao-only` | Collect AutomationOrchestrator resources only |
| `-n <namespace>` | Collect resources from a single namespace |

Examples:

```
# Collect only AutomationOrchestrator resources
oc adm must-gather --image=quay.io/<username>/aap-must-gather:latest -- /usr/bin/gather --ao-only

# Collect only AAP resources in a specific namespace
oc adm must-gather --image=quay.io/<username>/aap-must-gather:latest -- /usr/bin/gather --aap-only -n my-namespace
```

This will create a new directory with the data collected in it, as well as an `event-filter.html` file,
which can be opened in the browser to inspect the event data collected.

## Testing

Run the end-to-end tests against a local kind cluster:

```
./tests/test_e2e.sh
```

This creates a temporary kind cluster, builds and loads the image, runs all
gather variants, and validates that each script collects the expected CRDs.
The cluster is automatically deleted on exit.

Requires: `podman`, `kind`, `oc`.

```
$ tree
.
├── collection-scripts
│   └── gather
├── Dockerfile
├── must-gather.local.5507664261615403644
│   ├── event-filter.html
│   ├── quay-io-chadams-aap-must-gather-sha256-25ac61fdb2210cf61b5cb7ce165c42be1512db9004cf8d1b7cd050837b98ae4a
│   │   ├── event-filter.html
│   │   └── timestamp
│   └── timestamp
└── README.md
```
