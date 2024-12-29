---
{{- define "volumes.secret" -}}
      {{- with .Values}}
        - name: secret-volume
          secret:
            secretName: {{index .containerNames 0}}
      {{- end}}
{{- end -}}
