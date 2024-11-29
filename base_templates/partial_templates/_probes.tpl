---
{{- define "probes.get" -}}
          {{- with .Values}}
          readinessProbe: &probe
            httpGet:
              path: /
              port: {{.appPort}}
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
          livenessProbe: *probe
          {{- end}}
{{- end -}}
