# syntax=docker/dockerfile:1
# check=error=true

# Imagem de PRODUCAO. Para desenvolvimento use o Dockerfile.dev.

# RUBY_VERSION precisa bater com o .ruby-version.
ARG RUBY_VERSION=3.3.11
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Libs de runtime. postgresql-client: pg_dump do botão "Fazer backup" da tela
# de Administração.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      libpq5 \
      libargon2-1 \
      postgresql-client \
      libreoffice-writer \
      fonts-liberation && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# jemalloc reduz uso de memória e latência.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

# Só para compilar as gems; fica no estágio de build.
# libvips NÃO entra aqui: já está na base e ruby-vips usa FFI (sem headers).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libargon2-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Defesa contra CRLF: um checkout no Windows deixa os scripts de bin/ com CR,
# o shebang vira "ruby<CR>" e o build quebra.
RUN sed -i 's/\r$//' bin/* && chmod +x bin/*

# -j 1: evita um bug do QEMU — https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# O assets:precompile depende da task `environment`, entao carrega a aplicacao
# inteira — e o initializer do Devise faz ENV.fetch("HOST_IP") e
# ENV.fetch("OIDC_CLIENT_SECRET") sem valor padrao. Em runtime as duas vem do
# compose; no build nao existem, e o precompile aborta com KeyError.
# Os valores abaixo sao descartaveis: a descoberta OIDC (discovery: true) so
# acontece no primeiro login, nunca aqui. SECRET_KEY_BASE_DUMMY faz o mesmo
# pelo RAILS_MASTER_KEY.
RUN SECRET_KEY_BASE_DUMMY=1 HOST_IP=127.0.0.1 OIDC_CLIENT_SECRET=dummy ./bin/rails assets:precompile

FROM base

# Usuário sem privilégios.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# O entrypoint prepara o banco.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
