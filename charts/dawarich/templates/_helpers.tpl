{{/*
Expand the name of the chart.
*/}}
{{- define "dawarich.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dawarich.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dawarich.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dawarich.labels" -}}
helm.sh/chart: {{ include "dawarich.chart" . }}
{{ include "dawarich.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dawarich.labelsSidekiq" -}}
helm.sh/chart: {{ include "dawarich.chart" . }}
{{ include "dawarich.selectorLabelsSidekiq" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dawarich.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dawarich.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "dawarich.selectorLabelsSidekiq" -}}
app.kubernetes.io/name: {{ include "dawarich.fullname" . | printf "%s-sidekiq" }}
app.kubernetes.io/instance: {{ .Release.Name | printf "%s-sidekiq" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dawarich.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dawarich.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "dawarich.environmentSetup" -}}
{{- range $key, $value := .environment }}
{{- if $value }}
{{ $key | snakecase | upper | indent 2 }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "dawarich.redisSecretName" -}}
{{- default (printf "%s-redis-secret" (include "dawarich.fullname" .)) .Values.dawarich.redis.existingSecret }}
{{- end }}

{{- define "dawarich.volumes" -}}
{{- if .Values.persistence.public.enabled }}
- name: public
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-public" (include "dawarich.fullname" .)) .Values.persistence.public.existingClaim }}
{{- end }}
{{- if .Values.persistence.watched.enabled }}
- name: watched
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-watched" (include "dawarich.fullname" .)) .Values.persistence.watched.existingClaim }}
{{- else }}
- name: watched
  emptyDir: {}
{{- end }}
{{- if .Values.persistence.storage.enabled }}
- name: storage
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-storage" (include "dawarich.fullname" .)) .Values.persistence.storage.existingClaim }}
{{- end }}
{{- if .Values.dawarich.extraVolumes }}
{{ toYaml .Values.dawarich.extraVolumes | indent 2 }}
{{- end }}
{{- end }}

{{- define "dawarich.volumeMounts" -}}
{{- if .Values.persistence.public.enabled }}
- name: public
  mountPath: /var/app/public
{{- end }}
- name: watched
  mountPath: /var/app/tmp/imports/watched
{{- if .Values.persistence.storage.enabled }}
- name: storage
  mountPath: /var/app/storage
{{- end }}
{{- if .Values.dawarich.extraVolumeMounts }}
{{ toYaml .Values.dawarich.extraVolumeMounts | indent 2 }}
{{- end }}
{{- end }}

{{- define "dawarich.sidekiqVolumeMounts" -}}
{{- if .Values.persistence.public.enabled }}
- name: public
  mountPath: /var/app/public
{{- end }}
{{- if .Values.persistence.watched.enabled }}
- name: watched
  mountPath: /var/app/tmp/imports/watched
{{- end }}
{{- if .Values.persistence.storage.enabled }}
- name: storage
  mountPath: /var/app/storage
{{- end }}
{{- end }}

{{- define "dawarich.envFrom" -}}
- configMapRef:
    name: {{ include "dawarich.fullname" . }}-config
{{- if .Values.existingEnvSecret }}
- secretRef:
    name: {{ .Values.existingEnvSecret }}
{{- end }}
{{- end }}

{{- define "dawarich.env" -}}
{{/* SELF_HOSTED is required in Dawarich >=0.25.4 */}}
- name: SELF_HOSTED
  value: "true"
{{/* STORE_GEODATA was introduced in Dawarich 0.28.0 */}}
- name: STORE_GEODATA
  value: "true"
- name: APPLICATION_HOSTS
  value: {{ join "," .Values.dawarich.hosts }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_HOST" "Key" "postgresHost" "Value" .Values.postgresql.host "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_PORT" "Key" "postgresPort" "Value" .Values.postgresql.port "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_NAME" "Key" "postgresDatabase" "Value" .Values.postgresql.auth.database "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_USERNAME" "Key" "postgresUsername" "Value" .Values.postgresql.auth.username "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_PASSWORD" "Key" "postgresPassword" "Value" .Values.postgresql.auth.password "Root" .) }}
{{- $redisAddr := print (tpl .Values.redis.host .) ":" .Values.redis.port }}
{{- if .Values.redis.auth }}
{{ include "dawarich.secretValueEnvRef" (dict "EnvName" "A_REDIS_PASSWORD" "Key" "redisPassword" "Value" .Values.redis.redisPassword "Root" .) }}
- name: REDIS_URL
  value: {{ print "redis://:$(A_REDIS_PASSWORD)@" $redisAddr | quote }}
{{- else }}
- name: REDIS_URL
  value: {{ print "redis://" $redisAddr | quote }}
{{- end }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "SECRET_KEY_BASE" "Key" "keyBase" "Value" .Values.keyBase "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "PHOTON_API_KEY" "Key" "photonApiKey" "Value" .Values.photonApiKey "Root" .) }}
{{- include "dawarich.secretValueEnvRef" (dict "EnvName" "GEOAPIFY_API_KEY" "Key" "geoapifyApiKey" "Value" .Values.geoapifyApiKey "Root" .) }}
{{- if .Values.oidc.enabled }}
{{ include "dawarich.secretValueEnvRef" (dict "EnvName" "OIDC_CLIENT_ID" "Key" "oidcClientId" "Value" .Values.oidc.clientId "Root" .) }}
{{ include "dawarich.secretValueEnvRef" (dict "EnvName" "OIDC_CLIENT_SECRET" "Key" "oidcClientSecret" "Value" .Values.oidc.clientSecret "Root" .) }}
- name: OIDC_ISSUER
  value: {{ .Values.oidc.issuer | quote }}
- name: OIDC_REDIRECT_URI
  value: {{ .Values.oidc.redirectUri | quote }}
- name: OIDC_AUTO_REGISTER
  value: {{ .Values.oidc.autoRegister | quote }}
- name: OIDC_PROVIDER_NAME
  value: {{ .Values.oidc.providerName | quote }}
- name: ALLOW_EMAIL_PASSWORD_REGISTRATION
  value: {{ .Values.oidc.allowEmailPasswordRegistration | quote }}
{{- end }}

{{- end }}

{{- define "dawarich.initContainers" }}
- name: wait-for-postgres
  image: busybox
  env:
    {{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_HOST" "Key" "postgresHost" "Value" .Values.postgresql.host "Root" .) | nindent 4 }}
    {{- include "dawarich.secretValueEnvRef" (dict "EnvName" "DATABASE_PORT" "Key" "postgresPort" "Value" .Values.postgresql.port "Root" .) | nindent 4 }}
  command: ['sh', '-c', 'until nc -z "$DATABASE_HOST" "$DATABASE_PORT"; do echo waiting for postgres; sleep 2; done;']
{{- end }}


{{- define "dawarich.livenessProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.hosts | first }}
{{- end }}

{{- define "dawarich.readinessProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.hosts | first }}
{{- end }}

{{- define "dawarich.startupProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.hosts | first }}
initialDelaySeconds: 30
periodSeconds: 10
failureThreshold: 10
{{- end }}

{{- define "dawarich.secretValue" }}
{{- if not (kindIs "map" .Value) }}
{{ .Key | quote }}: {{ ternary (tpl (.Value | toString) .Root) (.Value | toString) (not (not .Template)) | b64enc }}
{{- end }}
{{- end }}

{{- define "dawarich.secretValueEnvRef" }}
{{- if .Value }}
- name: {{ .EnvName | quote }}
  valueFrom:
    secretKeyRef:
      {{- if kindIs "map" .Value }}
      name: {{ .Value.name | default (include "dawarich.fullname" .Root) }}
      key: {{ .Value.key | quote }}
      {{- else }}
      name: {{ include "dawarich.fullname" .Root }}
      key: {{ .Key | quote }}
      {{- end }}
{{- end }}
{{- end }}
