---
# {{- with .Values}} -- {{- end -}} block will affect how newlines are rendered!
# Don't remove!
{{- define "security.context" -}}
          {{- with .Values}}
          securityContext:
            readOnlyRootFilesystem: true
            runAsUser: 1000
            runAsNonRoot: true
          {{- end}}
{{- end -}}
