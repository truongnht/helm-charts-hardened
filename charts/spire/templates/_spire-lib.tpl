{{- define "spire-lib.cluster-name" }}
{{- if ne (len (dig "spire" "clusterName" "" .Values.global)) 0 }}
{{- .Values.global.spire.clusterName }}
{{- else }}
{{- .Values.clusterName }}
{{- end }}
{{- end }}

{{- define "spire-lib.trust-domain" }}
{{- if ne (len (dig "spire" "trustDomain" "" .Values.global)) 0 }}
{{- .Values.global.spire.trustDomain }}
{{- else }}
{{- .Values.trustDomain }}
{{- end }}
{{- end }}

{{- define "spire-lib.jwt-issuer" }}
{{- if ne (len (dig "spire" "jwtIssuer" "" .Values.global)) 0 }}
{{- .Values.global.spire.jwtIssuer }}
{{- else }}
{{- .Values.jwtIssuer }}
{{- end }}
{{- end }}

{{- define "spire-lib.bundle-configmap" }}
{{- if ne (len (dig "spire" "bundleConfigMap" "" .Values.global)) 0 }}
{{- .Values.global.spire.bundleConfigMap }}
{{- else }}
{{- .Values.bundleConfigMap }}
{{- end }}
{{- end }}

{{- define "spire-lib.cluster-domain" -}}
{{- if ne (len (dig "k8s" "clusterDomain" "" .Values.global)) 0 }}
{{- .Values.global.k8s.clusterDomain }}
{{- else }}
{{- .Values.clusterDomain }}
{{- end }}
{{- end }}

{{- define "spire-lib.registry" }}
{{- if ne (len (dig "spire" "image" "registry" "" .global)) 0 }}
{{- print .global.spire.image.registry "/"}}
{{- else if ne (len (.image.registry)) 0 }}
{{- print .image.registry "/"}}
{{- end }}
{{- end }}

{{- define "spire-lib.image" -}}
{{- $registry := include "spire-lib.registry" . }}
{{- $repo := .image.repository }}
{{- $tag := (default .image.tag .image.version) | toString }}
{{- if eq (substr 0 7 $tag) "sha256:" }}
{{- printf "%s/%s@%s" $registry $repo $tag }}
{{- else if .appVersion }}
{{- printf "%s%s:%s" $registry $repo (default .appVersion $tag) }}
{{- else if $tag }}
{{- printf "%s%s:%s" $registry $repo $tag }}
{{- else }}
{{- printf "%s%s" $registry $repo }}
{{- end }}
{{- end }}

{{/* Takes in a dictionary with keys:
 * global - the standard global object
 * ingress - a standard format ingress config object
*/}}
{{- define "spire-lib.ingress-controller-type" }}
{{-   $type := "" }}
{{-   if ne (len (dig "spire" "ingressControllerType" "" .global)) 0 }}
{{-     $type = .global.spire.ingressControllerType }}
{{-   else if ne .ingress.controllerType "" }}
{{-     $type = .ingress.controllerType }}
{{-   else }}
{{-     $type = "other" }}
{{-   end }}
{{-   if not (has $type (list "other" "ingress-nginx")) }}
{{-     fail "Unsupported ingress controller type specified. Must be one of [other, ingress-nginx]" }}
{{-   end }}
{{-   $type }}
{{- end }}

{{/* Takes in a dictionary with keys:
 * ingress - the standardized ingress object
 * svcName - The service to route to
 * port - which port on the service to use
*/}}
{{ define "spire-lib.ingress-spec" }}
{{- $svcName := .svcName }}
{{- $port := .port }}
{{- with .ingress.className }}
ingressClassName: {{ . | quote }}
{{- end }}
{{- if .ingress.tls }}
tls:
  {{- range .ingress.tls }}
  - hosts:
      {{- range .hosts }}
      - {{ . | quote }}
      {{- end }}
    secretName: {{ .secretName | quote }}
  {{- end }}
{{- end }}
rules:
  {{- range .ingress.hosts }}
  - host: {{ .host | quote }}
    http:
      paths:
        {{- range .paths }}
        - path: {{ .path }}
          pathType: {{ .pathType }}
          backend:
            service:
              name: {{ $svcName | quote }}
              port:
                number: {{ $port }}
        {{- end }}
  {{- end }}
{{- end }}

{{- define "spire-lib.kubectl-image" }}
{{- $root := deepCopy . }}
{{- $tag := (default $root.image.tag $root.image.version) | toString }}
{{- if eq (len $tag) 0 }}
{{- $_ := set $root.image "tag" (regexReplaceAll "^(v?\\d+\\.\\d+\\.\\d+).*" $root.KubeVersion "${1}") }}
{{- end }}
{{- include "spire-lib.image" $root }}
{{- end }}

{{/*
Take in an array of, '.', a failure string to display, and boolean to to display it,
if strictMode is enabled and the boolean is true
*/}}
{{- define "spire-lib.check-strict-mode" }}
{{ $root := index . 0 }}
{{ $message := index . 1 }}
{{ $condition := index . 2 }}
{{- if (dig "spire" "strictMode" false $root.Values.global) }}
{{- if $condition }}
{{- fail $message }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Take a copy of the config and merge in .Values.customPlugins and .Values.unsupportedBuiltInPlugins passed through as root.
*/}}
{{- define "spire-lib.config_merge" }}
{{- $pluginsToMerge := dict "plugins" dict }}
{{- range $type, $val := .root.Values.customPlugins }}
{{-   if . }}
{{-     if eq $type "svidstore" }}
{{-       $_ := set $pluginsToMerge.plugins "SVIDStore" (deepCopy $val) }}
{{-     else }}
{{-       $nt := printf "%s%s" (substr 0 1 $type | upper) (substr 1 -1 $type) }}
{{-       $_ := set $pluginsToMerge.plugins $nt (deepCopy $val) }}
{{-     end }}
{{-   end }}
{{- end }}
{{- range $type, $val := .root.Values.unsupportedBuiltInPlugins }}
{{-   if . }}
{{-     if eq $type "svidstore" }}
{{-       $_ := set $pluginsToMerge.plugins "SVIDStore" (deepCopy $val) }}
{{-     else }}
{{-       $nt := printf "%s%s" (substr 0 1 $type | upper) (substr 1 -1 $type) }}
{{-       $_ := set $pluginsToMerge.plugins $nt (deepCopy $val) }}
{{-     end }}
{{-   end }}
{{- end }}
{{- $newConfig := .config | fromYaml | mustMerge $pluginsToMerge }}
{{- $newConfig | toYaml }}
{{- end }}

{{/*
Take a copy of the plugin section and return a yaml string based version
reformatted from a dict of dicts to a dict of lists of dicts
*/}}
{{- define "spire-lib.plugins_reformat" }}
{{- range $type, $v := . }}
{{ $type }}:
{{-   range $name, $v2 := $v }}
    - {{ $name }}: {{ $v2 | toYaml | nindent 8 }}
{{-   end }}
{{- end }}
{{- end }}

{{/*
Take a copy of the config as a yaml config and root var.
Merge in .root.Values.customPlugins and .Values.unsupportedBuiltInPlugins into config,
Reformat the plugin section from a dict of dicts to a dict of lists of dicts,
and export it back as as json string.
This makes it much easier for users to merge in plugin configs, as dicts are easier
to merge in values, but spire needs arrays.
*/}}
{{- define "spire-lib.reformat-and-yaml2json" -}}
{{- $config := include "spire-lib.config_merge" . | fromYaml }}
{{- $plugins := include "spire-lib.plugins_reformat" $config.plugins | fromYaml }}
{{- $_ := set $config "plugins" $plugins }}
{{- $config | toPrettyJson }}
{{- end }}
