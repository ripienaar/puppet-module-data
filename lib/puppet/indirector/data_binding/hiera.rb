require "hiera"
require "hiera/config"
require "hiera/scope"

begin
  require 'puppet/indirector/hiera'
rescue LoadError => e
  begin
    require "puppet/indirector/code"
  rescue LoadError => e
    $stderr.puts "Couldn't require either of puppet/indirector/{hiera,code}!"
  end
end


class Hiera::Config
  class << self
    alias :old_load :load unless respond_to?(:old_load)

    def load(source)
      old_load(source)

      @config[:backends] << "module_data" unless @config[:backends].include?("module_data")

      @config
    end
  end
end

class Puppet::DataBinding::Hiera < Puppet::Indirector::Code
  desc "Retrieve data using Hiera."

  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera library"
    end
    super
  end

  if defined?(::Psych::SyntaxError)
    DataBindingExceptions = [::StandardError, ::Psych::SyntaxError]
  else
    DataBindingExceptions = [::StandardError]
  end

  def find(request)
    hiera.lookup(request.key, nil, Hiera::Scope.new(request.options[:variables]), nil, nil)
  rescue *DataBindingExceptions => detail
    raise Puppet::DataBinding::LookupError.new(detail.message, detail)
  end

  private

  def self.hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if File.exist?(hiera_config)
      config = Hiera::Config.load(hiera_config)
    else
      Puppet.warning "Config file #{hiera_config} not found, using Hiera defaults"
    end

    config[:logger] = 'puppet'
    config
  end

  def self.hiera
    @hiera ||= Hiera.new(:config => hiera_config)
  end

  def hiera
    self.class.hiera
  end
end
