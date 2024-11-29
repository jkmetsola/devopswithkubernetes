---
{{- define "container.base" -}}
        {{- with .Values}}
        - name: {{index .containerNames 0}}
          image: "{{.imageRegistry}}/{{index .containerNames 0}}:{{.versionTag}}"
          imagePullPolicy: {{.imagePullPolicy}}
          resources: &resource_limits
            limits:
              cpu: "1"
              memory: "512Mi"
            requests:
              cpu: "100m"
              memory: "256Mi"
          {{- template "container.command" $}}
        {{- end}}
{{- end -}}
