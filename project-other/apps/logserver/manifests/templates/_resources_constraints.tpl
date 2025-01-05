---
{{- define "resources.constraints" -}}
        {{- with .Values}}
          resources: &resource_limits
            limits:
              cpu: "50m"
              memory: "128Mi"
            requests:
              cpu: "8m"
              memory: "64Mi"
        {{- end}}
{{- end -}}
