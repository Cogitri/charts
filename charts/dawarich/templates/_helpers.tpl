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
{{- if .Values.persistence.gemCache.enabled }}
- name: gem-cache
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-gem-cache" (include "dawarich.fullname" .)) .Values.persistence.gemCache.existingClaim }}
{{- end }}
{{- if .Values.persistence.public.enabled }}
- name: public
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-public" (include "dawarich.fullname" .)) .Values.persistence.public.existingClaim }}
{{- end }}
{{- if .Values.persistence.watched.enabled }}
- name: watched
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-watched" (include "dawarich.fullname" .)) .Values.persistence.watched.existingClaim }}
{{- end }}
{{- if .Values.dawarich.extraVolumes }}
{{ toYaml .Values.dawarich.extraVolumes | indent 2 }}
{{- end }}
{{- end }}

{{- define "dawarich.volumeMounts" -}}
{{- if .Values.persistence.gemCache.enabled }}
- name: gem-cache
  mountPath: /usr/local/bundle/gems
{{- end }}
{{- if .Values.persistence.public.enabled }}
- name: public
  mountPath: /var/app/public
{{- end }}
{{- if .Values.persistence.watched.enabled }}
- name: watched
  mountPath: /var/app/tmp/imports/watched
{{- end }}
{{- if .Values.dawarich.extraVolumeMounts }}
{{ toYaml .Values.dawarich.extraVolumeMounts | indent 2 }}
{{- end }}
{{- end }}

{{- define "dawarich.sidekiqVolumeMounts" -}}
{{- if .Values.persistence.gemCache.enabled }}
- name: gem-cache
  mountPath: /usr/local/bundle/gems
  readonly: true
{{- end }}
{{- if .Values.persistence.public.enabled }}
- name: public
  mountPath: /var/app/public
  readonly: true
{{- end }}
{{- if .Values.persistence.watched.enabled }}
- name: watched
  mountPath: /var/app/tmp/imports/watched
  readonly: true
{{- end }}
{{- end }}

{{- define "dawarich.envFrom" -}}
- configMapRef:
    name: {{ include "dawarich.fullname" . }}-config
{{- end }}

{{- define "dawarich.env" -}}
{{- with .Values.postgresql }}
- name: DATABASE_HOST
  value: {{ $.Release.Name }}-postgresql
- name: DATABASE_NAME
  value: {{ .auth.database }}
- name: DATABASE_USERNAME
  value: {{ default "postgres" .auth.username }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: password
      {{- else }}
      name: {{ $.Release.Name }}-postgresql
      key: {{ if not .auth.password }}postgres-{{ end }}password
      {{- end }}
{{- end }}
{{- with .Values.redis }}
- name: A_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: redis-password
      {{- else }}
      name: {{ $.Release.Name }}-redis
      key: redis-password
      {{- end }}
- name: REDIS_URL
  value: redis://{{ .auth.username }}:$(A_REDIS_PASSWORD)@{{ $.Release.Name }}-redis-master
{{- end }}
{{- end }}

{{- define "dawarich.initContainers" }}
- name: wait-for-postgres
  image: busybox
  command: ['sh', '-c', 'until nc -z {{ printf "%s-postgresql" .Release.Name }} 5432; do echo waiting for postgres; sleep 2; done;']
- name: wait-for-redis
  image: busybox
  command: ['sh', '-c', 'until nc -z {{ printf "%s-redis-master" .Release.Name }} 6379; do echo waiting for redis; sleep 2; done;']
{{- end }}
