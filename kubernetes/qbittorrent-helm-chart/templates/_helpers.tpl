{{/*
Expand the helper functions for the qBittorrent Helm chart
*/}}

{{- define "qbittorrent.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "qbittorrent.serviceName" -}}
{{- printf "%s-service" (include "qbittorrent.fullname" .) -}}
{{- end -}}

{{- define "qbittorrent.deploymentName" -}}
{{- printf "%s-deployment" (include "qbittorrent.fullname" .) -}}
{{- end -}}

{{- define "qbittorrent.configMapName" -}}
{{- printf "%s-config" (include "qbittorrent.fullname" .) -}}
{{- end -}}