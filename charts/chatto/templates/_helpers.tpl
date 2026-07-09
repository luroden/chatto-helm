{{/*
Expand the name of the chart.
*/}}
{{- define "chatto.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "chatto.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "chatto.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "chatto.labels" -}}
helm.sh/chart: {{ include "chatto.chart" . }}
{{ include "chatto.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: chatto
{{- end }}

{{- define "chatto.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chatto.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "chatto.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chatto.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Container image reference, defaulting the tag to the chart appVersion.
*/}}
{{- define "chatto.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
Hostname extracted from chatto.url, e.g. https://chat.example.com:8443 -> chat.example.com.
Empty when chatto.url is unset. Used as the default hostname for the Gateway
listeners, the HTTPRoute, and the cert-manager Certificate.
*/}}
{{- define "chatto.urlHost" -}}
{{- with .Values.chatto.url -}}
{{- first (splitList ":" (urlParse .).host) -}}
{{- end -}}
{{- end }}

{{/*
Hostnames served by the chart's Gateway (and its Certificate). Rendered as a
YAML list; consume with `fromYamlArray`.
*/}}
{{- define "chatto.gatewayHostnames" -}}
{{- $hosts := .Values.gateway.hostnames -}}
{{- if not $hosts -}}
{{- $hosts = compact (list (include "chatto.urlHost" .)) -}}
{{- end -}}
{{- toYaml $hosts -}}
{{- end }}

{{/*
Hostnames matched by the HTTPRoute. Rendered as a YAML list.
*/}}
{{- define "chatto.httpRouteHostnames" -}}
{{- $hosts := .Values.httpRoute.hostnames -}}
{{- if not $hosts -}}
{{- $hosts = compact (list (include "chatto.urlHost" .)) -}}
{{- end -}}
{{- toYaml $hosts -}}
{{- end }}

{{/*
Gateway listener names must be unique per Gateway and RFC 1123 labels, so they
cannot be derived from hostnames (wildcards, dots). One hostname gets the bare
protocol name; several get an index suffix.
Args: dict "prefix" <string> "index" <int> "total" <int>
*/}}
{{- define "chatto.listenerName" -}}
{{- if eq (int .total) 1 -}}
{{- .prefix -}}
{{- else -}}
{{- printf "%s-%d" .prefix (int .index) -}}
{{- end -}}
{{- end }}

{{/*
Secret holding the Gateway's TLS certificate. cert-manager writes it when
gateway.tls.certificate.enabled; otherwise the user provides it.
*/}}
{{- define "chatto.gatewayTlsSecretName" -}}
{{- default (printf "%s-tls" (include "chatto.fullname" .)) .Values.gateway.tls.secretName -}}
{{- end }}

{{/*
Name of the Secret holding the sensitive CHATTO_* config keys.
*/}}
{{- define "chatto.configSecretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "chatto.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
Name of the Secret holding the NATS token / credentials.
Bundled NATS: natsAuth.existingSecret or natsAuth.secretName (referenced
statically by the nats subchart, so it must be a literal).
External NATS: externalNats.auth.existingSecret or <fullname>-nats-auth.
*/}}
{{- define "chatto.natsSecretName" -}}
{{- if .Values.nats.enabled -}}
{{- default .Values.natsAuth.secretName .Values.natsAuth.existingSecret -}}
{{- else -}}
{{- default (printf "%s-nats-auth" (include "chatto.fullname" .)) .Values.externalNats.auth.existingSecret -}}
{{- end -}}
{{- end }}

{{/*
Whether the chart should render/manage the NATS auth Secret itself.
True when using bundled NATS (or external token/userpass/credentials auth)
without a user-provided existingSecret.
*/}}
{{- define "chatto.manageNatsSecret" -}}
{{- if .Values.nats.enabled -}}
{{- if not .Values.natsAuth.existingSecret -}}true{{- end -}}
{{- else -}}
{{- if and (ne .Values.externalNats.auth.method "none") (not .Values.externalNats.auth.existingSecret) -}}true{{- end -}}
{{- end -}}
{{- end }}

{{/*
Computed NATS client URL.
*/}}
{{- define "chatto.natsUrl" -}}
{{- if .Values.nats.enabled -}}
{{- printf "nats://%s:4222" (include "chatto.natsFullname" .) -}}
{{- else -}}
{{- required "externalNats.url is required when nats.enabled=false" .Values.externalNats.url -}}
{{- end -}}
{{- end }}

{{/*
Stream replication factor (CHATTO_NATS_REPLICAS).
Bundled: cluster size when clustered, else 1. External: externalNats.replicas.
*/}}
{{- define "chatto.natsReplicas" -}}
{{- if .Values.nats.enabled -}}
{{- if .Values.nats.config.cluster.enabled -}}
{{- .Values.nats.config.cluster.replicas -}}
{{- else -}}
1
{{- end -}}
{{- else -}}
{{- .Values.externalNats.replicas -}}
{{- end -}}
{{- end }}

{{/*
NATS auth method used by Chatto.
*/}}
{{- define "chatto.natsAuthMethod" -}}
{{- if .Values.nats.enabled -}}token{{- else -}}{{ .Values.externalNats.auth.method }}{{- end -}}
{{- end }}

{{/*
Replicate the nats subchart's fullname so we can build the service DNS name.
*/}}
{{- define "chatto.natsFullname" -}}
{{- if .Values.nats.fullnameOverride -}}
{{- .Values.nats.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "nats" .Values.nats.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}
