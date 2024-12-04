{{- define "ingress.path" }}
          - path: /{{index .containerNames 0}}
            pathType: Prefix
            backend:
              service:
                name: {{.serviceName}}
                port:
                  number: {{.clusterPort}}
{{- end }}
