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
app.kubernetes.io/name: {{ include "dawarich.name" . }}
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

{{- define "dawarich.postgresSecretName" -}}
{{- default (printf "%s-postgres-secret" (include "dawarich.fullname" .)) .Values.dawarich.postgres.existingSecret }}
{{- end }}

{{- define "dawarich.volumes" -}}
- name: gem-cache
  persistentVolumeClaim:
    claimName: {{ include "dawarich.fullname" . }}-gem-cache
- name: public
  persistentVolumeClaim:
    claimName: {{ include "dawarich.fullname" . }}-public
- name: watched
  persistentVolumeClaim:
    claimName: {{ include "dawarich.fullname" . }}-watched
{{- if .Values.dawarich.extraVolumes }}
{{ toYaml .Values.dawarich.extraVolumes }}
{{- end }}
{{- end }}

{{- define "dawarich.volumeMounts" -}}
- name: gem-cache
  mountPath: /usr/local/bundle/gems
- name: public
  mountPath: /var/app/public
- name: watched
  mountPath: /var/app/tmp/imports/watched
{{- if .Values.dawarich.extraVolumeMounts }}
{{ toYaml .Values.dawarich.extraVolumeMounts }}
{{- end }}
{{- end }}

{{- define "dawarich.sidekiqVolumeMounts" -}}
- name: gem-cache
  mountPath: /usr/local/bundle/gems
  readonly: true
- name: public
  mountPath: /var/app/public
  readonly: true
- name: watched
  mountPath: /var/app/tmp/imports/watched
  readonly: true
{{- end }}

{{- define "dawarich.envFrom" -}}
- configMapRef:
    name: {{ include "dawarich.fullname" . }}-config
- secretRef:
    name: {{ include "dawarich.postgresSecretName" . }}
- secretRef:
    name: {{ include "dawarich.redisSecretName" . }}
{{- end }}
