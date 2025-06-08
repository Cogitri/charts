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
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dawarich.labelsSidekiq" -}}
helm.sh/chart: {{ include "dawarich.chart" . }}
{{ include "dawarich.selectorLabelsSidekiq" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
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
{{- if .Values.persistence.storage.enabled }}
- name: storage
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-storage" (include "dawarich.fullname" .)) .Values.persistence.storage.existingClaim }}
{{- end }}
{{- if .Values.persistence.solid.enabled }}
- name: solid
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-solid" (include "dawarich.fullname" .)) .Values.persistence.solid.existingClaim }}
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
{{- if .Values.persistence.solid.enabled }}
- name: storage
  mountPath: /var/app/solid
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
{{- end }}

{{- define "dawarich.env" -}}
{{/* SELF_HOSTED is required in Dawarich >=0.25.4 */}}
- name: SELF_HOSTED
  value: "true"
- name: APPLICATION_HOSTS
  value: {{ join "," .Values.dawarich.hosts }}
{{- with .Values.postgresql }}
- name: DATABASE_HOST
  value: "{{ tpl $.Values.postgresql.host $ }}"
- name: DATABASE_PORT
  value: "{{ .port }}"
- name: DATABASE_NAME
  value: "{{ .auth.database }}"
- name: QUEUE_DATABASE_NAME
  value: "{{ .auth.database }}_queue"
- name: DATABASE_USERNAME
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: username
      {{- else }}
      name: {{ include "dawarich.fullname" $ }}
      key: postgresUsername
      {{- end }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .auth.existingSecret }}
      name: {{ .auth.existingSecret }}
      key: password
      {{- else if not .enabled }}
      name: {{ include "dawarich.fullname" $ }}
      key: postgresPassword
      {{- else }}
      name: {{ $.Release.Name }}-postgresql
      key: password
      {{- end }}
{{- end }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      {{- if .Values.keyBase.existingSecret }}
      name: {{ .Values.keyBase.existingSecret }}
      key: value
      {{- else }}
      name: {{ include "dawarich.fullname" . }}
      key: keyBase
      {{- end }}
{{- end }}

{{- define "dawarich.initContainers" }}
- name: wait-for-postgres
  image: busybox
  env:
    - name: DATABASE_HOST
      value: "{{ tpl .Values.postgresql.host . }}"
    - name: DATABASE_PORT
      value: "{{ .Values.postgresql.port }}"
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
