#!/bin/bash
# Generates merged sdoc

# Colors
ccred=$(echo -e "\033[31m")
ccgreen=$(echo -e "\033[32m")
ccyellow=$(echo -e "\033[33m")
ccend=$(echo -e "\033[0m")

RAILS_VERSION=""
RUBY_VERSION=""

log() {
  echo "${ccyellow}${1}${ccend}"
}

usage() { 
  echo "Generates the API docs for a given Rails and Ruby version"
  echo "Works on MacOSX"
  echo "Usage: $0 -u <ruby_version> -a <rails_version>"
  echo "  eg.: $0 -u 2.4.3 -a 5.0.2"
  exit 1; 
}

while getopts "u:a:" opt; do
  case $opt in
    u) RUBY_VERSION="${OPTARG}"
      ;;
    a) RAILS_VERSION="v${OPTARG}"
      ;;
    *) usage
      ;;
  esac
done

[ -z "${RUBY_VERSION}" ] || [ -z "${RAILS_VERSION}" ] && usage

log "Generating API docs for"
log "Ruby Version ${RUBY_VERSION}"
log "Rails Version ${RAILS_VERSION}"
log "Press ENTER to continue"
read

bundle

log "Creating directories"
rm -rf repos
rm -rf sdocs
rm -rf docs
mkdir -p repos
mkdir -p sdocs
cd repos

log "Preparing system for rails ${RAILS_VERSION} install"
brew install mysql postgresql

# Rails
log "Fetching Rails $RAILS_VERSION repo from github.com"
rm -rf rails
git clone --branch ${RAILS_VERSION} --single-branch --depth 1 https://github.com/rails/rails.git
cd rails
BUNDLER_VERSION=$(grep "BUNDLED WITH" Gemfile.lock -A 1 | tail -n 1 | tr -d ' ')
log "Installing bundler version ${BUNDLER_VERSION} for rails"
gem install bundler -v $BUNDLER_VERSION
git ch $RAILS_VERSION
bundle _${BUNDLER_VERSION}_ install

log "Generating SDOC for Rails ${RAILS_VERSION} in the background"
bundle exec sdoc -q -o ../../sdocs/rails-$RAILS_VERSION --line-numbers --format=sdoc -T rails --github --exclude "\/test\/" --exclude ".*_test.rb$" . &
RAILS_PID=$!

# Ruby
RUBY_URL="http://ftp.ruby-lang.org/pub/ruby/ruby-$RUBY_VERSION.tar.bz2"
log "Fetching ruby $RUBY_VERSION from $RUBY_URL"
cd ..
rm -rf ruby
mkdir ruby
cd ruby
curl -o ruby.tar.bz2 $RUBY_URL
tar xjf ruby.tar.bz2
cd ruby-$RUBY_VERSION
log "Generating SDOC for ruby ${RUBY_VERSION} in the background"
bundle exec sdoc -q -o ../../../sdocs/ruby-$RUBY_VERSION --line-numbers --format=sdoc -T rails --github --exclude ".*rubygems.*" --exclude ".*rdoc.*" . &
RUBY_PID=$!

log "Waiting for RUBY and RAILS sdoc background jobs to finish"
wait $RAILS_PID $RUBY_PID

# Merge sdocs
cd ../../../sdocs

log "Merging Ruby and Rails SDOC"
bundle exec sdoc-merge --title "Ruby $RUBY_VERSION, Rails $RAILS_VERSION" --op ../docs --names "Ruby $RUBY_VERSION,Rails $RAILS_VERSION" ruby-$RUBY_VERSION rails-$RAILS_VERSION

# cleanup
log "Cleaning up"

log "========================================"
log "Merged SDOC is now in 'docs'"
log "========================================"
