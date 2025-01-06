{{- define "init.container.waitdb" -}}
    {{- with .Values}}
      initContainers:
        - name: wait-for-db
          image: alpine:3.21.0
          command:
            - 'sh'
            - '-c'
            - |
              apk add --no-cache iputils
              until ping -c 1 {{.databases.postgres.serviceName}}; do
                echo waiting for {{.databases.postgres.serviceName}}
                sleep 2
              done
          resources:
            limits:
              cpu: "10m"
              memory: "32Mi"
            requests:
              cpu: "5m"
              memory: "16Mi"
          securityContext:
            readOnlyRootFilesystem: true
            runAsUser: 1000
            runAsNonRoot: true
    {{- end}}
{{- end -}}
