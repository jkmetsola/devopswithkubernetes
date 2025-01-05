---
{{- define "container.base" -}}
        {{- with .Values}}
        - name: {{index .containerNames 0}}
          image: "{{.imageRegistry}}/{{index .containerNames 0}}:{{.versionTag}}"
          imagePullPolicy: {{.imagePullPolicy}}
          {{- template "resources.constraints" $}}
          {{- template "container.command" $}}
        {{- end}}
{{- end -}}
