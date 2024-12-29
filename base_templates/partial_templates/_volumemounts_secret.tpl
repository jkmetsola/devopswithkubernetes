---
{{- define "volumemounts.secret" -}}
          {{- with .Values}}
            - name: secret-volume
              mountPath: /etc/secrets
              readOnly: true
          {{- end}}
{{- end -}}
