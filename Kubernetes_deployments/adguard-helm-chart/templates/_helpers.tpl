{{/*
Expand the name of the release
*/}}
{{- define "adguard.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels for all resources
*/}}
{{- define "adguard.labels" -}}
app: {{ include "adguard.fullname" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
{{- end -}}

{{/*
Generate a name for the PVC
*/}}
{{- define "adguard.pvcName" -}}
{{ printf "%s-pvc" (include "adguard.fullname" .) }}
{{- end -}}

{{/*
Generate a name for the service
*/}}
{{- define "adguard.serviceName" -}}
{{ printf "%s-service" (include "adguard.fullname" .) }}
{{- end -}}

{{/*
Generate a name for the ingress
*/}}
{{- define "adguard.ingressName" -}}
{{ printf "%s-ingress" (include "adguard.fullname" .) }}
{{- end -}}