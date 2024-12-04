---
{{- define "postgres.env" -}}
          {{- with .Values}}
          envFrom:
            - secretRef:
                name: {{index .databases.postgres.containerNames 0}}
          {{- end}}
{{- end -}}
