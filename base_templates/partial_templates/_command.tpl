---
{{- define "container.command" -}}
        {{- with .Values}}
          command:
            - "/bin/bash"
            - "-c"
            - "{{.tempScriptVolumeMountPath}}/{{index .containerNames 0}}"
        {{- end}}
{{- end -}}
