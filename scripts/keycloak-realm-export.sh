#!/bin/bash
POD="$(kubectl get pods -n keycloak --no-headers -l app.kubernetes.io/name=keycloak| head -n1 | awk '{print $1}')"
if [ -n $POD ]; then 
    kubectl exec -n keycloak $POD -- bash -c "kc.sh export --file /tmp/crucible-realm.json --realm crucible --users realm_file"
    kubectl cp -n keycloak $POD:/tmp/crucible-realm.json ./crucible-realm.json
else
    echo "Keycloak Pod not found in 'keycloak' namespace"
fi
