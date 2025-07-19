FROM ruby:3.3.0-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    sqlite3 \
    nodejs \
    npm \
    git \
    curl \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids tmp/sockets log

# Set permissions
RUN chmod -R 755 /app

# Expose port
EXPOSE 3000

# Start the application
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-e", "development"] 