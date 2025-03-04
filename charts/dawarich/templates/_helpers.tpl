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

{{- define "dawarich.postgresSecretName" -}}
{{- default (printf "%s-postgres-secret" (include "dawarich.fullname" .)) .Values.dawarich.postgres.existingSecret }}
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
{{- end }}

{{- define "dawarich.envFrom" -}}
- configMapRef:
    name: {{ include "dawarich.fullname" . }}-config
{{- end }}

{{- define "dawarich.env" -}}
- name: APPLICATION_HOSTS
  value: {{ .Values.dawarich.host }}
{{- with .Values.postgresql }}
- name: DATABASE_HOST
  value: "{{ if .enabled }}{{ $.Release.Name }}-postgresql{{ else }}{{ .externalHost }}{{ end }}"
- name: DATABASE_PORT
  value: "{{ if .enabled }}5432{{ else }}{{ .externalPort }}{{ end }}"
- name: DATABASE_NAME
  value: {{ .auth.database }}
- name: DATABASE_USERNAME
  value: {{ default "postgres" .auth.username }}
- name: DATABASE_PASSWORD
  {{- if .auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: password
      {{- else }}
      name: {{ $.Release.Name }}-postgresql
      key: password
      {{- end }}
  {{- else }}
  value: {{ .auth.password }}
  {{- end }}
{{- end }}
{{- with .Values.redis }}
- name: A_REDIS_PASSWORD
  {{- if .auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: redis-password
      {{- else }}
      name: {{ $.Release.Name }}-postgresql
      key: redis-password
      {{- end }}
  {{- else }}
  value: {{ .auth.password }}
  {{- end }}
- name: REDIS_URL
  value: redis://{{- if .auth.enabled }}:$(A_REDIS_PASSWORD)@{{- end }}{{ if .enabled }}{{ $.Release.Name }}-redis-master{{ else }}{{ .externalHost }}{{ end }}:{{ if .enabled }}6379{{ else }}{{ .externalPort }}{{ end }}
{{- end }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      {{- if .Values.keyBase.existingSecret }}
      name: {{ .Values.keyBase.existingSecret }}
      {{- else }}
      name: {{ include "dawarich.fullname" . }}-secret-keybase
      {{- end }}
      key: value
{{- end }}

{{- define "dawarich.initContainers" }}
- name: wait-for-postgres
  image: busybox
  env:
    - name: DATABASE_HOST
      value: "{{ if .Values.postgresql.enabled }}{{ $.Release.Name }}-postgresql{{ else }}{{ .Values.postgresql.externalHost }}{{ end }}"
    - name: DATABASE_PORT
      value: "{{ if .Values.postgresql.enabled }}5432{{ else }}{{ .Values.postgresql.externalPort }}{{ end }}"
  command: ['sh', '-c', 'until nc -z "$DATABASE_HOST" "$DATABASE_PORT"; do echo waiting for postgres; sleep 2; done;']
- name: wait-for-redis
  image: busybox
  env:
    - name: REDIS_HOST
      value: "{{ if .Values.redis.enabled }}{{ $.Release.Name }}-redis-master{{ else }}{{ .Values.redis.externalHost }}{{ end }}"
    - name: REDIS_PORT
      value: "{{ if .Values.redis.enabled }}6379{{ else }}{{ .Values.redis.externalPort }}{{ end }}"
  command: ['sh', '-c', 'until nc -z "$REDIS_HOST" "$REDIS_PORT"; do echo waiting for redis; sleep 2; done;']
{{- end }}


{{- define "dawarich.livenessProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.host }}
{{- end }}

{{- define "dawarich.readinessProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.host }}
{{- end }}

{{- define "dawarich.startupProbe" }}
httpGet:
  path: /api/v1/health
  port: http
  httpHeaders:
    - name: Host
      value: {{ .Values.dawarich.host }}
initialDelaySeconds: 30
periodSeconds: 10
failureThreshold: 10
{{- end }}