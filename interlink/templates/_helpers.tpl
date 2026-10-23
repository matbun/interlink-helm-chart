{{/*
Expand the name of the chart.
*/}}
{{- define "interlink.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "interlink.fullname" -}}
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
{{- define "interlink.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "interlink.labels" -}}
helm.sh/chart: {{ include "interlink.chart" . }}
{{ include "interlink.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "interlink.selectorLabels" -}}
app.kubernetes.io/name: {{ include "interlink.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "interlink.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "interlink.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Render container resource requests and limits from the CPU/memory sub-key format:
  resources:
    CPU:
      request: "100m"
      limit: "500m"
    memory:
      request: "128Mi"
      limit: "512Mi"
*/}}
{{- define "interlink.containerResources" -}}
{{- $cpu := .CPU -}}
{{- $mem := .memory -}}
{{- if or $cpu $mem -}}
resources:
  {{- if or (and $cpu $cpu.request) (and $mem $mem.request) }}
  requests:
    {{- if and $cpu $cpu.request }}
    cpu: {{ $cpu.request | quote }}
    {{- end }}
    {{- if and $mem $mem.request }}
    memory: {{ $mem.request | quote }}
    {{- end }}
  {{- end }}
  {{- if or (and $cpu $cpu.limit) (and $mem $mem.limit) }}
  limits:
    {{- if and $cpu $cpu.limit }}
    cpu: {{ $cpu.limit | quote }}
    {{- end }}
    {{- if and $mem $mem.limit }}
    memory: {{ $mem.limit | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Whether the wstunnel shadow template ConfigMap should be rendered and mounted.

The virtual kubelet prefers a template file over its built-in ones, so mounting the
wstunnel template while shadowMode is "ssh" would silently override the SSH shadow.
An explicit customTemplate is always honoured, whichever mode is in use.
*/}}
{{- define "interlink.useWstunnelTemplateFile" -}}
{{- if .Values.virtualNode.network.enableTunnel -}}
{{- if or .Values.virtualNode.network.customTemplate (ne (.Values.virtualNode.network.shadowMode | default "") "ssh") -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Rules for the namespaced objects the virtual kubelet handles: offloaded pods, their
shadows, and the Secrets and ConfigMaps they mount. Granted cluster-wide, or only in
virtualNode.tenantNamespace when the virtual node is confined to one namespace.
*/}}
{{- define "interlink.namespacedRules" -}}
- apiGroups:
    - "apps"
  resources:
    - replicasets
    - deployments
  verbs:
    - create
    - delete
    - list
    - get
    - update
    - patch
- apiGroups:
    - "networking.k8s.io"
  resources:
    - ingresses
  verbs:
    - update
    - create
    - get
    - list
    - watch
    - patch
    - delete
- apiGroups:
    - ""
  resources:
    - configmaps
  verbs:
    - get
    - list
    - watch
    - create
    - update
    - patch
    - delete
- apiGroups:
    - ""
  resources:
    - secrets
  verbs:
    - get
    - list
    - watch
    - delete
    {{- if and (eq ($.Values.virtualNode.network.shadowMode | default "") "ssh") (ne (toString $.Values.virtualNode.network.ssh.replicateCredentials) "false") }}
    # Copying the SSH credential into each shadow's namespace needs write access.
    # Only granted when that is switched on: it is cluster-wide.
    - create
    - update
    - patch
    {{- end }}
- apiGroups:
    - ""
  resources:
    - services
    - serviceaccounts
    - namespaces
  verbs:
    - get
    - list
    - watch
# For https://kubernetes.io/docs/reference/kubernetes-api/
# authentication-resources/token-request-v1/
- apiGroups: [""]
  resources: ["serviceaccounts/token", "namespaces"]
  verbs:
    - create
    - get
    - list
- apiGroups:
    - ""
  resources:
    - pods
    - services
  verbs:
    - update
    - create
    - get
    - list
    - watch
    - patch
    - delete
- apiGroups:
    - ""
  resources:
    - pods/status
  verbs:
    - update
    - patch
# logs of the containers a pod keeps on the cluster come from its shadow
- apiGroups:
    - ""
  resources:
    - pods/log
  verbs:
    - get
{{- end }}
