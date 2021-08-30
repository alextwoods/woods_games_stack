FROM ruby:3.0

# install npm/yarn
RUN apt-get update && apt-get install npm -y && npm install --global yarn

WORKDIR /usr/src/app

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1

# Add Gemfile.lock to this copy, COPY Gemfile Gemfile.lock ./
COPY Gemfile ./
RUN bundle install

COPY . .

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

RUN rails assets:precompile && mkdir -p tmp/pids

EXPOSE 80
CMD ["puma", "-p", "80"]