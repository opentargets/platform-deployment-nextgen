# prefix-product returns the namespace/resource prefix for this deployment.
{{- define "prefix-product" -}}
{{- printf "%s-%s" .Values.prefix .Values.product -}}
{{- end -}}

# labels returns the common labels for all resources.
{{- define "labels" -}}
prefix:  {{ .Values.prefix }}
product: {{ .Values.product }}
{{- end -}}

# subdomain returns the public subdomain for this product.
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

# ports and paths
{{- define "ports.dns"                -}}53{{- end -}}
{{- define "ports.apiproxy"           -}}8081{{- end -}}
{{- define "ports.http"               -}}8080{{- end -}}
{{- define "ports.clickhouse"         -}}8123{{- end -}}
{{- define "ports.clickhouse.native"  -}}9000{{- end -}}
{{- define "ports.clickhouse.metrics" -}}9363{{- end -}}
{{- define "ports.opensearch"         -}}9200{{- end -}}
{{- define "ports.opensearch.perf"    -}}9600{{- end -}}

{{- define "paths.health.api"    -}}/health{{- end -}}
{{- define "paths.health.aiapi"  -}}/health{{- end -}}
{{- define "paths.health.webapp" -}}/health{{- end -}}
