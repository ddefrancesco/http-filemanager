# http-filemanager
Ballerina microservice code to upload/download binary files and textual files (plain text,json and xml) plus observability (jaeger, prometheus) and database tracing included. Ready for use with wso2 microgateway.
Also, docker and k8s artifacts, are included.
To run microservice with observability in dev mode:

```
ballerina run upload --b7a.observability.enabled=true
```
Even OAS3 file is provided with WSO2 Microgateway (v. 3.2.0 and later) extensions. 
