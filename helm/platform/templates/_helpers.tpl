# prefix-product returns the namespace/resource prefix for this deployment.
{{- define "prefix-product" -}}
{{- printf "%s-%s" .Values.prefix .Values.product -}}
{{- end -}}

# namespace returns the Kubernetes namespace for this deployment.
# Uses .Values.namespace if set, otherwise falls back to prefix-product.
{{- define "namespace" -}}
{{- .Values.namespace | default (include "prefix-product" .) -}}
{{- end -}}

# labels returns the common labels for all resources.
{{- define "labels" -}}
prefix:  {{ .Values.prefix }}
product: {{ .Values.product }}
colour:   {{ .Values.colour }}
{{- end -}}

# subdomain returns the public subdomain for this product.
{{- define "subdomain" -}}
{{- $product := .Values.product -}}
{{- $domain := .Values.domain -}}
{{- $prefix := .Values.subdomainPrefix | default "" -}}
{{- if eq $product "platform" -}}
{{- if $prefix -}}
{{- printf "%s.platform.%s" $prefix $domain -}}
{{- else -}}
{{- printf "platform.%s" $domain -}}
{{- end -}}
{{- else if eq $product "ppp" -}}
{{- if $prefix -}}
{{- printf "%s.partner-platform.%s" $prefix $domain -}}
{{- else -}}
{{- printf "partner-platform.%s" $domain -}}
{{- end -}}
{{- else -}}
{{- if $prefix -}}
{{- printf "%s.%s.%s" $prefix $product $domain -}}
{{- else -}}
{{- printf "%s.%s" $product $domain -}}
{{- end -}}
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
