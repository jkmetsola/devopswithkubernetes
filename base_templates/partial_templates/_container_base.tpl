---
{{- define "container.base" -}}
        {{- with .Values}}
        - name: {{index .containerNames 0}}
          image: "{{.imageRegistry}}/{{index .containerNames 0}}:{{.versionTag}}"
          imagePullPolicy: {{.imagePullPolicy}}
          {{- include "resources.constraints" $}}
          {{- include "container.command" $}}
        {{- end}}
{{- end -}}
