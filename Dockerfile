##################
# nginx 1.11 with lua support to build up a canary release solution.
# Extended from https://github.com/nginxinc/docker-nginx/blob/11fc019b2be3ad51ba5d097b1857a099c4056213/mainline/alpine/Dockerfile
##################

FROM alpine:3.4

MAINTAINER TDAF Team "tdaf@tid.es"

ARG NGINX_VERSION=1.11.5
ARG NDK_VERSION=0.3.0
ARG LUA_NGINX_VERSION=0.10.7
ARG GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8
ARG CONFIG="\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_xslt_module=dynamic \
	--with-http_image_filter_module=dynamic \
	--with-http_geoip_module=dynamic \
	--with-http_perl_module=dynamic \
	--with-threads \
	--with-stream \
	--with-stream_ssl_module \
	--with-http_slice_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-file-aio \
	--with-http_v2_module \
	--with-ipv6 \
  --with-ld-opt="-Wl,-rpath,/usr/lib64" \
  --add-module=/usr/src/ngx_devel_kit-${NDK_VERSION} \
  --add-module=/usr/src/lua-nginx-module-${LUA_NGINX_VERSION} \
	"

RUN \
  apk add --no-cache lua luajit \
  && apk add --no-cache --virtual .build-deps \
    lua-dev \
    luajit-dev \
		curl \
  && curl -fSL https://github.com/simpl/ngx_devel_kit/archive/v${NDK_VERSION}.tar.gz -o ngx_devel_kit-${NDK_VERSION}.tar.gz \
  && curl -fSL https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_VERSION}.tar.gz -o lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \
	&& mkdir -p /usr/src \
  && tar -zxC /usr/src -f ngx_devel_kit-${NDK_VERSION}.tar.gz \
  && tar -zxC /usr/src -f lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \
	&& rm ngx_devel_kit-${NDK_VERSION}.tar.gz \
	&& rm lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \

	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache lua luajit gettext bash \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
    lua-dev \
    luajit-dev \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
  && curl -fSL https://github.com/simpl/ngx_devel_kit/archive/v${NDK_VERSION}.tar.gz -o ngx_devel_kit-${NDK_VERSION}.tar.gz \
  && curl -fSL https://github.com/openresty/lua-nginx-module/archive/v${LUA_NGINX_VERSION}.tar.gz -o lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \
	&& mkdir -p /usr/src \
  && tar -zxC /usr/src -f ngx_devel_kit-${NDK_VERSION}.tar.gz \
  && tar -zxC /usr/src -f lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \
	&& rm ngx_devel_kit-${NDK_VERSION}.tar.gz \
	&& rm lua-nginx-module-${LUA_NGINX_VERSION}.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
	&& ./configure $CONFIG \
	&& make \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& mkdir -p /var/run/nginx \
	&& chown -R nginx:nginx /var/run/nginx \
	&& apk add --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& rm -rf /usr/src

ADD config /etc/nginx/
ADD *.sh /usr/bin/

VOLUME /etc/nginx/conf.d /etc/nginx/versions /var/log/nginx

EXPOSE 8080 8081 8082 8083 8084

ENTRYPOINT ["/usr/bin/nginx-docker-entrypoint.sh"]
