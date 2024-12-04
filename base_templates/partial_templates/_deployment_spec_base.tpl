---
{{- define "deployment.spec.base" -}}
{{- with .Values}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{index .containerNames 0}}
spec:
  replicas: {{.replicas | default 1}}
  selector:
    matchLabels:
      app: {{index .containerNames 0}}
  template:
    metadata:
      labels:
        app: {{index .containerNames 0}}
{{- end}}
{{- end -}}
