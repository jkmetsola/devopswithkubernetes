---
{{- define "volumes.base" -}}
      {{- with .Values}}
      volumes:
        - name: {{.tempStartupScriptVolumeName}}
          configMap:
            name: {{index .containerNames 0}}
            defaultMode: 0755
      {{- end}}
{{- end -}}
