# ---------------------------------------------------------------- build
# The API's address and the switched-on modules are baked in at build time
# (Vite inlines VITE_* values), so build one image per environment:
#   docker build --build-arg VITE_API_BASE_URL=https://api.trosky.africa/api/v1 .
FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

ARG VITE_API_BASE_URL=/api/v1
ARG VITE_ENABLED_MODULES=dispatch,driver-performance,fleet,revenue,user-growth,complaints-insights,fraud,demand,reports,audit-log,settings,wallets,alerts,team
ARG VITE_LIVE_REFRESH_SECONDS=8
# Never demo data in a deployed image: the build refuses demo mode, and the
# check below fails if any demo account or seed data reached the bundle.
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_ENABLED_MODULES=$VITE_ENABLED_MODULES \
    VITE_LIVE_REFRESH_SECONDS=$VITE_LIVE_REFRESH_SECONDS \
    VITE_DEMO_MODE=false

RUN npm run build && npm run check:build

# -------------------------------------------------------------- runtime
# nginx on Alpine, in its unprivileged build: it runs as a non-root user
# and listens on 8080.
FROM nginxinc/nginx-unprivileged:stable-alpine AS runtime

# Where the browser may send API requests besides this site itself, for
# the Content-Security-Policy (e.g. https://api.trosky.africa). Leave it
# empty when the API is served from the same origin (/api behind a proxy).
ENV API_ORIGIN=""

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1
