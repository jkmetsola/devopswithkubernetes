---
{{- define "resources.constraints" -}}
        {{- with .Values}}
          resources: &resource_limits
            limits:
              cpu: "100m"
              memory: "256Mi"
            requests:
              cpu: "15m"
              memory: "128Mi"
        {{- end}}
{{- end -}}
