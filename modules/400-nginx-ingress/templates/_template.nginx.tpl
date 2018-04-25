{{- define "template.nginx" }}
  {{- $name := (print "nginx" (.suffix | default "")) }}
  {{- $publishService := (.publishService | default false) }}
  {{- $hostNetwork := (.hostNetwork | default false) }}
  {{- with .context }}
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: {{ $name }}
  namespace: {{ include "helper.namespace" . }}
  labels:
    heritage: antiopa
    module: {{ .Chart.Name }}
    app: {{ $name }}
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: {{ $name }}
  template:
    metadata:
      labels:
        app: {{ $name }}
#TODO: Docker before 1.12 does not support sysctls
#        security.alpha.kubernetes.io/sysctls: "net.ipv4.ip_local_port_range=1024 65000"
    spec:
{{ include "helper.nodeSelector" . | indent 6 }}
{{ include "helper.tolerations" . | indent 6 }}
      serviceAccount: kube-nginx-ingress
      hostNetwork: {{ $hostNetwork }}
    {{- if eq $hostNetwork true }}
      dnsPolicy: ClusterFirstWithHostNet
    {{- else }}
      dnsPolicy: ClusterFirst
    {{- end }}
      terminationGracePeriodSeconds: 300
      imagePullSecrets:
      - name: registry
      containers:
      - image: {{ .Values.global.modulesImages.registry }}/nginx-ingress/controller:{{ .Values.global.modulesImages.tags.nginxIngress.controller }}
        name: nginx
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          periodSeconds: 2
          timeoutSeconds: 5
        args:
        - /nginx-ingress-controller
        - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
        - --configmap=$(POD_NAMESPACE)/{{ $name }}
        - --annotations-prefix=ingress.kubernetes.io
    {{- if $publishService }}
        - --publish-service=$(POD_NAMESPACE)/{{ $name }}
    {{- end }}
        - --sort-backends
        - --v=2
    {{- if not .name }}
        - --ingress-class=nginx
    {{- else }}
        - --ingress-class=nginx-{{ .name }}
    {{- end }}
        volumeMounts:
        - mountPath: /var/lib/nginx/body
          name: client-body-temp-path
        - mountPath: /var/lib/nginx/fastcgi
          name: fastcgi-temp-path
        - mountPath: /var/lib/nginx/proxy
          name: proxy-temp-path
        - mountPath: /var/lib/nginx/scgi
          name: scgi-temp-path
        - mountPath: /var/lib/nginx/uwsgi
          name: uwsgi-temp-path
      - image: {{ .Values.global.modulesImages.registry }}/nginx-ingress/statsd-exporter:{{ .Values.global.modulesImages.tags.nginxIngress.statsdExporter }}
        name: statsd-exporter
      - image: quay.io/brancz/kube-rbac-proxy:v0.2.0
        name: kube-rbac-proxy
        args:
        - "--secure-listen-address=:9103"
        - "--upstream=http://127.0.0.1:9102/"
        ports:
        - containerPort: 9103
          hostPort: 9103
          name: https
        resources:
          requests:
            memory: 20Mi
            cpu: 10m
          limits:
            memory: 40Mi
            cpu: 20m
      volumes:
      - name: client-body-temp-path
        emptyDir: {}
      - name: fastcgi-temp-path
        emptyDir: {}
      - name: proxy-temp-path
        emptyDir: {}
      - name: scgi-temp-path
        emptyDir: {}
      - name: uwsgi-temp-path
        emptyDir: {}
  {{- end }}
{{- end }}
