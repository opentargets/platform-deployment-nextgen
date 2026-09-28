{{- define "router.namespace" -}}
{{- .Values.namespaceOverride | default (printf "%s-%s-router" .Values.envPrefix .Values.product) -}}
{{- end -}}

{{/* An A record's target: a literal IP (dnsTargetOverride) when adopting a record whose
     live value was patched directly, so it doesn't collide with a mutually-exclusive
     rrdatasRefs already set; otherwise a live reference to the ComputeAddress. Takes a
     dict: Values, computeAddressName, namespace (the ComputeAddress's own namespace). */}}
{{- define "router.dnsTarget" -}}
{{- if .Values.dnsTargetOverride -}}
rrdatas:
  - {{ .Values.dnsTargetOverride }}
{{- else -}}
rrdatasRefs:
  - kind: ComputeAddress
    name: {{ .computeAddressName }}
    namespace: {{ .namespace }}
{{- end -}}
{{- end -}}

{{- define "router.proxyConfig" -}}
events {}
http {
  # Resolve colour Services at request time and refresh cached addresses.
  resolver kube-dns.kube-system.svc.cluster.local valid=10s ipv6=off;
  resolver_timeout 5s;
  geo $real_client_ip $limit {
    default 1;
    {{- range .security.rateLimiterWhitelist }}
    {{ . }} 0;
    {{- end }}
  }
  map $http_x_forwarded_for $real_client_ip {
    ~^(\S+),\s  $1;
    default     $http_x_forwarded_for;
  }
  map $limit $limit_key {
    0 "";
    1 $real_client_ip;
  }
  map $http_x_forwarded_proto $forwarded_proto {
    default $http_x_forwarded_proto;
    "" $scheme;
  }
  limit_req_zone $limit_key zone=api_limit:10m rate=40r/s;
  server {
    listen 8080;
    location = /nginx-health {
      access_log off;
      return 200 "ok\n";
      add_header Content-Type text/plain;
    }
    location / {
      limit_req zone=api_limit burst=80 nodelay;
      limit_req_status 429;
      set $upstream {{ .upstream | quote }};
      proxy_pass http://$upstream;
      {{- if .streaming }}
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_buffering off;
      {{- end }}
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $forwarded_proto;
    }
  }
}
{{- end -}}

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
