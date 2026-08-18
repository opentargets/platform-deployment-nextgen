# helm/platform/templates/_helpers.tpl has an identical define — keep both in sync if either changes.
{{- define "subdomain" -}}
{{- $product := .Values.product -}}
{{- $domain := .Values.domain -}}
{{- if eq $product "platform" -}}
{{- printf "platform.%s" $domain -}}
{{- else if eq $product "ppp" -}}
{{- printf "partner-platform.%s" $domain -}}
{{- else -}}
{{- printf "%s.%s" $product $domain -}}
{{- end -}}
{{- end }}
