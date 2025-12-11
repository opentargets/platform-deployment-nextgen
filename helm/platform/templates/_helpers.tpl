# prefix-product is a helper that returns the prefixes for a whole product.
{{- define "prefix-product" -}}
{{- printf "%s-%s" .Values.prefix .Values.product -}}
{{- end -}}

# labels is a helper that returns the common labels for a whole product.
{{- define "labels" -}}
prefix:  {{ .Values.prefix }}
product: {{ .Values.product }}
{{- end -}}

# env is a helper that returns the environment name based on the color value.
{{- define "env" -}}
{{- if eq .color .root.Values.production -}}
production
{{- else -}}
staging
{{- end -}}
{{- end }}

# deploymentColor determines the color for a service
#
# For production services, it will simply return the color defined in the config.
#
# For staging services:
# - If staging is disabled, it will return the production color.
#     This allows us to tear down staging resources when not needed.
# - If staging is enabled, it will return the color opposite to production.
#
{{- define "deploymentColor" -}}
{{- $deploymentColor := .root.Values.production }}
{{- if and (eq .env "staging") (ne .root.Values.staging "disabled") }}
  {{- if eq $deploymentColor "blue" }}
    {{- $deploymentColor = "green" }}
  {{- else if eq $deploymentColor "green" }}
    {{- $deploymentColor = "blue" }}
  {{- end }}
{{- end }}
{{- $deploymentColor -}}
{{- end }}

# isDeploymentUsed checks if a deployment color is going to be used.
# If staging is disabled, only the production color is used.
# If staging is enabled, both colors are used.
{{- define "isDeploymentUsed" -}}
{{- $color := .color -}}
{{- $root := .root -}}
{{- if eq $root.Values.staging "disabled" -}}
  {{- if eq $color $root.Values.production -}}
    true
  {{- end -}}
{{- else -}}
  true
{{- end -}}
{{- end }}

# subdomain is a helper that returns the subdomain for a whole product.
{{- define "subdomain" -}}
{{- $product := .root.Values.product -}}
{{- $domain := .root.Values.domain -}}
{{- $subdomain := printf "%sz.%s" $product $domain -}}
{{- if eq $product "platform" -}}
{{- $subdomain = printf "platform.%s" $domain -}}
{{- else if eq $product "ppp" -}}
{{- $subdomain = printf "partner-platform.%s" $domain -}}
{{- end -}}
{{- if eq .env "staging" -}}
{{- $subdomain = printf "staging.%s" $subdomain -}}
{{- end -}}
{{- $subdomain -}}
{{- end }}

# ports and paths
{{- define "ports.dns"        -}}53{{- end -}}
{{- define "ports.http"       -}}8080{{- end -}}
{{- define "ports.clickhouse" -}}8123{{- end -}}
{{- define "ports.opensearch" -}}9200{{- end -}}

{{- define "paths.health.api"    -}}/health{{- end -}}
{{- define "paths.health.aiapi"  -}}/health{{- end -}}
{{- define "paths.health.webapp" -}}/health{{- end -}}
