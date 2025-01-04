---
{{- define "container.base" -}}
        {{- with .Values}}
        - name: {{index .containerNames 0}}
          image: "{{.imageRegistry}}/{{index .containerNames 0}}:{{.versionTag}}"
          imagePullPolicy: {{.imagePullPolicy}}
          resources: &resource_limits
            limits:
              cpu: "100m"
              memory: "256Mi"
            requests:
              cpu: "15m"
              memory: "128Mi"
          {{- template "container.command" $}}
        {{- end}}
{{- end -}}
