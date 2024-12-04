---
{{- define "probes.get" -}}
          {{- with .Values}}
          readinessProbe: &probe
            httpGet:
              path: {{.probePath | default "/"}}
              port: {{.appPort}}
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 10
          livenessProbe: *probe
          {{- end}}
{{- end -}}
