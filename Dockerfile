ARG RUBY_VERSION=3.3.0
FROM ruby:$RUBY_VERSION-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libsqlite3-dev \
    libvips \
    pkg-config \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives


# Install system dependencies
# RUN apk add --no-cache \
#     build-base \
#     tzdata \
#     nodejs \
#     yarn \
#     sqlite-dev \
#     sqlite \
#     git

# Set working directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Add a script to be executed every time the container starts
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

# Configure the main process to run when running the image
# CMD ["rails", "server", "-b", "0.0.0.0"] 