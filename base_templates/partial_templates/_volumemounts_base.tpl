---
{{- define "volumemounts.base" -}}
          {{- with .Values}}
          volumeMounts:
            - name: {{.tempStartupScriptVolumeName}}
              mountPath: {{.tempScriptVolumeMountPath}}
              readOnly: true
          {{- end}}
{{- end -}}
