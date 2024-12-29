---
# {{- with .Values}} -- {{- end -}} block will affect how newlines are rendered!
# Don't remove!
{{- define "security.context" -}}
          {{- with .Values}}
          securityContext:
            readOnlyRootFilesystem: true
            privileged: true
            capabilities:
              add:
                - SYS_ADMIN
              drop:
                - NET_RAW
          {{- end}}
{{- end -}}
