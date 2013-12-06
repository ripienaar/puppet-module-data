require 'hiera'
require 'hiera/config'
require 'puppet/indirector/hiera'


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

class Puppet::DataBinding::Hiera < Puppet::Indirector::Hiera
  desc "Retrieve data using Hiera."
end

