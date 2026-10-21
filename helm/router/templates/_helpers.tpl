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
  # Google's load balancer appends "<client-ip>, <lb-ip>" to whatever X-Forwarded-For the
  # client sent, so only the second-to-last entry can be trusted; earlier ones are spoofable.
  map $http_x_forwarded_for $real_client_ip {
    ~([^,\s]+)\s*,\s*[^,\s]+\s*$  $1;
    default     $remote_addr;
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
  {{- if and .userAgentRules .security.blockedUserAgents }}
  # Listed User-Agents (exact string, or ~/~* regex) are refused outright.
  map $http_user_agent $blocked_user_agent {
    default 0;
    {{- range .security.blockedUserAgents }}
    {{ . | quote }} 1;
    {{- end }}
  }
  {{- end }}
  {{- if and .userAgentRules .security.rateLimitedUserAgents }}
  # Each listed User-Agent (exact string, or ~/~* regex) gets its own bucket across all
  # client IPs; unlisted agents get an empty key and are only limited per IP.
  map $http_user_agent $ua_key {
    default "";
    {{- range .security.rateLimitedUserAgents }}
    {{ . | quote }} $http_user_agent;
    {{- end }}
  }
  map $limit $ua_limit_key {
    0 "";
    1 $ua_key;
  }
  limit_req_zone $ua_limit_key zone=ua_limit:10m rate=40r/s;
  {{- end }}
  server {
    listen 8080;
    {{- if and .userAgentRules .security.blockedUserAgents }}
    if ($blocked_user_agent) {
      return 403;
    }
    {{- end }}
    location = /nginx-health {
      access_log off;
      return 200 "ok\n";
      add_header Content-Type text/plain;
    }
    location / {
      limit_req zone=api_limit burst=80 nodelay;
      {{- if and .userAgentRules .security.rateLimitedUserAgents }}
      limit_req zone=ua_limit burst=80 nodelay;
      {{- end }}
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
